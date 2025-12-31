@echo off
echo ========================================
echo  NEXUS MONITOR - DYNAMIC INTERFACE SELECTION
echo ========================================
echo.
echo Starting dashboard with interface selector...
echo.
echo Open browser: http://localhost:5000
echo.
echo Press Ctrl+C to stop
echo.
echo ========================================
echo.

cd /d "%~dp0"

python nexus_dashboard_dynamic.py

pause
