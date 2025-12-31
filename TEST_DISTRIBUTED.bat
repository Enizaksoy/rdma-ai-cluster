@echo off
echo ========================================
echo 8-Node Distributed Training Test
echo ========================================
echo.
echo Testing PyTorch distributed training
echo across ALL 8 cluster servers
echo.
echo Configuration:
echo   Master: ubunturdma1 (Vlan251)
echo   Workers: ubunturdma2-8 (Vlan251 + Vlan250)
echo   World Size: 8 nodes
echo   Backend: Gloo (CPU)
echo.
pause

wsl bash /mnt/c/Users/eniza/Documents/claudechats/test_distributed_training.sh

echo.
pause
