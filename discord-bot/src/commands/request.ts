import fs from 'fs/promises';
import path from 'path';
import { validatePrompt, checkRateLimit, validateChanges } from '../services/guardrails.js';
import { createWorkspace, runBuild, cleanup } from '../services/builder.js';
import { editRotation } from '../services/claude.js';

let currentRequest = null;

// Recent request history per user (in-memory, capped at 10)
const history = new Map();

function addHistory(userId, entry) {
  if (!history.has(userId)) history.set(userId, []);
  const list = history.get(userId);
  list.push(entry);
  if (list.length > 10) list.shift();
}

export function getHistory(userId) {
  return history.get(userId) || [];
}

export function getCurrentRequest() {
  return currentRequest;
}

export async function handleRequest(interaction) {
  const prompt = interaction.options.getString('prompt');
  const classHint = interaction.options.getString('class') || null;
  const userId = interaction.user.id;

  // Layer 1: Input validation
  const promptCheck = validatePrompt(prompt);
  if (!promptCheck.valid) {
    return interaction.reply({ content: promptCheck.error, ephemeral: true });
  }

  const rateCheck = checkRateLimit(userId);
  if (!rateCheck.allowed) {
    return interaction.reply({ content: rateCheck.error, ephemeral: true });
  }

  // Mutex check
  if (currentRequest) {
    return interaction.reply({
      content: `A request is already being processed for <@${currentRequest.userId}>. Please wait.`,
      ephemeral: true,
    });
  }

  currentRequest = { userId, startTime: Date.now(), prompt };
  await interaction.deferReply();

  let tempDir = null;
  try {
    // Step 1: Create isolated workspace
    tempDir = await createWorkspace();

    // Step 2: Let Claude edit the rotation
    await interaction.editReply('Working on your request...');

    const result = await editRotation(tempDir, prompt, classHint);

    if (!result.success) {
      addHistory(userId, { timestamp: Date.now(), prompt, status: 'error', summary: result.error });
      return await interaction.editReply(`Claude could not complete the edit:\n\`\`\`\n${truncate(result.error, 1500)}\n\`\`\``);
    }

    if (result.filesChanged.length === 0) {
      addHistory(userId, { timestamp: Date.now(), prompt, status: 'no_changes', summary: result.summary });
      return await interaction.editReply(`No files were modified. Claude said:\n${truncate(result.summary, 1800)}`);
    }

    // Step 3: Post-Claude guardrails
    const validation = await validateChanges(tempDir, result.filesChanged);
    if (!validation.valid) {
      addHistory(userId, { timestamp: Date.now(), prompt, status: 'rejected', summary: validation.errors.join(', ') });
      return await interaction.editReply(`Safety check failed:\n${validation.errors.map(e => `- ${e}`).join('\n')}`);
    }

    // Step 4: Build
    const build = await runBuild(tempDir);
    if (!build.success) {
      addHistory(userId, { timestamp: Date.now(), prompt, status: 'build_failed', summary: build.error });
      return await interaction.editReply(`Build failed after Claude's edits:\n\`\`\`\n${truncate(build.error, 1500)}\n\`\`\``);
    }

    // Step 5: Deliver
    const outputBuffer = await fs.readFile(build.outputPath);
    const summary = truncate(result.summary, 1800);

    addHistory(userId, { timestamp: Date.now(), prompt, status: 'success', summary });

    await interaction.editReply({
      content: `**Done!** Here's your customized rotation.\n\n${summary}`,
      files: [{ attachment: outputBuffer, name: 'TellMeWhen.lua' }],
    });
  } catch (err) {
    console.error('Request failed:', err);
    addHistory(userId, { timestamp: Date.now(), prompt, status: 'error', summary: err.message });
    await interaction.editReply('An unexpected error occurred while processing your request.').catch(() => {});
  } finally {
    if (tempDir) await cleanup(tempDir);
    currentRequest = null;
  }
}

function truncate(str, max) {
  if (!str) return '(no output)';
  if (str.length <= max) return str;
  return str.slice(0, max - 15) + '... (truncated)';
}
