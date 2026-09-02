param(
    [Parameter(Mandatory = $false)]
    [string]$InstallerPath = '.\dist-installer\TrayVoha-Setup-x64.exe',

    [Parameter(Mandatory = $false)]
    [string]$PayloadPath = '.\dist-ci\TrayVoha.exe',

    [Parameter(Mandatory = $false)]
    [string]$ReportPath = '.\dist-ci\installer-audit.txt'
)

$ErrorActionPreference = 'Stop'

$installer = (Resolve-Path $InstallerPath).Path
$payload = (Resolve-Path $PayloadPath).Path
$report = [System.IO.Path]::GetFullPath($ReportPath)
$reportDir = Split-Path -Parent $report
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$installDir = Join-Path $env:ProgramFiles 'TrayVoha'
$installedExe = Join-Path $installDir 'TrayVoha.exe'
$uninstaller = Join-Path $installDir 'unins000.exe'
$startMenuShortcut = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\TrayVoha.lnk'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$settingsDir = Join-Path $env:APPDATA 'TrayVoha'
$sentinel = Join-Path $settingsDir 'installer-audit-sentinel.txt'

function Get-RunValue {
    try {
        return (Get-ItemProperty -Path $runKey -Name 'TrayVoha' -ErrorAction Stop).TrayVoha
    }
    catch {
        return $null
    }
}

function Get-UninstallEntry {
    $roots = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($root in $roots) {
        $match = Get-ItemProperty $root -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -eq 'TrayVoha' } |
            Select-Object -First 1
        if ($match) {
            return $match
        }
    }

    return $null
}

$payloadHash = (Get-FileHash $payload -Algorithm SHA256).Hash.ToLowerInvariant()
$installerHash = (Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant()
$runBefore = Get-RunValue

@(
    "PayloadSHA256=$payloadHash"
    "InstallerSHA256=$installerHash"
    "InstallDir=$installDir"
    "RunValueBefore=$runBefore"
) | Set-Content -Encoding utf8 $report

try {
    if (Test-Path $installDir) {
        throw "Каталог встановлення вже існує до тесту: $installDir"
    }

    New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
    'preserve-me' | Set-Content -Encoding utf8 $sentinel

    $install = Start-Process -FilePath $installer `
        -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-' `
        -Wait -PassThru
    "InstallExitCode=$($install.ExitCode)" | Add-Content -Encoding utf8 $report
    if ($install.ExitCode -ne 0) {
        throw "Інсталятор завершився з кодом $($install.ExitCode)."
    }

    if (-not (Test-Path $installedExe)) {
        throw "Після встановлення не знайдено $installedExe"
    }
    if (-not (Test-Path $uninstaller)) {
        throw "Після встановлення не знайдено $uninstaller"
    }

    $installedHash = (Get-FileHash $installedExe -Algorithm SHA256).Hash.ToLowerInvariant()
    "InstalledPayloadSHA256=$installedHash" | Add-Content -Encoding utf8 $report
    if ($installedHash -ne $payloadHash) {
        throw 'Хеш встановленого TrayVoha.exe не збігається з перевіреним payload.'
    }

    $entry = Get-UninstallEntry
    if (-not $entry) {
        throw 'Не знайдено uninstall entry для TrayVoha.'
    }
    "UninstallDisplayName=$($entry.DisplayName)" | Add-Content -Encoding utf8 $report
    "UninstallDisplayVersion=$($entry.DisplayVersion)" | Add-Content -Encoding utf8 $report
    "UninstallString=$($entry.UninstallString)" | Add-Content -Encoding utf8 $report

    if (-not (Test-Path $startMenuShortcut)) {
        throw "Не знайдено ярлик меню Пуск: $startMenuShortcut"
    }
    'StartMenuShortcut=PASS' | Add-Content -Encoding utf8 $report

    $runAfterInstall = Get-RunValue
    "RunValueAfterInstall=$runAfterInstall" | Add-Content -Encoding utf8 $report
    if ($runAfterInstall -ne $runBefore) {
        throw 'Інсталятор самовільно змінив HKCU Run для TrayVoha.'
    }

    $uninstall = Start-Process -FilePath $uninstaller `
        -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' `
        -Wait -PassThru
    "UninstallExitCode=$($uninstall.ExitCode)" | Add-Content -Encoding utf8 $report
    if ($uninstall.ExitCode -ne 0) {
        throw "Деінсталятор завершився з кодом $($uninstall.ExitCode)."
    }

    Start-Sleep -Seconds 2

    if (Test-Path $installedExe) {
        throw 'TrayVoha.exe залишився після деінсталяції.'
    }
    if (Test-Path $installDir) {
        $remaining = @(Get-ChildItem -Force $installDir -ErrorAction SilentlyContinue)
        if ($remaining.Count -ne 0) {
            throw "Каталог встановлення не очищено після деінсталяції: $installDir"
        }
        Remove-Item -Force $installDir -ErrorAction SilentlyContinue
    }

    if (Get-UninstallEntry) {
        throw 'Uninstall entry залишився після деінсталяції.'
    }
    if (Test-Path $startMenuShortcut) {
        throw 'Ярлик меню Пуск залишився після деінсталяції.'
    }

    $runAfterUninstall = Get-RunValue
    "RunValueAfterUninstall=$runAfterUninstall" | Add-Content -Encoding utf8 $report
    if ($runAfterUninstall -ne $runBefore) {
        throw 'Деінсталятор змінив HKCU Run для TrayVoha.'
    }

    if (-not (Test-Path $sentinel)) {
        throw 'Деінсталятор видалив локальні дані користувача TrayVoha.'
    }
    'UserDataPreserved=PASS' | Add-Content -Encoding utf8 $report
    'InstallerInvariant=INSTALL_HASH_UNINSTALL_PASS' | Add-Content -Encoding utf8 $report
    'AuditResult=PASS' | Add-Content -Encoding utf8 $report
}
catch {
    'AuditResult=FAIL' | Add-Content -Encoding utf8 $report
    Get-Content $report | Write-Host
    throw
}
finally {
    if (Test-Path $uninstaller) {
        try {
            Start-Process -FilePath $uninstaller `
                -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' `
                -Wait -ErrorAction SilentlyContinue | Out-Null
        }
        catch {
        }
    }

    Remove-Item -Force $sentinel -ErrorAction SilentlyContinue
}

Get-Content $report
