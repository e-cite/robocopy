@echo off
title e-cite robocopy-tool v.1.2
echo --------------------
echo e-cite robocopy-tool
echo v.1.2
echo --------------------

setlocal
set "vernr=1.2"
set "ini_file=.\robocopy_settings.ini"


:: Variablen aus ini-Datei einlesen

for /f "eol=; tokens=2 delims==" %%a IN ('findstr /c:"nasname" "%ini_file%"') DO (SET "nasname=%%a")
for /f "eol=; tokens=2 delims==" %%a IN ('findstr /c:"path_robocopy_dir" "%ini_file%"') DO (SET "path_robocopy=%%a")
for /f "eol=; tokens=2 delims==" %%a IN ('findstr /c:"path_robocopy-log" "%ini_file%"') DO (SET "path_robocopy-log=%%a")
for /f "eol=; tokens=2 delims==;" %%a IN ('findstr /c:"robo_options" "%ini_file%"') DO (SET "robo_opt1=%%a")
for /f "eol=; tokens=3 delims==;" %%a IN ('findstr /c:"robo_options" "%ini_file%"') DO (SET "robo_opt2=%%a")
for /f "eol=; tokens=4 delims==;" %%a IN ('findstr /c:"robo_options" "%ini_file%"') DO (SET "robo_opt3=%%a")
for /f "eol=; tokens=5 delims==;" %%a IN ('findstr /c:"robo_options" "%ini_file%"') DO (SET "robo_opt4=%%a")
for /f "eol=; tokens=6 delims==;" %%a IN ('findstr /c:"robo_options" "%ini_file%"') DO (SET "robo_opt5=%%a")
for /f "eol=; tokens=2 delims==" %%a IN ('findstr /c:"nasuser" "%ini_file%"') DO (SET "nasuser=%%a")
for /f "eol=; tokens=2 delims==" %%a IN ('findstr /c:"naspasswd" "%ini_file%"') DO (SET "naspasswd=%%a")
for /f "eol=; tokens=2 delims==" %%a IN ('findstr /c:"nasshare" "%ini_file%"') DO (SET "nasshare=%%a")


:: Prüfen ob variablen ausgelesen wurden

if "%nasname%" == "" (echo Variable nasname konnte nicht aus %ini_file% ausgelesen werden & goto error)
if "%path_robocopy%" == "" (echo Variable path_robocopy konnte nicht aus %ini_file% ausgelesen werden & goto error)
if "%path_robocopy-log%" == "" (echo Variable path_log konnte nicht aus %ini_file% ausgelesen werden & goto error)



:: LOG-Datei schreiben

set "path_log=%path_robocopy-log%\robocopy.log"

echo. >%path_log%
echo --------------------- >>%path_log%
echo %date% %time% >>%path_log%
echo Versionsnummer: %vernr% >>%path_log%
echo. >>%path_log%



:: Variablen für die Pfade der robocopy-Job-Dateien festlegen, Anzahl der robocopy-Jobs definieren

set /a "n_rcj=1"
:rcjcount
if exist %path_robocopy%\robocopy_queue_%n_rcj%.rcj (
	set /a "n_rcj +=1" & goto rcjcount
	) else (
	set /a "n_rcj -=1"
	)

if "%n_rcj%" == "0" (
	echo ABBRUCH: Keine Robocopy-Jobdateien gefunden! >>%path_log% & echo ABBRUCH: Keine Robocopy-Jobdateien gefunden! & goto error
	) else (
	echo Es wurden %n_rcj% Robocopy-Jobdateien gefunden. >>%path_log%
	)



:: NAS anpingen, Ergebnisse in log-Datei schreiben

ping -n 1 %nasname% >>nul

if errorlevel 1 (
	echo. >>%path_log% & echo ABBRUCH: ping ERRORLEVEL %errorlevel% >>%path_log% & echo. & echo ABBRUCH: ping NICHT ERFOLGREICH! ERRORLEVEL %errorlevel% & goto error
	) else (
	echo. >>%path_log% & echo ERFOLG: ping ERRORLEVEL %errorlevel% >>%path_log% & echo.
	)



:: Falls in der Settings-Datei Benutzername und Passwort gesetzt wurde, wird das Laufwerk hier mit net use eingebunden.

