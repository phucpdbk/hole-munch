# Farm assets

Selected from the user's local `G:/projects/tycoon-farm/assets/models`.
The source project's `assets/CREDITS.txt` identifies these packs as CC0:

- Quaternius — Farm Animal Pack / 5 Low Poly Animals: cow, pig, chicken.
- Kenney — Nature Kit / Food Kit: tree_oak, fence_simple, crops_cornStageD,
  crops_wheatStageB, tent_smallOpen, pumpkin.

The nine `.res` files are static, normalized, vertex-colored derivatives baked
by `tools/bake_farm.gd`. Each has one surface and uses the game's hole shader.
No Synty source files or music were copied. No files were uploaded to Meshy.

`source/.gdignore` keeps source FBX files out of runtime imports and exported
packages. To rebake, temporarily remove that marker, import in Godot, run
`godot --headless --path . --script res://tools/bake_farm.gd`, then restore it.
