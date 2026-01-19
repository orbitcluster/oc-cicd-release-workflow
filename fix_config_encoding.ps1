$f = ".yamllint"
if (Test-Path $f) {
    $enc = New-Object System.Text.UTF8Encoding $false
    $txt = [System.IO.File]::ReadAllText($f)
    $txt = $txt.Replace("`r`n", "`n")
    [System.IO.File]::WriteAllText($f, $txt, $enc)
    Write-Host "Fixed $f"
} else {
    Write-Host "File not found: $f"
}
