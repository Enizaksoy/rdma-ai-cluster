@echo off
REM Nexus Interface Monitor - Windows Batch File
REM Cift tiklayin veya command prompt'tan calistirin

echo ====================================
echo Nexus Interface Monitor
echo ====================================
echo.
echo Switch: 192.168.50.229
echo Interfaces: Ethernet1/1/1-4, Ethernet1/2/1-4
echo.
echo Durdurmak icin Ctrl+C basin
echo.

cd /d "%~dp0"

python nexus_monitor.py --host 192.168.50.229 --user admin --password "Versa@123!!" --interfaces Ethernet1/1/1-4 Ethernet1/2/1-4 --interval 1

pause
