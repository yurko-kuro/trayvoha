$ErrorActionPreference = "Stop"

$project = Join-Path $PSScriptRoot "TrayVoha.csproj"
$output = Join-Path $PSScriptRoot "dist"
$generator = Join-Path $PSScriptRoot "tools\generate-icon-assets.py"

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command py -ErrorAction SilentlyContinue
}
if (-not $python) {
    throw "Для генерації іконки потрібен Python 3."
}

if ($python.Name -eq "py.exe" -or $python.Name -eq "py") {
    & $python.Source -3 $generator
}
else {
    & $python.Source $generator
}

$icon = Join-Path $PSScriptRoot "assets\windows\trayvoha.ico"
if (-not (Test-Path $icon)) {
    throw "Не вдалося згенерувати Windows-іконку: $icon"
}

dotnet publish $project `
    --configuration Release `
    --runtime win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    --output $output

Write-Host ""
Write-Host "ГОТОВО: $output\TrayVoha.exe"
