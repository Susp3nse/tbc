import Anthropic from '@anthropic-ai/sdk';
import fs from 'fs/promises';
import path from 'path';
import { glob } from 'fs/promises';
import { config } from '../config.js';

const SYSTEM_PROMPT = `You are a WoW TBC rotation customization assistant for the Flux AIO addon.
Your job is to edit Lua source files to implement the user's requested rotation tweak.

## CONSTRAINTS (CRITICAL)
- You may ONLY edit files under: source/aio/**/*.lua
- Do NOT create new files
- Do NOT delete files
- Do NOT edit shared framework files (core.lua, main.lua, settings.lua, ui.lua) unless the change absolutely requires it
- Do NOT remove existing strategies unless explicitly asked
- Make the MINIMAL change needed to fulfill the request

## TOOLS
You have these tools:
- read_file(path): Read a Lua source file. Path relative to workspace root (e.g. "source/aio/druid/cat.lua")
- edit_file(path, old_string, new_string): Replace exact text in a file. old_string must match exactly. Always read a file before editing.
- list_files(pattern): List files matching a glob pattern (e.g. "source/aio/**/*.lua")

## ARCHITECTURE

All modules share the \`_G.FluxAIO\` namespace (aliased as \`NS\`).
- \`NS.A\` = Action table (spell/ability definitions)
- \`NS.Player\`, \`NS.Unit\` = Framework unit APIs
- \`NS.rotation_registry\` = Strategy/middleware registry
- \`NS.Constants\` = All numeric constants (thresholds, stance IDs, etc.)
- \`NS.cached_settings\` = Runtime settings cache

### Class Modules
- Druid: source/aio/druid/ — balance.lua, bear.lua, caster.lua, cat.lua, class.lua, healing.lua, middleware.lua, resto.lua, schema.lua
- Hunter: source/aio/hunter/ — class.lua, cliptracker.lua, debugui.lua, middleware.lua, rotation.lua, schema.lua

## STRATEGY PATTERN

Each strategy is a Lua table:
\`\`\`lua
local MyStrategy = {
    requires_combat = true,
    requires_enemy = true,
    requires_in_range = true,
    setting_key = "some_setting",   -- auto-checked: strategy skipped if false
    spell = A.SpellName,            -- auto-checked: strategy skipped if not ready
    min_energy = 42,                -- checked by check_prerequisites
    matches = function(context, state)
        return context.energy >= context.settings.some_threshold
    end,
    execute = function(icon, context, state)
        local result = safe_ability_cast(A.SpellName, icon, TARGET_UNIT)
        if result then
            return result, "[CATEGORY] Description"
        end
        return nil
    end,
}
\`\`\`

Registration uses array order for priority (first = highest):
\`\`\`lua
rotation_registry:register("cat", {
    named("StrategyName", strategyTable),
    named("AnotherName", anotherTable),
}, {
    context_builder = get_cat_state,
    check_prerequisites = function(strategy, context) ... end,
})
\`\`\`

## CONTEXT OBJECT

Available in matches/execute as the \`context\` parameter:
- context.hp, context.mana, context.mana_pct, context.energy, context.rage, context.cp
- context.in_combat, context.is_stealthed, context.has_clearcasting
- context.target_exists, context.target_dead, context.target_enemy, context.has_valid_enemy_target
- context.target_hp, context.ttd (time to die)
- context.in_melee_range, context.is_behind, context.enemy_count
- context.target_phys_immune, context.target_magic_immune
- context.on_gcd, context.gcd_remaining
- context.settings — runtime settings, access as context.settings.key_name

Cat-specific state (passed as \`state\` parameter via context_builder):
- state.rake_duration, state.rip_duration, state.mangle_duration
- state.has_wolfshead, state.can_powershift, state.shifts_remaining
- state.energy_after_shift, state.energy_tick_soon
- state.pooling — set by higher-priority strategies when energy-starved
- state.tf_queued — Tiger's Fury queued flag

## KEY RULES
- Lua 5.1 only: no goto, no \`//\` comments
- Settings access: ALWAYS use \`context.settings.key\` in matches/execute. NEVER capture at load time
- Settings keys are snake_case: \`context.settings.tigers_fury_energy\`
- Pre-allocate tables at load time (not inline \`{}\` in combat code paths)
- Spell casting: \`A.SpellName:IsReady(target)\` then \`A.SpellName:Show(icon)\` or use \`safe_ability_cast(A.SpellName, icon, target)\`
- String formatting: use \`format()\` (local alias for string.format)
- 200 local variable limit per function scope

## COMMON EDIT PATTERNS
- **Change a threshold**: Find the comparison in matches() or execute(), change the value
- **Add a condition**: Add a check in matches() that returns false when condition isn't met
- **Reorder priority**: Move the named() entry up or down in the registration array
- **Disable a strategy**: Return false at the top of matches(), or remove from registration

## AFTER MAKING CHANGES
Summarize briefly:
1. Which file(s) and what changed
2. What it does functionally
3. Any caveats`;

