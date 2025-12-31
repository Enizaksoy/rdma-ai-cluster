@echo off
echo ========================================
echo Network Stress Test
echo ========================================
echo.
echo This will:
echo   1. Install AI/ML stack (if needed)
echo   2. Run intensive 8-node training
echo   3. Monitor RDMA/PFC/ECN statistics
echo.
echo Default duration: 5 minutes
echo.
set /p duration="Enter duration in seconds (default 300): "
if "%duration%"=="" set duration=300

echo.
echo Duration set to: %duration% seconds
echo.
pause

wsl bash /mnt/c/Users/eniza/Documents/claudechats/run_stress_test.sh %duration%

echo.
pause
