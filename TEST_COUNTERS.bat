@echo off
echo ========================================
echo  TEST INTERFACE COUNTERS
echo ========================================
echo.
echo This will check if interface byte counters are incrementing
echo.

cd /d "%~dp0"

python test_interface_counters.py

pause
