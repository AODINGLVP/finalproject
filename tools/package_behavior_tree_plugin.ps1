[CmdletBinding()]
param(
    [string]$OutputDirectory = "dist",
    [string]$ValidationDirectory = "testgame/testgame/test_results/second_phase_task3",
    [string]$WorkingDirectory = ".codex_tmp/behavior_tree_plugin_package",
    [string]$GodotPath = "Godot_v4.6-stable_win64_console.exe",
    [switch]$SkipCleanInstall
)

$ErrorActionPreference = "Stop"
$script:Passed = 0
$script:Failed = 0

function Assert-Check {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        $script:Passed += 1
        Write-Host "PASS: $Message"
    } else {
        $script:Failed += 1
        Write-Host "FAIL: $Message"
    }
}

function Normalize-RelativePath {
    param([string]$Path)
    return $Path.Replace("\", "/")
}

function Assert-ChildPath {
    param([string]$Parent, [string]$Child)
    $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $childFull = [IO.Path]::GetFullPath($Child)
    if (-not $childFull.StartsWith($parentFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe generated path outside validation directory: $childFull"
    }
}

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$source = Join-Path $repoRoot "visual_scripting/addons/behavior_tree_editor"
$outputRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot $OutputDirectory))
$validationRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot $ValidationDirectory))
$workingRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot $WorkingDirectory))
$godot = [IO.Path]::GetFullPath((Join-Path $repoRoot $GodotPath))

Assert-Check (Test-Path -LiteralPath $source -PathType Container) "plugin source directory exists"
Assert-Check (Test-Path -LiteralPath $godot -PathType Leaf) "Godot executable exists"

$pluginConfig = Join-Path $source "plugin.cfg"
$configText = Get-Content -LiteralPath $pluginConfig -Raw
$versionMatch = [regex]::Match($configText, 'version="([^"]+)"')
Assert-Check $versionMatch.Success "plugin.cfg declares a version"
$version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "unknown" }

New-Item -ItemType Directory -Force -Path $outputRoot, $validationRoot, $workingRoot | Out-Null
$stagingRoot = Join-Path $workingRoot "package_staging"
$extractRoot = Join-Path $workingRoot "package_extract"
$cleanProject = Join-Path $workingRoot "clean_install_project"
foreach ($generatedPath in @($stagingRoot, $extractRoot, $cleanProject)) {
    Assert-ChildPath $workingRoot $generatedPath
    if (Test-Path -LiteralPath $generatedPath) {
        Remove-Item -LiteralPath $generatedPath -Recurse -Force
    }
}

$stagedPlugin = Join-Path $stagingRoot "addons/behavior_tree_editor"
New-Item -ItemType Directory -Force -Path $stagedPlugin | Out-Null
Get-ChildItem -LiteralPath $source -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $stagedPlugin -Recurse -Force
}

$allowedExtensions = @(".gd", ".uid", ".cfg", ".md", ".txt")
$sourceFiles = Get-ChildItem -LiteralPath $stagedPlugin -Recurse -File
$invalidFiles = @($sourceFiles | Where-Object { $allowedExtensions -notcontains $_.Extension.ToLowerInvariant() })
Assert-Check ($invalidFiles.Count -eq 0) "package source contains only approved file types"

$requiredFiles = @(
    "plugin.cfg",
    "plugin.gd",
    "bt_tree_resource.gd",
    "bt_node_resource.gd",
    "bt_blackboard_schema.gd",
    "bt_blackboard_entry.gd",
    "runtime/behavior_tree_component.gd",
    "runtime/behavior_tree_runner.gd",
    "runtime/bt_status.gd",
    "README.md",
    "LICENSE.txt"
)
foreach ($required in $requiredFiles) {
    Assert-Check (Test-Path -LiteralPath (Join-Path $stagedPlugin $required) -PathType Leaf) "required file: $required"
}

