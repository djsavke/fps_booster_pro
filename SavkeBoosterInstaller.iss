; Savke FPS Booster PRO - Inno Setup script (stub)
[Setup]
AppName=Savke FPS Booster PRO
AppVersion=6.0.0
DefaultDirName={pf}\SavkeFPSBooster
DefaultGroupName=Savke FPS Booster PRO
OutputBaseFilename=Savke_FPS_Booster_PRO_Installer
Compression=lzma
SolidCompression=yes

[Files]
Source: "Savke_FPS_Booster_PRO_v6_0.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Savke FPS Booster PRO"; Filename: "{app}\Savke_FPS_Booster_PRO_v6_0.exe"
Name: "{commondesktop}\Savke FPS Booster PRO"; Filename: "{app}\Savke_FPS_Booster_PRO_v6_0.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; GroupDescription: "Additional icons:"
