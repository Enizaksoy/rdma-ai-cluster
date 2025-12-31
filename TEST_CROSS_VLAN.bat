@echo off
echo ========================================
echo Cross-VLAN RDMA Traffic Test
echo ========================================
echo.
echo This will generate traffic BETWEEN VLANs:
echo   Test 1: Vlan251 -^> Vlan250
echo   Test 2: Vlan250 -^> Vlan251
echo   Test 3: 4 simultaneous cross-VLAN flows
echo.
echo You will see this traffic on your switch!
echo.
pause

wsl bash /mnt/c/Users/eniza/Documents/claudechats/test_rdma_cross_vlan.sh

echo.
pause
