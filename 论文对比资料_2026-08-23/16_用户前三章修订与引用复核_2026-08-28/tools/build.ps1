param(
    [string]$ChineseSource,
    [string]$EnglishSource,
    [string]$OutputDirectory,
    [switch]$SkipPdf,
    [switch]$UpdateWordFields,
    [switch]$SelfTest,
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$versionDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $versionDirectory '..\..'))
$builder = Join-Path $PSScriptRoot 'build_dissertation.py'

$pythonCandidates = @(
    (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'),
    (Get-Command python.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1),
    (Get-Command python -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1)
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }

if (-not $pythonCandidates) {
    throw 'Python with python-docx is required, but no Python executable was found.'
}
$python = $pythonCandidates[0]

if (-not $ChineseSource) {
    $ChineseSource = Join-Path $versionDirectory 'source\论文内容_中文.md'
}
if (-not $EnglishSource) {
    $EnglishSource = Join-Path $versionDirectory 'source\dissertation_content_en.md'
}
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $versionDirectory 'output'
}
$tectonic = Join-Path $repositoryRoot '.codex_tmp\tectonic-0.17.0\tectonic.exe'

$arguments = @(
    $builder,
    '--zh-source', $ChineseSource,
    '--en-source', $EnglishSource,
    '--output-dir', $OutputDirectory,
    '--tectonic', $tectonic
)
if ($SkipPdf) { $arguments += '--skip-pdf' }
if ($UpdateWordFields) { $arguments += '--update-word-fields' }
if ($SelfTest) { $arguments += '--self-test' }
if ($ValidateOnly) { $arguments += '--validate-only' }

& $python @arguments
if ($LASTEXITCODE -ne 0) {
    throw "Dissertation build failed with exit code $LASTEXITCODE"
}
