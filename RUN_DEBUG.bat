@echo off
echo ========================================
echo  QUEUE DEBUG TEST
echo ========================================
echo.
echo Testing queue statistics output...
echo.

cd /d "%~dp0"

python test_queue_debug.py

echo.
echo Check the files created:
echo   - queue_output_text.txt
echo   - queue_output_json.txt
echo.
pause
