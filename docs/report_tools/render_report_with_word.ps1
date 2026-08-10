$ErrorActionPreference = 'Stop'

$inputPath = (Resolve-Path "$PSScriptRoot\..\Godot_Behavior_Tree_Plugin_Complete_Report.docx").Path
$outputDir = Join-Path $PSScriptRoot '..\report_render'
$outputDir = [System.IO.Path]::GetFullPath($outputDir)
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$pdfPath = Join-Path $outputDir 'Godot_Behavior_Tree_Plugin_Complete_Report.pdf'
$tempDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\.codex_tmp\report_word_render'))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$renderInput = Join-Path $tempDir 'render-input.docx'
Copy-Item -LiteralPath $inputPath -Destination $renderInput -Force

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
try {
    # A copied path avoids Word's recovery cache for a repeatedly regenerated file.
    $document = $word.Documents.Open($renderInput, $false, $true)
    $document.ExportAsFixedFormat($pdfPath, 17)
    $document.Close($false)
} finally {
    $word.Quit()
    Remove-Item -LiteralPath $renderInput -Force -ErrorAction SilentlyContinue
}

Write-Output $pdfPath
