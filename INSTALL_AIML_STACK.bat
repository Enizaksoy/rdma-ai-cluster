@echo off
echo ========================================
echo AI/ML Stack Installation
echo ========================================
echo.
echo This will install on all 8 servers:
echo   - Python 3 and pip
echo   - PyTorch (CPU version)
echo   - MPI4py for distributed computing
echo   - NumPy, Pandas, Scikit-learn
echo   - Matplotlib, Jupyter, TensorBoard
echo.
echo Installation time: 10-15 minutes
echo.
pause

wsl bash /mnt/c/Users/eniza/Documents/claudechats/install_aiml_stack.sh

echo.
echo ========================================
echo Installation Complete!
echo ========================================
echo.
echo Check the log file for details.
echo.
pause
