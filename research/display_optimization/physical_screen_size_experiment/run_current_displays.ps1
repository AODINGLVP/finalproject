param(
    [Parameter(Mandatory=$true)][string]$Session,
    [string]$InventoryPath = '',
    [int]$Trials = 3,
    [int]$Warmups = 2,
    [double]$LogicalUnitsPerCm = 35.0
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$godot = Join-Path $repoRoot 'Godot_v4.6-stable_win64_console.exe'
$project = Join-Path $repoRoot 'testgame/testgame'
$harness = 'res://tests/physical_screen_size_experiment/run_physical_screen_size_experiment.gd'
$sessionDir = Join-Path $PSScriptRoot "data/$Session"
if ([string]::IsNullOrWhiteSpace($InventoryPath)) {
    $InventoryPath = Join-Path $sessionDir 'devices.csv'
}
$InventoryPath = [IO.Path]::GetFullPath($InventoryPath)

if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) { throw "Godot executable not found: $godot" }
if (-not (Test-Path -LiteralPath $InventoryPath -PathType Leaf)) { throw "Display inventory not found: $InventoryPath" }
if ($Trials -le 0 -or $Warmups -lt 0 -or $LogicalUnitsPerCm -le 0) { throw 'Invalid experiment parameters.' }

$devices = @(Import-Csv -LiteralPath $InventoryPath | Sort-Object {[double]$_.diagonal_in})
if ($devices.Count -eq 0) { throw 'The display inventory is empty.' }
$commit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Unable to resolve the Git commit.' }

foreach ($device in $devices) {
    $slug = ($device.device_key.ToLowerInvariant() -replace '[^a-z0-9_-]', '_')
    $runDir = Join-Path $sessionDir "runs/$slug"
    if (Test-Path -LiteralPath $runDir) {
        throw "Run directory already exists and will not be overwritten: $runDir"
    }
    New-Item -ItemType Directory -Path $runDir -Force | Out-Null

    $env:BT_SCREEN_OUTPUT_DIR = $runDir
    $env:BT_SCREEN_SESSION = $Session
    $env:BT_SCREEN_DEVICE_KEY = $device.device_key
    $env:BT_SCREEN_GDI_NAME = $device.gdi_name
    $env:BT_SCREEN_GODOT_INDEX = $device.godot_index
    $env:BT_SCREEN_MANUFACTURER = $device.manufacturer
    $env:BT_SCREEN_MODEL = $device.model
    $env:BT_SCREEN_SERIAL = $device.serial
    $env:BT_SCREEN_WIDTH_CM = $device.width_cm
    $env:BT_SCREEN_HEIGHT_CM = $device.height_cm
    $env:BT_SCREEN_POSITION_X = $device.position_x
    $env:BT_SCREEN_POSITION_Y = $device.position_y
    $env:BT_SCREEN_NATIVE_WIDTH = $device.native_width
    $env:BT_SCREEN_NATIVE_HEIGHT = $device.native_height
    $env:BT_SCREEN_REFRESH_HZ = $device.refresh_hz
    $env:BT_SCREEN_LOGICAL_UNITS_PER_CM = [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $LogicalUnitsPerCm)
    $env:BT_SCREEN_WARMUPS = $Warmups
    $env:BT_SCREEN_TRIALS = $Trials
    $env:BT_SCREEN_GIT_COMMIT = $commit

    $logPath = Join-Path $runDir 'godot.log'
    Write-Output "PHYSICAL_SCREEN_RUN_START device=$($device.device_key) diagonal=$($device.diagonal_in)in godot_index=$($device.godot_index)"
    & $godot --rendering-method gl_compatibility --audio-driver Dummy --screen $device.godot_index --path $project --script $harness 2>&1 |
        Tee-Object -FilePath $logPath
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) { throw "Godot run failed for $($device.device_key) with exit code $exitCode" }
    $logText = Get-Content -LiteralPath $logPath -Raw
    if ($logText -match '(?m)^(ERROR:|SCRIPT ERROR:|FAIL:)' -or $logText -match 'native crash|illegal memory|leaked instance') {
        throw "Failure marker found in $logPath"
    }
    $rawCount = @(Import-Csv -LiteralPath (Join-Path $runDir 'raw.csv')).Count
    $expectedCount = 5 * 6 * $Trials
    if ($rawCount -ne $expectedCount) { throw "Expected $expectedCount raw rows for $($device.device_key), found $rawCount" }
    Write-Output "PHYSICAL_SCREEN_RUN_OK device=$($device.device_key) observations=$rawCount"
}

& python (Join-Path $PSScriptRoot 'analyze_results.py') $sessionDir
if ($LASTEXITCODE -ne 0) { throw "Analysis failed with exit code $LASTEXITCODE" }
Write-Output "PHYSICAL_SCREEN_SESSION_OK devices=$($devices.Count) session=$Session output=$sessionDir"
