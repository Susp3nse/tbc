# BindPad Importer

An extension addon for [BindPad](../BindPad) that creates BindPad macros (with
keybinds) from a Lua table or a JSON object.

It is a separate, standalone addon. It does not edit BindPad's files; it only
calls BindPad's public functions. BindPad can therefore be updated independently
and this addon keeps working as long as those entry points still exist.

Client: WoW Classic Anniversary (interface `11503` / `11504`). It uses the same
`.toc` interface line as BindPad itself.

## Install

The addon lives in:

```
Interface/AddOns/BindPadImporter/
- BindPadImporter.toc
- BindPadImporter.lua     (adapter logic)
- Json.lua                (JSON decoder)
- Macros.lua              (macro definitions to edit)
- README.md
```

`BindPad` must also be installed and enabled. It is listed as a dependency, so
the game loads BindPadImporter after it automatically.

## The macro object

Every macro is one object/table. The same shape works as Lua (in `Macros.lua`)
or as JSON (paste window or API).

| Field | Type | Required | Meaning |
|---|---|---|---|
| `name` | string | yes | Macro name; shown on the BindPad slot. Auto-suffixed if it collides. |
| `macrotext` | string | yes | The macro body or script. |
| `key` | string | optional | Keybind, e.g. `"F"`, `"SHIFT-E"`, `"CTRL-1"`, `"ALT-BUTTON3"`, `"NUMPAD1"`. Omit for no bind. |
| `icon` | string or number | optional | A bare icon name (`"Spell_Fire_FlameBolt"`), a full path (`"Interface\\Icons\\Spell_Fire_FlameBolt"`), or a fileID number. Bare names are prefixed with `Interface\Icons\`. Defaults to a question-mark icon. |
| `tab` | number | optional | BindPad tab to write into. `1` = General (default), `2` to `4` = character-specific. |
| `forAllCharacters` | boolean | optional | General tab only: bind on every character. |

The minimum object is `name` plus `macrotext`.

### Field aliases

So data generated elsewhere still works, these spellings are all accepted:

- name: `name`, `macroName`, `"Macro name"`
- key: `key`, `keybind`, `Keybind`
- macrotext: `macrotext`, `text`, `body`, `"Macro text"`
- icon: `icon`, `texture`

## Three ways to import

### 1. Automated: edit `Macros.lua`, then `/reload` (recommended)

Fill in `BindPadImporterMacros`. Everything in it is imported automatically on
login or reload.

```lua
BindPadImporterMacros = {
  {
    name = "Fireball",
    key = "SHIFT-F",
    macrotext = "/cast Fireball",
    icon = "Spell_Fire_FlameBolt",   -- bare name; or "Interface\\Icons\\Spell_Fire_FlameBolt"
  },
  {
    name = "Heal",
    key = "CTRL-1",
    macrotext = "/cast [@player] Lesser Heal",
  },
}
```

Then in game: `/reload`. Watch chat for `[BindPad] imported 2/2 macro(s)`.

### 2. Paste JSON: `/bpi`

Run `/bpi` to open a window, paste a JSON object or array, click Import.

```json
[
  { "name": "Fireball", "key": "SHIFT-F", "macrotext": "/cast Fireball" },
  { "name": "Heal",     "key": "CTRL-1",  "macrotext": "/cast [@player] Lesser Heal" }
]
```

### 3. Programmatic: from other addons, WeakAuras, or `/run`

```lua
BindPadImporter.ImportMacro(def)        -- one object  -> ok, nameOrError
BindPadImporter.ImportMacros(list)      -- array/list  -> importedCount, total
BindPadImporter.ImportJSON(jsonString)  -- JSON string -> importedCount or nil,err
```

## Slash commands

| Command | Action |
|---|---|
| `/bpi` | Open the paste-JSON window. |
| `/bpi run` | Re-import everything in `Macros.lua`. |
| `/bpi list` | List macros this addon has imported. |
| `/bpi clear` | Remove every macro this addon imported (and its keybind). |

## Behavior notes

- Idempotent. Re-importing a macro with the same `name` updates it in place (and
  re-applies its keybind) rather than creating a duplicate.
- Out of combat only. WoW blocks keybinding changes in combat, so import is
  deferred until combat ends (and until BindPad has finished initializing at
  login; there is a short auto-retry on entering the world).
- Overwrites conflicting binds silently. If a `key` is already used by something
  else, the importer takes it.
- General vs. character-specific tab. `tab = 1` (General) is the default and is
  the right choice in almost all cases. Tabs `2` to `4` map to BindPad's
  character-specific tabs.

## How it works

For each definition the importer:

1. Finds an existing BindPad macro slot by `name`, or the first empty slot
   (growing the tab if full).
2. Sets the slot to a BindPad macro (`type = "CLICK"`) with the name, icon and
   body, building the action via `BindPadCore.CreateBindPadMacroAction`.
3. Registers the secure macro attribute with `BindPadCore.UpdateMacroText` so the
   bind fires.
4. Applies the keybind with `BindPadCore.BindKey`.

All of those are BindPad's own public functions; this addon adds no secure code
of its own.

## Troubleshooting

- Nothing imported, or `BindPad is not ready yet`: make sure BindPad is enabled.
  The auto-import retries for about 20s after login; if you were in combat, leave
  combat and run `/bpi run`.
- `JSON error: ...`: the pasted text is not valid JSON. Check quotes and commas.
  In Lua strings, write Windows icon paths with double backslashes:
  `"Interface\\Icons\\..."`.
- A macro got renamed with `_2`: BindPad requires globally-unique macro names; a
  name already in use elsewhere is auto-suffixed.
- A keybind did not take: confirm the key string format (e.g. `"SHIFT-F"`,
  uppercase, modifiers first) and that you were not in combat.
