@echo off
echo ========================================
echo  NEXUS NETWORK MONITOR
echo ========================================
echo.
echo Starting dashboard...
echo.
echo Open your browser and go to:
echo.
echo     http://localhost:5000
echo.
echo Press Ctrl+C to stop
echo.
echo ========================================
echo.

cd /d "%~dp0"

python simple_nexus_monitor.py

pause
