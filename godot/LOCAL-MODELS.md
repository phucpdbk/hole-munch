# Model audit — H:\Game\3DModels

Inspected local folders and archive manifests. `tools/local-model-inventory.csv` lists
558 distinct Godot prefab scenes: Farm 487, Starter 58, Particle FX 13.
FBX and OBJ copies often describe the same model, not separate assets.

| Pack | Useful candidates | Game use |
| --- | --- | --- |
| POLYGON Starter | SM_Bean_Cop_01, SM_Veh_Plane_Stunt_01, SM_PolygonCity_Veh_Car_Small_01 | Police patrol, aircraft cosmetic, civilian traffic |
| POLYGON Farm | SM_Veh_Pickup_01, tractors, harvesters, barns, silos, fences, barrels, crates | Rural districts, evacuation vehicles, checkpoint scenery |
| GENERIC Particle FX | Dust, Smoke, Fire, Rain, Snow, Fog, Leaves | Explosions and weather; benchmark particle count/overdraw on mobile |
| POLYGON Icons | Alarm, Ammo, Armour and other FBX icons | Render to small 2D UI icons instead of adding 3D UI objects |

Starter and Farm include native Godot archives with prefabs and extracted meshes.
The police prefab is a static MeshInstance3D referencing a mesh and a separate
material; preserve texture/material dependencies when importing. The prefab uses
both `assets/` and `Assets/` paths, which must be normalized for case-sensitive
exports. Characters with skeletons/animations need a separate animation setup.

No dedicated army/tank/helicopter pack was found in the inspected manifests.
Farm's Trailer_Tank is agricultural equipment, not a combat tank.

The local build now imports seven prefab families: two farmhouses, a barn, two trees, a small car and a pickup. Doors, glass and wheels are included, with palette colors baked and geometry simplified. See `assets/synty/README.md` for the reproducible import steps. Source assets and derived meshes stay out of public Git; the APK contains the derived meshes.

## Playable defense prototype

- Three to six defenders (tanks and rifle infantry) approach along the road grid,
  stop to aim, then fire visible shells/tracers with muzzle flashes and impact rings.
- All 48 objectives are landmarks. Only independent military defenders fire.
- 10 seconds of opening protection on the first level, 8 on later levels.
- Stationary target warnings last 1.25 seconds (squad) or 1.5 seconds (boss).
- Move out of the red area to dodge. A hit removes 2 seconds, breaks the combo,
  and reduces movement speed by 35% for 0.85 seconds.
- 2.5 seconds of hit immunity prevents overlapping attacks from stacking.
- At most three warnings at a time; attacks stop when their source starts sinking.
- Projectile visuals reuse twelve mesh instances; no scene nodes are allocated per shot.
- Pause freezes combat. Retry clears all warning, slowdown and immunity state.

Validation: `--script res://tools/check_defense.gd`, `-- --campaign-smoke`,
and `-- --capture --defense-capture`.
