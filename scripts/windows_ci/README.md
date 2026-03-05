# Windows CI/CD Setup

This directory contains utility scripts to set up a nightly Continuous Integration and Continuous Deployment (CI/CD) workflow on a Windows machine. 

## Git Workflow Strategy
- **`main` branch:** This is the *production* branch. The nightly script strictly pulls and deploys from this branch.
- **`development` branch:** All active work, testing, and new features should occur on this branch. Once a feature or fix is verified, a Pull Request (PR) or a direct merge should be made from `development` into `main`.

## Scripts Included

### 1. `update_nightly.bat`
This script executes the update sequence for the Climbing Wall App:
1. Switches to the root directory of the repository.
2. Checks out the `main` branch.
3. Pulls the latest changes from the origin.
4. Rebuilds the Docker containers (`docker-compose build`).
5. Restarts the containers in detached output mode (`docker-compose up -d`).

*Note: You can run this script manually anytime you want to force an update to the latest `main`.*

### 2. `setup_scheduled_task.bat`
This script configures Windows Task Scheduler to run `update_nightly.bat` automatically every night at 3:00 AM. 

- It runs the task under the `SYSTEM` account. This means **it will run in the background completely hidden** without needing any user to be currently logged in to the desktop.
- **Requirements:** You MUST right-click this script and select **"Run as administrator"** for it to successfully create the scheduled task.

## How to Set It Up

1. Open your File Explorer and navigate to your project directory.
2. Go to the `scripts/windows_ci/` directory.
3. Right-click on `setup_scheduled_task.bat` and select **"Run as administrator"**.
4. A Command Prompt window will open, configure the task, and confirm it was successful. That's it! The system will now pull down your changes from `main` and deploy them every night explicitly at 3:00 AM.
