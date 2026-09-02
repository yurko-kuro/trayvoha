$ErrorActionPreference = 'Stop'

param(
    [Parameter(Mandatory = $false)]
    [string]$ExePath = '.\dist-ci\TrayVoha.exe',

    [Parameter(Mandatory = $false)]
    [string]$ReportPath = '.\dist-ci\runtime-audit.txt'
)

$exe = (Resolve-Path $ExePath).Path
$report = [System.IO.Path]::GetFullPath($ReportPath)
$reportDir = Split-Path -Parent $report
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$version = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exe)
$hash = (Get-FileHash $exe -Algorithm SHA256).Hash.ToLowerInvariant()
$signature = Get-AuthenticodeSignature $exe

$neptunHost = 'neptun.in.ua'
$neptunAddresses = @(
    [System.Net.Dns]::GetHostAddresses($neptunHost) |
        ForEach-Object { $_.ToString() } |
        Sort-Object -Unique
)

if ($neptunAddresses.Count -eq 0) {
    throw 'Не вдалося отримати IP-адреси NEPTUN.'
}

@(
    "SHA256=$hash"
    "FileVersion=$($version.FileVersion)"
    "ProductVersion=$($version.ProductVersion)"
    "ProductName=$($version.ProductName)"
    "OriginalFilename=$($version.OriginalFilename)"
    "SignatureStatus=$($signature.Status)"
    "Signer=$($signature.SignerCertificate.Subject)"
    "NeptunHost=$neptunHost"
    "NeptunAddresses=$($neptunAddresses -join ',')"
) | Set-Content -Encoding utf8 $report

if ($version.ProductName -ne 'TrayVoha') {
    throw "Неочікуваний ProductName: $($version.ProductName)"
}
if (-not $version.ProductVersion.StartsWith('1.5.0')) {
    throw "Неочікуваний ProductVersion: $($version.ProductVersion)"
}

$settingsDir = Join-Path $env:APPDATA 'TrayVoha'
New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
@'
{
  "Version": 2,
  "SetupCompleted": true,
  "SelectedAreaKeys": [
    "raion:запорізький"
  ]
}
'@ | Set-Content -Encoding utf8 (Join-Path $settingsDir 'settings.json')

$p = Start-Process -FilePath $exe -PassThru
$observedTcp = New-Object System.Collections.Generic.List[object]

try {
    for ($i = 0; $i -lt 200; $i++) {
        Start-Sleep -Milliseconds 100
        $p.Refresh()
        if ($p.HasExited) {
            throw "TrayVoha завершився під час runtime-аудиту з кодом $($p.ExitCode)"
        }

        $sample = @(Get-NetTCPConnection -OwningProcess $p.Id -ErrorAction SilentlyContinue)
        foreach ($connection in $sample) {
            if ($connection.State -ne 'Listen') {
                $observedTcp.Add([pscustomobject]@{
                    State = [string]$connection.State
                    LocalAddress = [string]$connection.LocalAddress
                    LocalPort = [int]$connection.LocalPort
                    RemoteAddress = [string]$connection.RemoteAddress
                    RemotePort = [int]$connection.RemotePort
                })
            }
        }
    }

    "PID=$($p.Id)" | Add-Content -Encoding utf8 $report

    $children = @(Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $p.Id })
    "ChildProcessCount=$($children.Count)" | Add-Content -Encoding utf8 $report
    $children | Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine |
        Format-List | Out-String | Add-Content -Encoding utf8 $report
    if ($children.Count -ne 0) {
        throw 'TrayVoha створив дочірній процес під час runtime-аудиту.'
    }

    $currentTcp = @(Get-NetTCPConnection -OwningProcess $p.Id -ErrorAction SilentlyContinue)
    $udp = @(Get-NetUDPEndpoint -OwningProcess $p.Id -ErrorAction SilentlyContinue)
    $listeners = @($currentTcp | Where-Object State -eq 'Listen')

    "TcpObservedCount=$($observedTcp.Count)" | Add-Content -Encoding utf8 $report
    "UdpCount=$($udp.Count)" | Add-Content -Encoding utf8 $report
    "TcpListenCount=$($listeners.Count)" | Add-Content -Encoding utf8 $report

    $uniqueTcp = @(
        $observedTcp |
            Sort-Object State, LocalAddress, LocalPort, RemoteAddress, RemotePort -Unique
    )

    '--- OBSERVED TCP ---' | Add-Content -Encoding utf8 $report
    $uniqueTcp |
        Format-Table -AutoSize |
        Out-String |
        Add-Content -Encoding utf8 $report

    '--- UDP ---' | Add-Content -Encoding utf8 $report
    $udp | Select-Object LocalAddress, LocalPort |
        Format-Table -AutoSize | Out-String | Add-Content -Encoding utf8 $report

    if ($listeners.Count -ne 0) {
        throw 'TrayVoha відкрив вхідний TCP listener.'
    }
    if ($udp.Count -ne 0) {
        throw 'TrayVoha відкрив UDP endpoint.'
    }
    if ($uniqueTcp.Count -eq 0) {
        throw 'Не зафіксовано жодного вихідного TCP-з’єднання TrayVoha.'
    }

    $unexpected = @(
        $uniqueTcp | Where-Object {
            $_.RemotePort -ne 443 -or $_.RemoteAddress -notin $neptunAddresses
        }
    )

    if ($unexpected.Count -ne 0) {
        '--- UNEXPECTED TCP ---' | Add-Content -Encoding utf8 $report
        $unexpected |
            Format-Table -AutoSize |
            Out-String |
            Add-Content -Encoding utf8 $report
        throw 'TrayVoha встановив TCP-з’єднання не з дозволеним NEPTUN:443.'
    }

    "NetworkInvariant=ONLY_NEPTUN_443" | Add-Content -Encoding utf8 $report
}
finally {
    if (-not $p.HasExited) {
        Stop-Process -Id $p.Id -Force
    }
}

Get-Content $report
