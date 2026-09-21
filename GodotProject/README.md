# Project Firefight — Godot desktop reconstruction

Open **project.godot** in Godot **4.7.1 or newer** and press **F6 on scenes/main.tscn**, or **F5** to run the project. Tested with Godot **4.7.1**, using the Compatibility renderer on Windows. No Unity installation, .NET runtime, plugins, or APK is needed to run this project. The saved native scene format comes from Godot 4.7.1; older Godot versions are not supported by this packaged project.

The project contains the original city and forest geometry, textures, equipment, scene transforms, font, sound recordings, and English tutorial text recovered from `Project-Firefight.apk`. Gameplay runs in native GDScript. The scenes are editable `.tscn` files; the recovered `.glb` files are also included.

## Start menu

First choose **Keyboard & Mouse** or **Meta VR Headset**. Then choose **City Level** or **Forest Level**. **Back to Controls** lets you change the input mode. **Quit** is available on both pages. The game is English-only; the language menu and German tutorial translations have been removed, and old saved language preferences are ignored.

The selected mode creates its own player controller. Keyboard/mouse gameplay input is ignored in VR mode; VR actions are ignored in keyboard mode. Returning to the first menu stops the VR session and clears the selection.

## Meta headset through Quest Link / Air Link

This is a **PC VR** implementation, not a standalone Quest APK or a mouse-controlled VR simulator. Connect the headset to the PC through Quest Link or Air Link, enter the Link environment, and make Meta Quest Link the active OpenXR runtime. Start this Godot project on the PC and choose **Meta VR Headset** on the monitor. Map selection, tutorials, and pause controls are then displayed inside the headset. Point the right controller at a menu button and pull/release the trigger to click it.

If OpenXR cannot initialize, the game stays on the control-selection page with a setup/retry message. It does not silently launch keyboard mode. The implementation uses Godot's built-in OpenXR interface and an explicit Oculus/Meta Touch action map. See [Godot OpenXR settings](https://docs.godotengine.org/en/stable/tutorials/xr/openxr_settings.html) and [XR action maps](https://docs.godotengine.org/en/stable/tutorials/xr/xr_action_map.html).

| Meta Touch input | Action |
| --- | --- |
| Headset movement | Tracked view / room-scale movement |
| Left thumbstick | Walk in the direction you face |
| Right thumbstick left/right | 30-degree snap turn |
| Right grip press | Pick up / place the aimed equipment (toggle) |
| Right A | Connect matching hose/equipment ports |
| Right thumbstick click | Disconnect aimed port |
| Right trigger | Use valve/key; hold to spray with the supplied nozzle; click menu buttons |
| Right B / left menu button | Pause / resume |

The right controller's aim pose selects targets and directs water. Held equipment follows its grip pose. Pause, restart, and map navigation are available in the headset. Losing XR session focus pauses an active level; use Resume after returning to the app.

**Hardware validation:** menu/input logic and XR poses/buttons were tested with synthetic Godot trackers. A physical Meta headset, Link/Air Link streaming, stereoscopic rendering, and headset performance have not been tested here. A real headset playthrough remains necessary.

## Keyboard and mouse controls

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

## Project files

| Path | Contents |
| --- | --- |
| `scenes/main.tscn` | Game entry point |
| `scenes/city.tscn`, `scenes/forest.tscn` | Editable recovered environments and collision geometry |
| `scripts/main.gd` | Menu, equipment interactions, tutorials, desktop adaptation |
| `scripts/player.gd` | Desktop player controller |
| `scripts/vr_player.gd` | OpenXR headset/controller rig, thumbstick movement and snap turning |
| `scripts/vr_panel.gd` | In-headset menu/HUD and controller-ray UI input |
| `openxr_action_map.tres` | Meta Touch poses, buttons, triggers and thumbstick bindings |
| `scripts/water_network.gd` | Hose connections and pressure propagation |
| `scripts/fire_patch.gd`, `scripts/fire.gdshader` | Native fire behavior and replacement visual effects |
| `data/` | Recovered scene metadata, tutorial strings, and fire rules |
| `assets/` | Original textures, meshes, font and audio converted to portable formats |
| `scripts/bake_scenes.gd` | Regenerate the editable scenes from GLB and metadata |
| `scripts/test_gameplay.gd` | Automated gameplay integration checks |
| `scripts/test_controls.gd` | Menu flow, controller isolation, and synthetic XR tests |