const TOOLS = [
  {
    name: 'read_file',
    description: 'Read a Lua source file. Path relative to workspace root.',
    input_schema: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Relative path, e.g. "source/aio/druid/cat.lua"' },
      },
      required: ['path'],
    },
  },
  {
    name: 'edit_file',
    description: 'Replace exact text in a file. old_string must match exactly. Read the file first.',
    input_schema: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Relative path to the file' },
        old_string: { type: 'string', description: 'Exact text to replace' },
        new_string: { type: 'string', description: 'Replacement text' },
      },
      required: ['path', 'old_string', 'new_string'],
    },
  },
  {
    name: 'list_files',
    description: 'List files matching a glob pattern under the workspace.',
    input_schema: {
      type: 'object',
      properties: {
        pattern: { type: 'string', description: 'Glob pattern, e.g. "source/aio/**/*.lua"' },
      },
      required: ['pattern'],
    },
  },
];

// Add cache_control to last tool for prompt caching (90% discount on repeated input tokens)
const TOOLS_CACHED = TOOLS.map((tool, i) =>
  i === TOOLS.length - 1 ? { ...tool, cache_control: { type: 'ephemeral' } } : tool
);

async function handleToolCall(workDir, toolName, input) {
  const safePath = (rel) => {
    const resolved = path.resolve(workDir, rel);
    if (!resolved.startsWith(workDir)) throw new Error('Path traversal blocked');
    return resolved;
  };

  switch (toolName) {
    case 'read_file': {
      const filePath = safePath(input.path);
      const content = await fs.readFile(filePath, 'utf8');
      return content;
    }
    case 'edit_file': {
      const filePath = safePath(input.path);
      const content = await fs.readFile(filePath, 'utf8');
      if (!content.includes(input.old_string)) {
        return `Error: old_string not found in ${input.path}. Read the file first to get the exact text.`;
      }
      const updated = content.replace(input.old_string, input.new_string);
      await fs.writeFile(filePath, updated, 'utf8');
      return `Successfully edited ${input.path}`;
    }
    case 'list_files': {
      const pattern = path.join(workDir, input.pattern).replace(/\\/g, '/');
      const entries = [];
      try {
        for await (const entry of glob(pattern)) {
          entries.push(path.relative(workDir, entry).replace(/\\/g, '/'));
        }
      } catch {
        // glob not available in older Node, fall back to recursive readdir
        const files = await walkDir(workDir, input.pattern);
        entries.push(...files);
      }
      return entries.join('\n') || 'No files found.';
    }
    default:
      return `Unknown tool: ${toolName}`;
  }
}

// Fallback glob via recursive readdir + minimatch-style filtering
async function walkDir(dir, pattern) {
  const results = [];
  const patternParts = pattern.replace(/\*\*/g, '___GLOBSTAR___').split('/');

  async function walk(currentDir, depth) {
    const entries = await fs.readdir(currentDir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(currentDir, entry.name);
      const rel = path.relative(dir, fullPath).replace(/\\/g, '/');
      if (entry.isDirectory()) {
        await walk(fullPath, depth + 1);
      } else if (rel.endsWith('.lua') && rel.startsWith('source/aio/')) {
        results.push(rel);
      }
    }
  }

  await walk(dir, 0);
  return results.sort();
}

export async function editRotation(workDir, userPrompt, classHint) {
  const client = new Anthropic({ apiKey: config.anthropicApiKey });

  const classConstraint = classHint
    ? `\n\nFocus ONLY on the ${classHint} class files in source/aio/${classHint}/.`
    : '';

  const filesChanged = new Set();
  const messages = [{ role: 'user', content: userPrompt + classConstraint }];

  try {
    for (let turn = 0; turn < config.maxTurns; turn++) {
      const response = await client.messages.create({
        model: config.claudeModel,
        max_tokens: 4096,
        system: [{ type: 'text', text: SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } }],
        tools: TOOLS_CACHED,
        messages,
      });

      // Collect text and tool_use blocks
      const assistantContent = response.content;
      messages.push({ role: 'assistant', content: assistantContent });

      // If no tool use, we're done
      if (response.stop_reason === 'end_turn') {
        const textBlocks = assistantContent.filter(b => b.type === 'text');
        const summary = textBlocks.map(b => b.text).join('\n');
        return { success: true, summary, filesChanged: [...filesChanged] };
      }

      // Handle tool calls
      const toolResults = [];
      for (const block of assistantContent) {
        if (block.type !== 'tool_use') continue;

        let result;
        try {
          result = await handleToolCall(workDir, block.name, block.input);
          if (block.name === 'edit_file' && !result.startsWith('Error')) {
            filesChanged.add(path.resolve(workDir, block.input.path));
          }
        } catch (err) {
          result = `Error: ${err.message}`;
        }

        toolResults.push({
          type: 'tool_result',
          tool_use_id: block.id,
          content: typeof result === 'string' ? result : JSON.stringify(result),
        });
      }

      messages.push({ role: 'user', content: toolResults });
    }

    // Ran out of turns
    return { success: false, error: `Reached max turns (${config.maxTurns})`, filesChanged: [...filesChanged] };
  } catch (err) {
    return { success: false, error: err.message, filesChanged: [...filesChanged] };
  }
}
