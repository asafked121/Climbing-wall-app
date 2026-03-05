@echo off
echo =========================================================
echo Setting up Nightly CI/CD Update Task for Climbing Wall App
echo =========================================================

:: Check if the script is run with Administrator privileges
net session >nul 2>&1
if NOT %errorLevel% == 0 (
    echo [ERROR] Administrative privileges are required.
    echo Please right-click this script and select "Run as administrator".
    pause
    exit /b 1
)

:: Define task properties
set TASK_NAME=ClimbingWall.NightlyUpdate
:: The absolute path to update_nightly.bat
set SCRIPT_PATH="%~dp0update_nightly.bat"
:: Set time for nightly build (e.g., 3:00 AM)
set TIME=03:00

echo Creating scheduled task: %TASK_NAME%
echo Script to run: %SCRIPT_PATH%
echo Schedule: Daily at %TIME%
echo Run as: SYSTEM (Background mode without UI)

:: /ru SYSTEM makes it run in the background regardless of user login state
schtasks /create /tn "%TASK_NAME%" /tr %SCRIPT_PATH% /sc daily /st %TIME% /ru SYSTEM /rl HIGHEST /f

if %errorLevel% == 0 (
    echo.
    echo [SUCCESS] Scheduled task created successfully!
    echo The update script will now run automatically every night at %TIME%.
) else (
    echo.
    echo [ERROR] Failed to create the scheduled task. Check the error message above.
)
pause
