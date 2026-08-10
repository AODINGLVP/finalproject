$ErrorActionPreference = 'Stop'

$inputPath = (Resolve-Path "$PSScriptRoot\..\BEHAVIOR_TREE_PLUGIN_FUNCTIONS_ZH.docx").Path
$outputDir = Join-Path $PSScriptRoot '..\plugin_functions_render_final'
$outputDir = [System.IO.Path]::GetFullPath($outputDir)
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$pdfPath = Join-Path $outputDir 'plugin-functions.pdf'
$tempDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\.codex_tmp\plugin_functions_word_render'))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$renderInput = Join-Path $tempDir 'render-input.docx'
Copy-Item -LiteralPath $inputPath -Destination $renderInput -Force

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
try {
    $document = $word.Documents.Open($renderInput, $false, $true)
    $document.ExportAsFixedFormat($pdfPath, 17)
    $document.Close($false)
} finally {
    $word.Quit()
    Remove-Item -LiteralPath $renderInput -Force -ErrorAction SilentlyContinue
}

Write-Output $pdfPath