if "%nasuser%" == "" (
	goto rcopy_start
	) else (
	echo Mounten: \\%nasname%%nasshare%, User: %nasuser%, Passwort: %naspasswd% >>%path_log%
	)

net use \\%nasname%%nasshare% %naspasswd% /USER:%nasuser% >>%path_log%

if errorlevel 1 (
	echo ABBRUCH: Mounten: ERRORLEVEL %errorlevel% >>%path_log% & echo ABBRUCH: Mounten der passwortgeschuetzten Freigabe NICHT ERFOLGREICH! ERRORLEVEL %errorlevel% & goto error
	) else (
	echo ERFOLG: Mounten: ERRORLEVEL %errorlevel% >>%path_log%
	)


:: robocopy wird für den eigentlichen Kopiervorgang gestartet, die if-Schleife legt die Häufigkeit der Ausführung abhängig von n_rcj fest

:rcopy_start
set /a "n_rcopy=1"
:rcopy
if %n_rcopy% LEQ %n_rcj% (
	set "path_rcj=%path_robocopy%\robocopy_queue_%n_rcopy%.rcj"
	) else (
	goto rcopy_end	
	)

robocopy /LOG+:%path_log% /R:3 /W:10 /FFT /JOB:%path_rcj% %robo_opt1% %robo_opt2% %robo_opt3% %robo_opt4% %robo_opt5%



:: Fehlerauswertung der Kopiervorgänge

if errorlevel 8 (
	echo. >>%path_log% & echo ABBRUCH: Robocopy: ERRORLEVEL %errorlevel% >>%path_log% & echo RCJ: %path_rcj% >>%path_log% & echo. & echo FEHLER: Robocopy: SCHWERER FEHLER, ERRORLEVEL %errorlevel%, RCJ: %path_rcj% & echo KEINE DATEIEN KOPIERT!! & set "error=1" & goto endif
	)
if errorlevel 4 (
	echo. >>%path_log% & echo ABBRUCH: Robocopy: ERRORLEVEL %errorlevel% >>%path_log% & echo RCJ: %path_rcj% >>%path_log% & echo. & echo FEHLER: Robocopy: LEICHTER FEHLER, ERRORLEVEL %errorlevel%, RCJ: %path_rcj% & echo Dateien wurden kopiert, ABER ADMINISTRATOR VERSTAENDIGEN!! & "set error=1" & goto endif
	)
if errorlevel 0 (
	echo. >>%path_log% & echo ERFOLG: Robocopy: ERRORLEVEL %errorlevel% >>%path_log% & echo RCJ: %path_rcj% >>%path_log% & echo. & echo ERFOLG: Robocopy: Kein Fehler, Status: %errorlevel%, RCJ: %path_rcj% & echo ERFOLG: Alle Dateien von Job %n_rcopy% wurden erfolgreich kopiert! & goto endif
	)

:endif
set /a "n_rcopy +=1"
goto rcopy



:: net use Freigabe unmounten

:rcopy_end
if not "%nasuser%" == "" (
	echo Mounten: Lösche Freigabe... >>%path_log% & net use \\%nasname%%nasshare% /DELETE >>%path_log%
	)

:: Fehlerauswertung

if "%error%" == "1" (
	goto error
	) else (
	echo ERFOLG: Beende robocopy! >>%path_log% & echo ERFOLG: Es wurden alle Kopiervorgaenge erfolgreich ausgefuehrt. & goto end
	)



:ERROR
echo FEHLERABBRUCH um %date% %time% >>%path_log%
echo.
echo ABBRUCH!
echo Dateien nicht vollstaendig kopiert! Bitte Administrator verstaendigen!
echo.

set "logtag=%date:~6,4%-%date:~3,2%-%date:~0,2%_%time:~0,2%-%time:~3,2%-%time:~6,2%_%computername%"
rename %path_log% robocopy_ERRORLOG_%logtag%.log >nul
copy %path_robocopy-log%\robocopy_ERRORLOG_%logtag%.log \\%nasname%\log-files\robocopy >nul

pause
exit


:END
echo Programm erfolgreich beendet um %date% %time% >>%path_log%
echo.
pause
exit