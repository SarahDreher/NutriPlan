@echo off
echo.
echo  NutriPlan wird gestartet...
echo.

REM Bibliotheken installieren falls noetig
python -c "import requests" 2>nul || (
    echo  Installiere requests...
    pip install requests --quiet
)
python -c "import dns.resolver" 2>nul || (
    echo  Installiere dnspython...
    pip install dnspython --quiet
)

echo  Wichtig: Dieses Fenster muss offen bleiben!
echo  Browser-Link: http://127.0.0.1:8080
echo  iPhone-Link: Wird beim Start angezeigt (selbes WLAN noetig)
echo.
python "%~dp0server.py"
pause
