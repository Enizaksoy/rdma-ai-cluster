@echo off
echo ========================================
echo RDMA Hardware Verification - All Servers
echo ========================================
echo.

echo === ubunturdma1 (192.168.11.152) ===
ssh versa@192.168.11.152 "hostname && echo 'RDMA Modules:' && lsmod | grep -iE 'rdma|ib_|mlx' && echo 'IB Devices:' && ls /sys/class/infiniband/ 2>&1 && echo 'RDMA Tools:' && which ibstat ibv_devices rdma 2>&1 && echo 'RoCE NICs:' && ibv_devices 2>&1"
echo.

echo === ubunturdma2 (192.168.11.153) ===
ssh versa@192.168.11.153 "hostname && echo 'RDMA Modules:' && lsmod | grep -iE 'rdma|ib_|mlx' && echo 'IB Devices:' && ls /sys/class/infiniband/ 2>&1 && echo 'RDMA Tools:' && which ibstat ibv_devices rdma 2>&1 && echo 'RoCE NICs:' && ibv_devices 2>&1"
echo.

echo === ubunturdma3 (192.168.11.154) ===
ssh versa@192.168.11.154 "hostname && echo 'RDMA Modules:' && lsmod | grep -iE 'rdma|ib_|mlx' && echo 'IB Devices:' && ls /sys/class/infiniband/ 2>&1 && echo 'RDMA Tools:' && which ibstat ibv_devices rdma 2>&1 && echo 'RoCE NICs:' && ibv_devices 2>&1"
echo.

echo === ubunturdma4 (192.168.11.155) ===
ssh versa@192.168.11.155 "hostname && echo 'RDMA Modules:' && lsmod | grep -iE 'rdma|ib_|mlx' && echo 'IB Devices:' && ls /sys/class/infiniband/ 2>&1 && echo 'RDMA Tools:' && which ibstat ibv_devices rdma 2>&1 && echo 'RoCE NICs:' && ibv_devices 2>&1"
echo.

echo === ubunturdma5 (192.168.11.107) ===
ssh versa@192.168.11.107 "hostname && echo 'RDMA Modules:' && lsmod | grep -iE 'rdma|ib_|mlx' && echo 'IB Devices:' && ls /sys/class/infiniband/ 2>&1 && echo 'RDMA Tools:' && which ibstat ibv_devices rdma 2>&1 && echo 'RoCE NICs:' && ibv_devices 2>&1"
echo.

echo === ubunturdma6 (192.168.12.51) ===
ssh versa@192.168.12.51 "hostname && echo 'RDMA Modules:' && lsmod | grep -iE 'rdma|ib_|mlx' && echo 'IB Devices:' && ls /sys/class/infiniband/ 2>&1 && echo 'RDMA Tools:' && which ibstat ibv_devices rdma 2>&1 && echo 'RoCE NICs:' && ibv_devices 2>&1"
echo.

echo === ubunturdma7 (192.168.20.150) ===
ssh versa@192.168.20.150 "hostname && echo 'RDMA Modules:' && lsmod | grep -iE 'rdma|ib_|mlx' && echo 'IB Devices:' && ls /sys/class/infiniband/ 2>&1 && echo 'RDMA Tools:' && which ibstat ibv_devices rdma 2>&1 && echo 'RoCE NICs:' && ibv_devices 2>&1"
echo.

echo === ubunturdma8 (192.168.30.94) ===
ssh versa@192.168.30.94 "hostname && echo 'RDMA Modules:' && lsmod | grep -iE 'rdma|ib_|mlx' && echo 'IB Devices:' && ls /sys/class/infiniband/ 2>&1 && echo 'RDMA Tools:' && which ibstat ibv_devices rdma 2>&1 && echo 'RoCE NICs:' && ibv_devices 2>&1"
echo.

echo ========================================
echo RDMA Hardware Check Complete
echo ========================================
pause
