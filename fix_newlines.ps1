$path = ".github/workflows/main.yml"
if (Test-Path $path) {
    $content = [System.IO.File]::ReadAllText($path)
    if ($content -match "`r`n") {
        $content = $content.Replace("`r`n", "`n")
        [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding $false))
        Write-Host "Fixed CRLF in $path"
    } else {
        Write-Host "$path already has LF"
    }
} else {
    Write-Host "File not found: $path"
}
