param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDirectory,

    [Parameter(Mandatory = $true)]
    [string]$DeliveryPdf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$tectonic = Join-Path $repoRoot '.codex_tmp\tectonic-0.17.0\tectonic.exe'
if (-not (Test-Path -LiteralPath $tectonic -PathType Leaf)) {
    throw "Portable Tectonic was not found: $tectonic"
}

$source = (Resolve-Path -LiteralPath $SourceDirectory).Path
$main = Join-Path $source 'supervisor_review.tex'
if (-not (Test-Path -LiteralPath $main -PathType Leaf)) {
    throw "Supervisor LaTeX entry point was not found: $main"
}

Push-Location $source
try {
    & $tectonic -X compile 'supervisor_review.tex' --keep-logs --keep-intermediates
    if ($LASTEXITCODE -ne 0) {
        throw "Tectonic failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

$builtPdf = Join-Path $source 'supervisor_review.pdf'
if (-not (Test-Path -LiteralPath $builtPdf -PathType Leaf)) {
    throw "Tectonic did not produce the expected PDF: $builtPdf"
}

$delivery = [IO.Path]::GetFullPath($DeliveryPdf)
$deliveryDirectory = Split-Path -Parent $delivery
if (-not (Test-Path -LiteralPath $deliveryDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $deliveryDirectory | Out-Null
}
Copy-Item -LiteralPath $builtPdf -Destination $delivery -Force

$log = Join-Path $source 'supervisor_review.log'
if (Test-Path -LiteralPath $log -PathType Leaf) {
    $failurePatterns = '(^|\s)(! LaTeX Error:|Emergency stop|Fatal error|Undefined control sequence|Overfull \\hbox)'
    $failures = Select-String -LiteralPath $log -Pattern $failurePatterns
    if ($failures) {
        throw "The LaTeX log contains fatal errors: $($failures.Line -join '; ')"
    }
}

$hash = (Get-FileHash -LiteralPath $delivery -Algorithm SHA256).Hash
$size = (Get-Item -LiteralPath $delivery).Length
Write-Output "SUPERVISOR_PDF=$delivery"
Write-Output "SUPERVISOR_PDF_BYTES=$size"
Write-Output "SUPERVISOR_PDF_SHA256=$hash"
Write-Output 'SUPERVISOR_PDF_BUILD=PASS'
