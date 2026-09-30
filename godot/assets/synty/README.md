# Locally imported POLYGON models

The playable local build uses models from the user's `H:/Game/3DModels` library:
POLYGON Farm (two farmhouses, barn, two trees, pickup) and POLYGON Starter (car).
Starter's three Bean characters (Female, Town Female, Cowboy) replace civilian
pedestrians. They contain 398, 688 and 704 triangles and share MultiMesh batches;
movement uses the existing bob/turn motion, not per-character skeleton animation.
Their child meshes (doors, glass, wheels) are included. Palette textures are sampled
into vertex colors, then surfaces are merged, normalized to gameplay size and
simplified for mobile. Runtime instances share a mesh and the game's swallow shader.

These are third-party Synty assets, not the CC0 models in `../farm`.
Source files and derived `.res` files are excluded from Git; the local APK includes
the derived meshes. Source prefabs/textures are excluded from the APK.

To rebuild on a machine with the same asset library:

```powershell
./godot/tools/import-local-models.ps1 -Library H:/Game/3DModels
Godot_v4.7.1-stable_win64_console.exe --headless --path godot --editor --import --quit
Godot_v4.7.1-stable_win64_console.exe --headless --path godot --script res://tools/bake_local_models.gd
```

Without the local assets, the public source falls back to procedural buildings,
cars and trees. Rebuilt APKs using the library must include the baked meshes.

## Winter and district playtest

Snow weather adds a slope/height mask to the shared house/tree shader and lightens
grass. It is visual coverage, not a snow physics simulation. Clear weather resets it.
Blocks now have unequal widths/depths with courtyards and shifted houses; roads
remain orthogonal, with traffic, sidewalks and defenders sharing their coordinates.

Largest-level desktop capture with VSync off (RTX 2060 SUPER), 120 frame samples:
before: median 3.021 ms / p95 4.760 ms; after: median 3.058 ms / p95 4.757 ms.
The district change also changes scene contents (842 -> 945 items), so this is a
whole-build comparison, not an isolated character benchmark. It does not establish
phone performance. Reproduce with `-- --capture --perf-large`.
