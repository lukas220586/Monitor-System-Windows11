; MonitorSystem Pugliese Hardware
; Compila con Inno Setup — Clicca destro su questo file → Compile

#define MyAppName "MonitorSystem Pugliese Hardware"
#define MyAppVersion "1.0"
#define MyAppPublisher "Pugliese Hardware"
#define MyAppURL "https://pugliese-hardware.it"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={commonappdata}\PuglieseHardware\SystemMonitor
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\Output
OutputBaseFilename=MonitorSystem_PuglieseHW_Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={uninstallexe}
PrivilegesRequired=admin
DisableWelcomePage=no

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Tasks]
Name: "autostart"; Description: "Avvia MonitorSystem all&39;accesso di Windows"; GroupDescription: "Avvio automatico:"

[Files]
Source: "..\scripts\send_stats.py"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\scripts\send_stats.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\installer\setup.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\MonitorSystem Pugliese Hardware"; Filename: "python.exe"; Parameters: """{app}\send_stats.py"""; WorkingDir: "{app}"
Name: "{group}\Guida (README)"; Filename: "{app}\README.md"
Name: "{group}\Disinstalla MonitorSystem"; Filename: "{uninstallexe}"

[Run]
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\setup.ps1"""; StatusMsg: "Installazione Python e librerie... Attendere."; Flags: runhidden
Filename: "python.exe"; Parameters: """{app}\send_stats.py"""; Description: "Avvia MonitorSystem ora"; Flags: postinstall nowait skipifsilent runhidden

[UninstallRun]
Filename: "schtasks"; Parameters: "/delete /tn ""MonitorSystem Pugliese Hardware"" /f"; Flags: runhidden

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    if WizardIsTaskSelected('autostart') then
      Exec('schtasks',
        '/create /tn "MonitorSystem Pugliese Hardware" /tr "python.exe ' +
        ExpandConstant('{app}') + '\send_stats.py" /sc onlogon /rl limited /f',
        '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;
