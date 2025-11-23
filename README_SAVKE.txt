Savke FPS Booster PRO — v6.0 ULTIMATE SMOOTH

Sadrzi:
- Savke_FPS_Booster_PRO_v6_0.ps1  (WPF smooth UI, HUD, tray, monitor, benchmark)
- logo.png                        (mozes da zamenis svojim pravim logoom)
- splash.gif                      (mozes da zamenis svojim pravim splash ekranom)
- update_example/savke_fps_booster_version.txt  (primer za auto-update fajl)
- SavkeBoosterInstaller.iss       (Inno Setup skripta - stub)

Kako da napravis EXE:
1) Otvori PowerShell kao Administrator.
2) cd do foldera gde je ovaj paket.
3) Pokreni:
   Invoke-ps2exe -inputFile ".\Savke_FPS_Booster_PRO_v6_0.ps1" -outputFile ".\Savke_FPS_Booster_PRO_v6_0.exe" -noConsole -x64

Kako da napravis installer:
1) Instaliraj Inno Setup.
2) Otvori SavkeBoosterInstaller.iss.
3) Proveri da je EXE ime isto (Savke_FPS_Booster_PRO_v6_0.exe).
4) Build u Inno Setup-u -> dobijes Installer .exe.

Auto-update:
- Hostuj fajl 'savke_fps_booster_version.txt' na svom sajtu / hostingu.
- U skripti promeni $UpdateInfoUrl da pokazuje na taj fajl.
