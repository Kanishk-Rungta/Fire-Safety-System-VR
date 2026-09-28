# Project Firefight — combined rescue mission

Open **project.godot in this outer Fire Project folder**, or run `Launch-GodotProject.ps1`. The launcher now opens this combined project. Use Godot 4.7.1.

Choose **Keyboard & Mouse → City Fire + House Rescue** for the complete mission. The Forest Level remains a separate outdoor training map.

1. Follow the outdoor equipment and water-supply tutorial, then extinguish every outdoor fire.
2. Follow **HOUSE ENTRY** to the turquoise marker on the street-facing side of the burning house. Press **E** nearby to enter. Entry remains locked while fire is active.
3. You arrive on the house porch. Walk through the open front door. Open the **living-room and kitchen windows** to disperse their smoke. Follow the yellow markers; crouch when the smoke warning appears.
4. Pick up the extinguisher and suppress every active indoor fire, including fire that spreads to furniture.
5. Put down the extinguisher, find the civilian in the bedroom, and pick them up.
6. Carry the civilian through the front door to the **green rescue assembly point on the porch**. The mission finishes when the living victim reaches this area.

The timer starts when the outdoor level starts, continues through entry and the indoor rescue, and stops when the victim is saved. Pauses are excluded. Results show total time and outdoor/indoor splits. Death ends the attempt; retry and restart return to the combined mission menu, and starting a new mission resets all objectives and timing.

| Action | Outside | Inside |
| --- | --- | --- |
| Move / look | WASD / mouse; Shift runs | WASD / mouse |
| Pick up / interact | E picks up, R operates equipment | E or Left-click picks up, drops, or opens doors/windows |
| Put down | Q | E or Left-click |
| Spray | Hold Left-click with supplied nozzle | Hold Right-click with extinguisher |
| Connect / disconnect | F / C | — |
| Crouch | — | C toggles, Ctrl holds |
| Flashlight | — | F |
| Pause | Esc | Esc |

Meta/OpenXR controls are retained. Outdoors, use the existing controller controls and **A** at HOUSE ENTRY. Indoors: left stick moves, right stick snap-turns, grip interacts/picks up/drops, trigger sprays, A toggles the flashlight, right stick click toggles crouch, and B/menu pauses. Instructions, survival information, pause controls, and results render in the headset.

The new reusable civilian asset is `interior/Scenes/Characters/CivilianVisual.tscn`: an original editable low-poly character with separate clothing, limbs, face, hair, closed eyes, and subtle breathing. `VictimNPC.tscn` supplies collision, carrying, and health behavior.

The original `GodotProject` and `godot-project` folders are retained as source copies. The combined game uses the root `scenes`, `scripts`, `assets`, `data`, `addons`, and `interior` folders. The existing APK and ZIP are older builds, not exports of this merged project.

Validation: 83 outdoor gameplay checks, 44 existing control checks, 25 full rescue checks, and 12 indoor control checks. VR checks use synthetic tracking; physical headset testing is still needed. Rendered entrance, indoor, and civilian screenshots were also inspected. This sandbox reports OS certificate/cache permission errors; the final runtime tests have no game-script or missing-resource errors.
