; Inno Setup Script for Personal Finance Application
; Produces a modern Windows Setup Wizard (.exe) with Next -> Next -> Install flow
; and mandatory License / Terms & Conditions acceptance.

#define MyAppName "Personal Finance"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#define MyAppPublisher "Personal Finance"
#define MyAppExeName "personal_finance.exe"
#ifndef MyAppSourceDir
  #define MyAppSourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef MyAppOutputDir
  #define MyAppOutputDir "."
#endif
#ifndef MyAppOutputBaseFilename
  #define MyAppOutputBaseFilename "26_3_PersonalFinance-Windows-x64"
#endif

[Setup]
AppId={{C7A9F32E-14D5-42E1-9428-A68B8E88E5F1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=LICENSE.txt
OutputDir={#MyAppOutputDir}
OutputBaseFilename={#MyAppOutputBaseFilename}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog
PrivilegesRequired=lowest
CloseApplications=yes
RestartIfNeededByRun=no
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyAppSourceDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppSourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.db,*.sqlite,*.sqlite3,*.db-journal,*.db-wal,*.db-shm,.portable,portable.txt"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
