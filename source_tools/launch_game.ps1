[CmdletBinding()]
param(
    [switch]$Editor,
    [switch]$ValidateOnly,
    [string]$GodotExe = $env:GODOT_EXE,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GameArgs
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Project = Join-Path $Root 'godot'
$Logs = Join-Path $Root 'artifacts/launch'
try {
    if (-not $GodotExe) {
        $Command = Get-Command godot -ErrorAction SilentlyContinue
        if ($Command) { $GodotExe = $Command.Source }
    }
    if (-not $GodotExe) {
        $Candidate = Join-Path $env:USERPROFILE 'Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
        if (Test-Path -LiteralPath $Candidate -PathType Leaf) { $GodotExe = $Candidate }
    }
    if (-not $GodotExe -or -not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) {
        throw 'No se encontro Godot. Define GODOT_EXE con la ruta de su ejecutable o importa godot/project.godot desde Godot.'
    }
    $GodotExe = (Resolve-Path -LiteralPath $GodotExe).Path
    New-Item -ItemType Directory -Path $Logs -Force | Out-Null
    $ImportLog = Join-Path $Logs 'import.log'
    Write-Host 'Preparando los recursos de Fragmentos de Luz...'
    & $GodotExe --headless --editor --path $Project --import --quit --log-file $ImportLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $ImportLog -Pattern 'SCRIPT ERROR:|ERROR:|Failed loading resource' -Quiet)) {
        throw "No se pudo preparar el juego. Revisa $ImportLog"
    }
    if ($ValidateOnly) {
        Write-Host 'Recursos preparados correctamente.'
        exit 0
    }
    $Arguments = @('--path', ('"' + $Project + '"'), '--log-file', ('"' + (Join-Path $Logs 'game.log') + '"'))
    if ($Editor) { $Arguments += '--editor' }
    if ($GameArgs.Count -gt 0) { $Arguments += '--'; $Arguments += $GameArgs }
    # These are interactive game/editor windows, intentionally visible to the player.
    Start-Process -FilePath $GodotExe -ArgumentList $Arguments -WindowStyle Normal
    exit 0
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
