# Project Firefight — Godot desktop reconstruction

Open **project.godot** in Godot **4.7.1 or newer** and press **F6 on scenes/main.tscn**, or **F5** to run the project. Tested with Godot **4.7.1**, using the Compatibility renderer on Windows. No Unity installation, .NET runtime, plugins, or APK is needed to run this project. The saved native scene format comes from Godot 4.7.1; older Godot versions are not supported by this packaged project.

The project contains the original city and forest geometry, textures, equipment, scene transforms, font, sound recordings, and English/German tutorial text recovered from `Project-Firefight.apk`. Gameplay runs in native GDScript. The scenes are editable `.tscn` files; the recovered `.glb` files are also included.

## Controls

| Input | Action |
| --- | --- |
| WASD / mouse | Walk / look |
| Shift / Space | Run / jump |
| E | Pick up the aimed equipment or hose end |
| Q | Place the held item; cancel a selected connection |
| F | Connect the held hose/equipment to the aimed matching connection |
| C | Disconnect the aimed connection |
| R | Turn a valve; operate the hydrant while holding its key |
| Left mouse | Spray while holding the supplied jet pipe |
| Escape | Pause, restart the level, or return to the menu |

A yellow marker identifies the current tutorial objective. Follow the original tutorial at the top left. A/B/C connections must match. Pick up an end, walk to its destination, aim at the connection, and press F. Place cones, the distributor, and the suction basket in their marked areas with Q. For the hydrant, hold the hydrant key, aim at the hydrant, and press R. Open the valves on the outlets actually connected to your hoses. The nozzle needs more than 0.5 bar.

**City:** cones → hydrant and collector → pump → distributor → C hoses → jet pipe → fire.

**Forest:** three A hoses → suction basket in the lake → pump → distributor → C hoses → jet pipe → fire.

Options switches the original tutorials between English and German. The selection is saved locally.

## Project files

| Path | Contents |
| --- | --- |
| `scenes/main.tscn` | Game entry point |
| `scenes/city.tscn`, `scenes/forest.tscn` | Editable recovered environments and collision geometry |
| `scripts/main.gd` | Menu, equipment interactions, tutorials, desktop adaptation |
| `scripts/player.gd` | Desktop player controller |
| `scripts/water_network.gd` | Hose connections and pressure propagation |
| `scripts/fire_patch.gd`, `scripts/fire.gdshader` | Native fire behavior and replacement visual effects |
| `data/` | Recovered scene metadata, tutorial strings, and fire rules |
| `assets/` | Original textures, meshes, font and audio converted to portable formats |
| `scripts/bake_scenes.gd` | Regenerate the editable scenes from GLB and metadata |
| `scripts/test_gameplay.gd` | Automated gameplay integration checks |

## Validation

Run `godot --headless --path . --script res://scripts/test_gameplay.gd` from this folder. The integration checks cover both complete tutorial routes, terrain below both spawns, connection rejection, source disconnection/reconnection, valve pressure splitting, nozzle pressure, fire growth, suppression, and completion. These tests invoke the gameplay actions programmatically; they do not establish pixel-identical rendering or a complete manual keyboard/mouse playthrough.

Run `godot --headless --path . -- --level=city --smoke` or use `forest` for a short runtime check.

A Windows export preset is included. Install the matching Godot export templates, create the `exports` folder, then export the `Windows Desktop` preset. The preset includes the JSON gameplay data. A standalone Windows executable has not been built or tested.

## Fidelity and remaining differences

This is a playable desktop reconstruction, **not a verified one-to-one conversion**. The supplied build was Unity 2020.3.5f1 and used VR interactions. There was no original project or running APK reference available for visual comparison.

- Original mesh placement, base textures, material colors, texture tiling, and foliage cutouts were recovered. Lighting, sky, water rendering, shader effects, and baked lighting are not identical to Unity. Original lightmap images are retained, but the Godot scenes use realtime lighting.
- The blue menu, menu choices, original font, and tutorial wording are retained. The VR world-space tutorial presentation becomes a desktop HUD with control prompts and objective markers.
- Hands, VR controller animations, grabbing/teleportation, and Unity rigid-body fixation are replaced with desktop walking and pick/place interactions. Held objects follow the camera; released equipment does not have a full rigid-body simulation.
- Pressure losses (A=0, B=0.2, C=0.35), source pressure (3), pump multiplication (3), output splitting, matching connection sizes, and the nozzle threshold (0.5) follow the recovered C# rules.
- Fire growth (100/s), upper limit (10,000), particle damage (0.45), neighbor links, and random initial ignition are recovered. Godot fire/smoke/spark/water effects are replacements. Desktop water-hit sampling is calibrated independently of Unity particle collisions, so extinguishing time is not guaranteed to match.
- The suction basket uses placement in the recovered lake tutorial target to enable its supply. This replaces the original physics-trigger lake interaction.
- The original DLLs are not executed by this project. Decompilation and extraction files are kept separately in the workspace's `recovery/` folder.

Further work is needed to claim exact visual and physics parity with the APK. This project provides the recovered content and functioning desktop implementation for that comparison and refinement.
