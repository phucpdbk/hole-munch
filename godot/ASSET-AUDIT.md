# Model inventory — tycoon-farm

Read-only source inspection: `G:/projects/tycoon-farm`, 2026-09-30.
The source project was not modified and no assets were uploaded externally.

## Reused in the 36-level Godot campaign

Source `assets/CREDITS.txt` identifies the following as Kenney/Quaternius CC0.
Nine FBX models were flattened to one mesh surface, centered at ground level,
scaled, and recolored where needed to match the game. The baked files total
about 57 KiB. Skeletons and animations are not used; small animals stroll using
the existing lightweight movement system.

| Model | Triangles | Role |
| --- | ---: | --- |
| cow | 796 | Walking animal and giant farm boss |
| pig | 562 | Walking animal and giant farm boss |
| chicken | 250 | Walking animal and giant farm boss |
| tree_oak | 196 | Farm trees |
| fence_simple | 64 | Edible fence sections |
| crops_cornStageD | 300 | Corn rows |
| crops_wheatStageB | 360 | Wheat rows |
| tent_smallOpen | 224 | Farm campsite buildings |
| pumpkin | 188 | Harvest rows |

Runtime assets: `assets/farm/*.res`; provenance: `assets/farm/CREDITS.md`.

## Other useful assets found

- Kenney/Quaternius: player/helper characters, other trees, bushes, grass,
  flowers, cacti, fences, carrot/pumpkin plants, bread, apples, eggs, cheese.
- Animation files: idle, run, pick, harvest, chop.
- Synty folders contain 549 `.tscn`, 757 `.res` and 24 `.fbx` files. These counts
  include scenes, prefabs, meshes and materials, not 1,330 distinct models.
- Particularly useful Synty prefabs: `SM_Veh_Tractor_01`, `SM_Veh_TractorOld_01`,
  `SM_Bld_Barn_01/02/03`, `SM_Bld_Farmhouse_01/02`, `SM_Bld_Silo_01/02`,
  `SM_Bld_Greenhouse_01`, `SM_Prop_Windmill_01`, plus crops and fences.

Synty files were inventoried but not copied. The source project's
`assets/Synty/README.txt` describes their separate licence and deliberately keeps
their source files out of Git. The CC0 set was sufficient for this update.

## Meshy image → 3D

Meshy's documented Image-to-3D API accepts PNG/JPEG via public URL or data URI
and can return GLB. A future asset workflow can create a task, poll its status,
download GLB, inspect scale/materials/topology, then import it into Godot.
For mobile, measure triangle count, texture memory and draw calls after import;
an AI-generated model is not automatically suitable for every device.

No Meshy API request has been made. To use it, choose the input image and make
the key available locally as `MESHY_API_KEY`; do not put a key into the game,
source control or an exported app. Generation can consume API credits.

Official reference: https://docs.meshy.ai/en/api/image-to-3d

## New landmarks

The 12 landmark meshes are generated locally by `scripts/landmarks.gd`:
Eiffel Tower, Big Ben, Leaning Tower of Pisa, Giza pyramid, Mount Fuji,
Statue of Liberty, Colosseum, One Pillar Pagoda, Khue Van Pavilion, Dutch
windmill, Moai and Sydney Opera House. They are stylized toy interpretations,
not imported assets or exact architectural reconstructions.
