@echo off
echo ========================================
echo RDMA Bandwidth Performance Test
echo ========================================
echo.
echo Testing RDMA bandwidth between servers:
echo   Vlan251: ubunturdma1 - ubunturdma3
echo   Vlan250: ubunturdma4 - ubunturdma2
echo.
pause

wsl bash /mnt/c/Users/eniza/Documents/claudechats/test_rdma_bandwidth.sh

echo.
pause
