--[[
    Macros.lua - macro definitions for BindPadImporter.

    Everything listed in BindPadImporterMacros is imported into BindPad on login
    or reload. Editing this file and running "/reload" applies a set of macros
    and keybinds to a character.

    Each entry is a table. Recognized fields (all field-name variants work, so
    the same shape used as JSON can be pasted here):

        name          (string)  - macro name, shown in the BindPad slot.        REQUIRED
        key           (string)  - the keybind, e.g. "F", "SHIFT-E", "CTRL-1",
                                   "ALT-BUTTON3", "NUMPAD1". Omit for no bind.
        macrotext     (string)  - the macro body / script.                      REQUIRED
        icon          (string|number) - any of: a bare icon name
                                   ("Spell_Fire_FlameBolt"), a full path
                                   ("Interface\\Icons\\Spell_Fire_FlameBolt"),
                                   or a fileID number. A bare name is auto-
                                   prefixed with Interface\Icons\. Optional;
                                   defaults to a question-mark icon.
        tab           (number)  - BindPad tab to write into (1 = General,
                                   default). 2-4 = character-specific tabs.
        forAllCharacters (boolean) - General-tab only: bind for every character.

    Aliases accepted per field (case-insensitive on the bracketed forms):
        name        : name, macroName, ["Macro name"]
        key         : key, keybind, Keybind, ["Keybind"]
        macrotext   : macrotext, text, body, ["Macro text"]
        icon        : icon, texture

    Re-importing is idempotent: a macro with the same name is updated in place
    (its keybind is re-applied), not duplicated.
    
    Example:
    BindPadImporterMacros = {
    {
        name = "BPI Icon Test",
        key = "CTRL-SHIFT-K",
        macrotext = "/run print('BindPadImporter icon test OK')",
        icon = "Achievement_General",
    },
}
]]
