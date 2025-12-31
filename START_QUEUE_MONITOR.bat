@echo off
echo ========================================
echo  NEXUS MONITOR - BANDWIDTH + QUEUES
echo ========================================
echo.
echo Starting dashboard with QoS queue stats...
echo.
echo Open browser: http://localhost:5000
echo.
echo Press Ctrl+C to stop
echo.
echo ========================================
echo.

cd /d "%~dp0"

python nexus_monitor_with_queues.py

pause
