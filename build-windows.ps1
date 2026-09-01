$ErrorActionPreference = "Stop"

$project = Join-Path $PSScriptRoot "NeptunTray.csproj"
$output = Join-Path $PSScriptRoot "dist"

dotnet publish $project `
    --configuration Release `
    --runtime win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    --output $output

Write-Host ""
Write-Host "READY: $output\AlertTray.exe"
