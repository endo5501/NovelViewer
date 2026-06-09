; Inno Setup 6 script for NovelViewer Windows installer
;
; Usage:
;   ISCC.exe installer\novel_viewer.iss /DAppVersion=1.2.3
;
; If /DAppVersion is omitted, MyAppVersion (0.0.0) is used. Per-user install
; (no UAC), output is written to repo root as novel_viewer-setup-v<version>.exe.

#define MyAppName "NovelViewer"
#define MyAppPublisher "com.endo5501"
#define MyAppURL "https://github.com/endo5501/NovelViewer"
#define MyAppExeName "novel_viewer.exe"
#define MyAppVersion "0.0.0"

#ifndef AppVersion
  #define AppVersion MyAppVersion
#endif

; Strip pre-release suffix (e.g. "1.2.3-rc1" -> "1.2.3") for VersionInfoVersion,
; which requires a numeric x.x[.x[.x]] form. The trailing "-" trick makes Pos
; always find a match so Copy returns the full version when there is no suffix.
#define VersionForInfo Copy(AppVersion, 1, Pos("-", AppVersion + "-") - 1)

[Setup]
; AppId uniquely identifies this application. NEVER change this GUID across
; releases; Inno Setup uses it to detect existing installs and upgrade in place.
AppId={{B7A0E4F2-9C8D-4E3B-A1F5-6D2C8E0B5A39}
AppName={#MyAppName}
AppVersion={#AppVersion}
VersionInfoVersion={#VersionForInfo}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={userpf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..
OutputBaseFilename=novel_viewer-setup-v{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Registry]
; Mark this install as "installer" so the app can distinguish an installed
; copy from a portable ZIP extraction and enable the in-app auto-update flow.
; uninsdeletekey removes it on uninstall, so a later ZIP run is treated as
; portable again.
Root: HKCU; Subkey: "Software\NovelViewer"; ValueType: string; ValueName: "InstallType"; ValueData: "installer"; Flags: uninsdeletekey

[Files]
; Whitelist approach: only ship Flutter build artifacts. User-created data
; (NovelViewer\, models\, voices\, novel_metadata.db) lives at {app} and
; sibling locations at runtime and is intentionally NOT matched here, so the
; installer never sees it on packaging and the uninstaller never removes it.
Source: "..\build\windows\x64\runner\Release\novel_viewer.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
; License files are copied into the Release tree by CI before ISCC runs. The
; skipifsourcedoesntexist flag lets developers compile locally without first
; running the license-copy scripts; CI enforces their presence separately.
Source: "..\build\windows\x64\runner\Release\*_LICENSE_*.txt"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; postinstall = invoked from the Wizard's Finished page (interactive installs).
; IMPORTANT: postinstall entries are executed by DEFAULT during silent installs
; too (the hidden Finished-page checkbox is treated as checked); skipifsilent is
; required to suppress them. Without it this entry AND the [Code] launch below
; would both fire under /SILENT /UPDATELAUNCH, opening two windows. So:
;   - interactive install -> this [Run] entry launches the app (once)
;   - /SILENT (+/UPDATELAUNCH) -> this entry is skipped; [Code] handles the launch
;   - plain /SILENT (winget, choco, RMM) -> neither fires; app is not relaunched
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[Code]
var
  UpdateLaunchRequested: Boolean;

function InitializeSetup(): Boolean;
var
  I: Integer;
begin
  UpdateLaunchRequested := False;
  for I := 1 to ParamCount do
    if CompareText(ParamStr(I), '/UPDATELAUNCH') = 0 then
      UpdateLaunchRequested := True;
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if (CurStep = ssPostInstall) and WizardSilent and UpdateLaunchRequested then
    Exec(ExpandConstant('{app}\{#MyAppExeName}'), '', ExpandConstant('{app}'),
         SW_SHOW, ewNoWait, ResultCode);
end;
