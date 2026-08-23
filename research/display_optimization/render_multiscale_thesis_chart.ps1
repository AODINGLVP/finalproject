Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$inputPath = Join-Path $repositoryRoot 'testgame\testgame\test_results\multiscale_display_trends.csv'
$sharedOutput = Join-Path $repositoryRoot 'thesis_draft\shared\figures\optimization_ratios.png'
$englishOutput = Join-Path $repositoryRoot 'thesis_draft\english\figures\optimization_ratios.png'
$chineseOutput = Join-Path $repositoryRoot 'thesis_draft\chinese\figures\optimization_ratios.png'

$rows = @(Import-Csv -LiteralPath $inputPath | Sort-Object { [int]$_.tree_size })
if ($rows.Count -ne 5) {
    throw "Expected five trend rows, found $($rows.Count)."
}

$width = 1600
$height = 900
$left = 150.0
$right = 80.0
$top = 170.0
$bottom = 120.0
$plotWidth = $width - $left - $right
$plotHeight = $height - $top - $bottom

$bitmap = [System.Drawing.Bitmap]::new($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$graphics.Clear([System.Drawing.Color]::White)

$titleFont = [System.Drawing.Font]::new('Segoe UI', 34, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$axisFont = [System.Drawing.Font]::new('Segoe UI', 22, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$legendFont = [System.Drawing.Font]::new('Segoe UI', 20, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$noteFont = [System.Drawing.Font]::new('Segoe UI', 17, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$blackBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(35, 35, 35))
$greyBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(90, 90, 90))
$gridPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(225, 225, 225), 1.0)
$axisPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(55, 55, 55), 2.0)

$title = 'Display Effects Across Controlled Tree Sizes'
$titleSize = $graphics.MeasureString($title, $titleFont)
$graphics.DrawString($title, $titleFont, $blackBrush, ($width - $titleSize.Width) / 2.0, 30.0)

for ($tick = 0; $tick -le 100; $tick += 20) {
    $y = $top + $plotHeight * (1.0 - $tick / 100.0)
    $graphics.DrawLine($gridPen, $left, $y, $left + $plotWidth, $y)
    $label = "$tick"
    $labelSize = $graphics.MeasureString($label, $axisFont)
    $graphics.DrawString($label, $axisFont, $greyBrush, $left - $labelSize.Width - 18.0, $y - $labelSize.Height / 2.0)
}

$graphics.DrawLine($axisPen, $left, $top, $left, $top + $plotHeight)
$graphics.DrawLine($axisPen, $left, $top + $plotHeight, $left + $plotWidth, $top + $plotHeight)

$xPositions = @()
for ($index = 0; $index -lt $rows.Count; $index++) {
    $x = $left + $plotWidth * $index / ($rows.Count - 1)
    $xPositions += $x
    $label = [string]$rows[$index].tree_size
    $labelSize = $graphics.MeasureString($label, $axisFont)
    $graphics.DrawString($label, $axisFont, $blackBrush, $x - $labelSize.Width / 2.0, $top + $plotHeight + 16.0)
}

$xLabel = 'Resource nodes'
$xLabelSize = $graphics.MeasureString($xLabel, $axisFont)
$graphics.DrawString($xLabel, $axisFont, $blackBrush, ($width - $xLabelSize.Width) / 2.0, $height - 62.0)

$yLabel = 'Reduction or dimming (%)'
$graphics.TranslateTransform(38.0, $top + $plotHeight / 2.0)
$graphics.RotateTransform(-90.0)
$yLabelSize = $graphics.MeasureString($yLabel, $axisFont)
$graphics.DrawString($yLabel, $axisFont, $blackBrush, -$yLabelSize.Width / 2.0, 0.0)
$graphics.ResetTransform()

$series = @(
    [pscustomobject]@{ Name = 'Compact area'; Field = 'compact_area_reduction_percent'; Color = [System.Drawing.Color]::FromArgb(0, 114, 178) },
    [pscustomobject]@{ Name = 'Overview area'; Field = 'overview_area_reduction_percent'; Color = [System.Drawing.Color]::FromArgb(213, 94, 0) },
    [pscustomobject]@{ Name = 'Search dimming'; Field = 'search_dimming_percent'; Color = [System.Drawing.Color]::FromArgb(0, 158, 115) },
    [pscustomobject]@{ Name = 'Focus cards'; Field = 'focus_card_reduction_percent'; Color = [System.Drawing.Color]::FromArgb(204, 121, 167) },
    [pscustomobject]@{ Name = 'Collapse cards'; Field = 'collapse_card_reduction_percent'; Color = [System.Drawing.Color]::FromArgb(230, 159, 0) }
)

$legendStart = 165.0
$legendGap = 270.0
for ($seriesIndex = 0; $seriesIndex -lt $series.Count; $seriesIndex++) {
    $entry = $series[$seriesIndex]
    $pen = [System.Drawing.Pen]::new($entry.Color, 4.0)
    $brush = [System.Drawing.SolidBrush]::new($entry.Color)
    $points = [System.Drawing.PointF[]]::new($rows.Count)
    for ($index = 0; $index -lt $rows.Count; $index++) {
        $value = [double]$rows[$index].($entry.Field)
        $x = [single]$xPositions[$index]
        $y = [single]($top + $plotHeight * (1.0 - $value / 100.0))
        $points[$index] = [System.Drawing.PointF]::new($x, $y)
    }
    $graphics.DrawLines($pen, $points)
    foreach ($point in $points) {
        $graphics.FillEllipse($brush, $point.X - 6.0, $point.Y - 6.0, 12.0, 12.0)
    }
    $legendX = $legendStart + $legendGap * $seriesIndex
    $graphics.DrawLine($pen, $legendX, 118.0, $legendX + 38.0, 118.0)
    $graphics.FillEllipse($brush, $legendX + 13.0, 112.0, 12.0, 12.0)
    $graphics.DrawString($entry.Name, $legendFont, $blackBrush, $legendX + 48.0, 103.0)
    $pen.Dispose()
    $brush.Dispose()
}

$note = 'Source: multiscale_display_trends.csv.'
$noteSize = $graphics.MeasureString($note, $noteFont)
$graphics.DrawString($note, $noteFont, $greyBrush, ($width - $noteSize.Width) / 2.0, $height - 28.0)

$sharedDirectory = Split-Path -Parent $sharedOutput
[System.IO.Directory]::CreateDirectory($sharedDirectory) | Out-Null
$bitmap.Save($sharedOutput, [System.Drawing.Imaging.ImageFormat]::Png)

$gridPen.Dispose()
$axisPen.Dispose()
$blackBrush.Dispose()
$greyBrush.Dispose()
$titleFont.Dispose()
$axisFont.Dispose()
$legendFont.Dispose()
$noteFont.Dispose()
$graphics.Dispose()
$bitmap.Dispose()

Copy-Item -LiteralPath $sharedOutput -Destination $englishOutput -Force
Copy-Item -LiteralPath $sharedOutput -Destination $chineseOutput -Force

Write-Output "MULTISCALE_CHART_OK rows=$($rows.Count) output=$sharedOutput"
