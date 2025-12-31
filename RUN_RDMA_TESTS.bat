@echo off
echo ========================================
echo RDMA Cluster Full Test Suite
echo ========================================
echo.
echo Running comprehensive RDMA tests...
echo This will test all 8 servers for:
echo   - Network interfaces
echo   - RDMA hardware
echo   - Network connectivity
echo   - RDMA performance
echo.
echo Results will be saved to a timestamped file.
echo.
pause

wsl bash /mnt/c/Users/eniza/Documents/claudechats/rdma_full_test.sh

echo.
echo ========================================
echo Tests Complete!
echo ========================================
echo.
echo Check the claudechats folder for the results file:
echo rdma_test_results_YYYYMMDD_HHMMSS.txt
echo.
pause