## Validation

Run `godot --headless --path . --script res://scripts/test_gameplay.gd` from this folder. The integration checks cover both complete tutorial routes, terrain below both spawns, connection rejection, source disconnection/reconnection, valve pressure splitting, nozzle pressure, fire growth, suppression, and completion. These tests invoke the gameplay actions programmatically; they do not establish pixel-identical rendering or a complete manual keyboard/mouse playthrough.

Run `godot --headless --path . -- --level=city --smoke` or use `forest` for a short runtime check.

Run `godot --headless --path . --script res://scripts/test_controls.gd` for the controller/menu checks. Current results: **65 gameplay assertions and 44 controller/menu assertions passed**. Synthetic XR checks are not a substitute for a hardware headset test.

A Windows export preset is included. Install the matching Godot export templates, create the `exports` folder, then export the `Windows Desktop` preset. The preset includes the JSON gameplay data. A standalone Windows executable has not been built or tested.

## Fidelity and remaining differences

This is a playable desktop reconstruction, **not a verified one-to-one conversion**. The supplied build was Unity 2020.3.5f1 and used VR interactions. There was no original project or running APK reference available for visual comparison.

- Original mesh placement, base textures, material colors, texture tiling, and foliage cutouts were recovered. Lighting, sky, water rendering, shader effects, and baked lighting are not identical to Unity. Original lightmap images are retained, but the Godot scenes use realtime lighting.
- The blue menu and original font remain. The new menu chooses controls before maps. English tutorials appear in a desktop HUD or an in-headset panel, depending on the selected mode.
- The original animated hands and Unity rigid-body fixation are not reproduced. Keyboard mode uses mouse look and pick/place; VR mode uses tracked head/controller poses, grip pick/place, thumbstick movement and snap turning. Released equipment does not have a full rigid-body simulation.
- Pressure losses (A=0, B=0.2, C=0.35), source pressure (3), pump multiplication (3), output splitting, matching connection sizes, and the nozzle threshold (0.5) follow the recovered C# rules.
- Fire growth (100/s), upper limit (10,000), particle damage (0.45), neighbor links, and random initial ignition are recovered. Godot fire/smoke/spark/water effects are replacements. Desktop water-hit sampling is calibrated independently of Unity particle collisions, so extinguishing time is not guaranteed to match.
- The suction basket uses placement in the recovered lake tutorial target to enable its supply. This replaces the original physics-trigger lake interaction.
- The original DLLs are not executed by this project. Decompilation and extraction files are kept separately in the workspace's `recovery/` folder.

Further work is needed to claim exact visual and physics parity with the APK. This project provides the recovered content and functioning desktop implementation for that comparison and refinement.

## Road closure and solid scenery

Both maps now have solid firetruck hulls, and recovered house meshes have wall collision. The pump remains reachable from behind each truck. These solids are shared by keyboard and VR locomotion.

The city road extends 40 metres toward the cone placement area, with sidewalks, a stop line, three stationary waiting cars, a marshal, and two bystanders. Gold rings mark the cone positions. Placed cones sit upright on the road and have collision; placing both changes the traffic sign to ?ROAD CLOSED?. The cars are a stationary emergency queue, not simulated traffic.

The additions are editable in `scenes/city.tscn`. `scripts/city_street_builder.gd` rebuilds them when running `scripts/bake_scenes.gd`; `scripts/road_closure.gd` controls the sign and hazard lights.

Run `godot --headless --path . --script res://scripts/test_world.gd` for 41 additional checks covering truck collision on both maps with both movement controllers, pump reach, building collision, road seams, waiting-car collision, and cone placement/sign updates. Physical headset testing remains outstanding.
