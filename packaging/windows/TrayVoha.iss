#define MyAppName "TrayVoha"
#define MyAppVersion "1.5.0"
#define MyAppExeName "TrayVoha.exe"

[Setup]
AppId={{6A1B96ED-7D59-4B1C-8C38-56E19B046901}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher=TrayVoha
DefaultDirName={autopf}\TrayVoha
DefaultGroupName=TrayVoha
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\dist-installer
OutputBaseFilename=TrayVoha-Setup-x64
SetupIconFile=..\..\assets\windows\trayvoha.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
ChangesAssociations=no
ChangesEnvironment=no

[Languages]
Name: "ukrainian"; MessagesFile: "compiler:Languages\Ukrainian.isl"

[Tasks]
Name: "desktopicon"; Description: "Створити ярлик на робочому столі"; GroupDescription: "Додаткові ярлики:"; Flags: unchecked

[Files]
Source: "..\..\dist-ci\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\TrayVoha"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\TrayVoha"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Запустити TrayVoha"; Flags: nowait postinstall skipifsilent
