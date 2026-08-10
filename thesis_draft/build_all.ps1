$ErrorActionPreference = "Stop"

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$tectonic = Join-Path $repoRoot ".codex_tmp/tectonic-0.17.0/tectonic.exe"
if (-not (Test-Path -LiteralPath $tectonic -PathType Leaf)) {
    throw "Portable Tectonic was not found: $tectonic"
}

foreach ($language in @("english", "chinese")) {
    $source = Join-Path $PSScriptRoot $language
    Push-Location $source
    try {
        & $tectonic -X compile uwthesis.tex --keep-logs
        if ($LASTEXITCODE -ne 0) {
            throw "Tectonic failed for $language with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
}

Write-Output "English: $(Join-Path $PSScriptRoot 'english/uwthesis.pdf')"
Write-Output "Chinese: $(Join-Path $PSScriptRoot 'chinese/uwthesis.pdf')"
