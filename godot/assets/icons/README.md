# UI icons (POLYGON Icons)

Button and HUD icons are rendered from the user's POLYGON Icons library
(`H:/Game/3DModels/POLYGON_Icons`, Synty) by `tools/bake_icons.gd`: each OBJ is
lit in a small orthographic stage, given a dark 3 px outline and saved as a
128×128 PNG here. The id → mesh table lives in `ICONS` at the top of the tool.

These are derived third-party assets, so the PNGs are excluded from Git like the
other Synty bakes (see `../synty/README.md`); local APKs include them. Without
them, `scripts/ui_style.gd` falls back to simple vector icons.

To rebuild (the tool renders, so do not pass `--headless`):

```powershell
# Extract OBJ/ and Textures/ from POLYGON_Icons_SourceFiles_v3.zip first.
Godot_v4.7.1-stable_win64_console.exe --path godot --script res://tools/bake_icons.gd -- <path>/_SourceFiles
Godot_v4.7.1-stable_win64_console.exe --headless --path godot --import
# Contact sheet of all 520 icons for picking new ones: test-output/icon-sheet.png
Godot_v4.7.1-stable_win64_console.exe --path godot --script res://tools/bake_icons.gd -- <path>/_SourceFiles --sheet
```
