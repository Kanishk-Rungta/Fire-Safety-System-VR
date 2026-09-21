param([switch]$Editor, [string]$GodotPath)
$projectPath = Join-Path $PSScriptRoot 'GodotProject'
if (-not $GodotPath) {
    $godotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($godotCommand) { $GodotPath = $godotCommand.Source }
}
if (-not $GodotPath) {
    $localGodot = Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe'
    if (Test-Path -LiteralPath $localGodot) { $GodotPath = $localGodot }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Pass -GodotPath with the path to your Godot executable, or import GodotProject/project.godot in Godot.'
}
if ($Editor) { & $GodotPath --editor --path $projectPath }
else { & $GodotPath --path $projectPath }
