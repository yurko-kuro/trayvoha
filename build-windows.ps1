$ErrorActionPreference = "Stop"

$project = Join-Path $PSScriptRoot "Tryvoha.csproj"
$output = Join-Path $PSScriptRoot "dist\windows"

if (Test-Path $output) {
    Remove-Item -Recurse -Force $output
}

New-Item -ItemType Directory -Force -Path $output | Out-Null

dotnet publish $project `
    --configuration Release `
    --runtime win-x64 `
    --self-contained true `
    -p:PublishSingleFile=false `
    -p:PublishTrimmed=false `
    --output $output

Write-Host ""
Write-Host "READY: $output"
Write-Host "Run: $output\Тривога.exe"
