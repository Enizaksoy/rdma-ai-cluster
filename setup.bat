@echo off
REM Setup script - Gerekli kutuphaneleri yukler

echo ====================================
echo Nexus Monitor Setup
echo ====================================
echo.
echo Python kutuphaneleri yukleniyor...
echo.

python -m pip install --upgrade pip
python -m pip install requests

echo.
echo ====================================
echo Setup tamamlandi!
echo ====================================
echo.
echo Simdi run_nexus_monitor.bat dosyasini calistirabilirsiniz.
echo.
pause
