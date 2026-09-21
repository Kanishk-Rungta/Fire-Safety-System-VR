# APK recovery and conversion

Input: `Project-Firefight.apk` (preserved unchanged).

The APK is a Unity 2020.3.5f1 Mono build, with three scenes: Menue, CityScene, ForestScene. Its user gameplay scripts were recovered from `Assembly-CSharp.dll` into `recovery/csharp/`. The original payload is in `recovery/apk/`; serialized object inventories are in `recovery/trees/`.

## Reproduce asset conversion

From this workspace:

```powershell
python -m pip install -r tools/requirements.txt --target .tools/python
python tools/extract_apk.py
python tools/recover.py
godot --headless --path GodotProject --editor --import --quit
godot --headless --path GodotProject --script res://scripts/bake_scenes.gd
godot --headless --path GodotProject --script res://scripts/test_gameplay.gd
```

`godot` denotes the Godot 4.7.1 executable. On this machine it is under `C:\Users\Acer\Downloads\Godot_v4.7.1-stable_win64.exe\`.

For C# reference decompilation, the workspace has ILSpy 9.1.0.7988 installed under `.tools/dotnet/`:

```powershell
.tools/dotnet/ilspycmd.exe -p -o recovery/csharp recovery/apk/assets/bin/Data/Managed/Assembly-CSharp.dll
```

The conversion exports triangle meshes with a Z-axis coordinate reflection, reverses triangle winding, converts texture UV orientation, maps material colors from sRGB to linear glTF factors, preserves texture tiling, and exports Unity static-batch submesh ranges in world space. Collider meshes are recovered separately because static-batched render meshes cannot be used as local terrain collision geometry. Built-in Unity primitive meshes are recovered from `unity default resources`.

The generic MonoBehaviour reader cannot decode the tutorial ScriptableObject's string arrays, so `recover.py` reads those arrays directly. One city MonoBehaviour has a null script reference and is not used. Extraction exceptions and asset export results are recorded under `recovery/`.

The playable project and its precise fidelity limitations are documented in `GodotProject/README.md`. `GodotProject.zip` packages the project without Godot's generated cache, the APK, recovery payload, or extraction-tool dependencies.
