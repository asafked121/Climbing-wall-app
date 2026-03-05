@echo off
:: Switch to the repository root directory
cd /d "%~dp0..\.."

echo =========================================================
echo Starting nightly update for Climbing Wall App
echo Time: %date% %time%
echo =========================================================

:: Ensure we are on the main branch
echo Checking out main branch...
git checkout main

:: Pull the latest changes from the origin
echo Pulling latest changes from origin/main...
git pull origin main

:: Rebuild the docker containers
echo Rebuilding docker containers...
docker-compose build

:: Restart the docker containers in detached (background) mode
echo Restarting docker containers...
docker-compose up -d

echo =========================================================
echo Nightly update complete!
echo Time: %date% %time%
echo =========================================================