$manifestEntries = @()
foreach ($file in (Get-ChildItem -LiteralPath $stagedPlugin -Recurse -File | Sort-Object FullName)) {
    $relative = Normalize-RelativePath $file.FullName.Substring($stagedPlugin.Length + 1)
    $manifestEntries += [ordered]@{
        path = $relative
        size = $file.Length
        sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
$manifest = [ordered]@{
    package = "behavior-tree-editor"
    version = $version
    godot = "4.6"
    entry_point = "addons/behavior_tree_editor/plugin.cfg"
    generated_utc = [DateTime]::UtcNow.ToString("o")
    files = $manifestEntries
}
$manifestPath = Join-Path $stagedPlugin "PACKAGE_MANIFEST.json"
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding utf8

$zipPath = Join-Path $outputRoot "behavior-tree-editor-$version.zip"
if (Test-Path -LiteralPath $zipPath) {
    Assert-ChildPath $outputRoot $zipPath
    Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -LiteralPath (Join-Path $stagingRoot "addons") -DestinationPath $zipPath -CompressionLevel Optimal
Assert-Check (Test-Path -LiteralPath $zipPath -PathType Leaf) "versioned ZIP package is generated"

New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force
$zipFiles = @(Get-ChildItem -LiteralPath $extractRoot -Recurse -File)
$outsidePlugin = @($zipFiles | Where-Object {
    (Normalize-RelativePath $_.FullName.Substring($extractRoot.Length + 1)) -notlike "addons/behavior_tree_editor/*"
})
Assert-Check ($outsidePlugin.Count -eq 0) "ZIP contains only addons/behavior_tree_editor"

$extractedPlugin = Join-Path $extractRoot "addons/behavior_tree_editor"
$extractedManifest = Get-Content -LiteralPath (Join-Path $extractedPlugin "PACKAGE_MANIFEST.json") -Raw | ConvertFrom-Json
Assert-Check ($extractedManifest.version -eq $version) "package manifest version matches plugin.cfg"
Assert-Check ($extractedManifest.godot -eq "4.6") "package manifest declares Godot 4.6"
foreach ($entry in $extractedManifest.files) {
    $filePath = Join-Path $extractedPlugin $entry.path
    $hashMatches = (Test-Path -LiteralPath $filePath -PathType Leaf) -and
        ((Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant() -eq $entry.sha256)
    Assert-Check $hashMatches "manifest hash: $($entry.path)"
}

$cleanInstallLog = Join-Path $validationRoot "clean_install_editor.log"
if (-not $SkipCleanInstall) {
    New-Item -ItemType Directory -Force -Path $cleanProject | Out-Null
    Copy-Item -LiteralPath (Join-Path $extractRoot "addons") -Destination $cleanProject -Recurse -Force
    @'
config_version=5

[application]
config/name="BehaviorTreePluginCleanInstall"
config/features=PackedStringArray("4.6")

[editor_plugins]
enabled=PackedStringArray("res://addons/behavior_tree_editor/plugin.cfg")

[rendering]
renderer/rendering_method="gl_compatibility"
'@ | Set-Content -LiteralPath (Join-Path $cleanProject "project.godot") -Encoding utf8

    & $godot --headless --audio-driver Dummy --path $cleanProject --editor --quit-after 8 --log-file $cleanInstallLog
    $godotExitCode = $LASTEXITCODE
    Assert-Check ($godotExitCode -eq 0) "clean project editor exits successfully"
    $logText = if (Test-Path -LiteralPath $cleanInstallLog) { Get-Content -LiteralPath $cleanInstallLog -Raw } else { "" }
    $fatalPattern = '(?im)^\s*(FAIL:|ERROR:|SCRIPT ERROR:)|access violation|segmentation fault|crash|leaked instance|resources still in use'
    Assert-Check (-not [regex]::IsMatch($logText, $fatalPattern)) "clean project log has no failures, script errors, leaks, or crashes"
    Assert-Check (Test-Path -LiteralPath (Join-Path $cleanProject ".godot") -PathType Container) "Godot imported the clean project"
}

$result = [ordered]@{
    package = $zipPath
    package_sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    version = $version
    source_file_count = $sourceFiles.Count
    archive_file_count = $zipFiles.Count
    clean_install_tested = -not $SkipCleanInstall
    passed = $script:Passed
    failed = $script:Failed
}
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $validationRoot "package_validation_result.json") -Encoding utf8
Write-Host "BT_PACKAGE_VALIDATION_SUMMARY passed=$($script:Passed) failed=$($script:Failed) package=$zipPath"
if ($script:Failed -gt 0) {
    exit 1
}
