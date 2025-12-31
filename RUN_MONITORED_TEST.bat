@echo off
echo ========================================
echo RDMA Test with Switch Monitoring
echo ========================================
echo.
echo This will:
echo   1. Run RDMA bandwidth tests on servers
echo   2. Monitor switch ports in real-time
echo   3. Collect PFC, ECN, queue statistics
echo.
set /p duration="Enter test duration in seconds (default 60): "
if "%duration%"=="" set duration=60

echo.
echo Starting monitored test for %duration% seconds...
echo.
pause

wsl bash /mnt/c/Users/eniza/Documents/claudechats/monitored_rdma_test.sh %duration%

echo.
echo Test complete! Check the results files.
echo.
pause
