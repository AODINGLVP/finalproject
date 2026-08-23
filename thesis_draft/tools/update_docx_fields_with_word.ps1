param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
$word.AutomationSecurity = 3

try {
    foreach ($item in $Path) {
        $resolved = (Resolve-Path -LiteralPath $item).Path
        $document = $word.Documents.Open($resolved, $false, $false)
        try {
            for ($index = 1; $index -le $document.TablesOfContents.Count; $index++) {
                $document.TablesOfContents.Item($index).Update() | Out-Null
            }
            $document.Fields.Update() | Out-Null
            $document.Repaginate()
            $document.Save()
            Write-Output "DOCX_FIELDS_UPDATED=$resolved"
            Write-Output "TOC_FIELDS=$($document.TablesOfContents.Count)"
        }
        finally {
            $document.Close(0)
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($document)
        }
    }
}
finally {
    $word.Quit()
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($word)
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
