# Climbing Wall App Server Setup Guide

This guide provides step-by-step instructions on how to install and configure an old laptop as a headless local server to run the Climbing Wall App on your home WiFi network.

## [Done] Phase 1: OS Installation 
Since this laptop will be a dedicated server, you do not need a desktop environment (GUI), which saves hundreds of megabytes of RAM.

1. Download **DietPi** for `x86_64 PC / BIOS / UEFI`.
2. Flash it to a USB drive using a tool like [BalenaEtcher](https://etcher.balena.io/) or [Rufus](https://rufus.ie/).
3. Boot your old laptop from the USB and follow the install process. Ensure the laptop is plugged into your router via Ethernet for the initial setup, or configure WiFi during install.

## [Done] Phase 2: Hostname, Passwords, and Auto-DNS (mDNS) 

To access your app nicely at `http://climb.local:5173` instead of an IP address, we will set the hostname to `climb` and use Avahi. We will also change the default DietPi passwords.

1. SSH into the laptop from your main computer (or log in directly on the laptop's keyboard). 
   To find the laptop's IP address, you can usually look at your home router's connected devices page.
   ```bash
   ssh root@<IP_ADDRESS>
   ```
   *DietPi Default Password:* `dietpi`

2. On the very first login, DietPi automatically forces you to change the global software passwords and the `root` password. Follow the prompts to create a secure password.

3. After the initial setup finishes, open the DietPi configuration menu:
   ```bash
   dietpi-config
   ```
4. Go to **Security Options** -> **Hostname**, and change the hostname to `climb`.
5. Install `avahi-daemon` to broadcast this hostname over the local network:
   ```bash
   sudo apt update && sudo apt install avahi-daemon -y
   ```
6. Reboot the laptop for changes to take effect:
   ```bash
   sudo reboot
   ```

## [Done] Phase 3: Install Docker and Docker Compose

DietPi makes this very easy:
1. SSH back into `climb.local` (or IP address).
2. Open the software menu:
   ```bash
   dietpi-software
   ```
3. Search for and select **Docker** and **Docker Compose**.
4. Proceed with the installation.

## [Done] Phase 4: Deploying the Application

Now we will get your code onto the server and spin it up.

1. Clone your GitHub repository onto the laptop:
   ```bash
   git clone https://github.com/asafked121/Climbing-wall-app.git
   cd Climbing-wall-app
   ```
2. Set up your `.env` file for the backend. The backend is configured to automatically create a Super Admin user on the very first boot based on this file.
   ```bash
   nano backend/.env
   ```
3. Paste in your environment variables. **Make sure to include these lines for the admin:**
   ```env
   # Admin Credentials
   SUPER_ADMIN_USERNAME=asaf
   SUPER_ADMIN_EMAIL=your@email.com
   SUPER_ADMIN_PASSWORD=your_secure_password
   
   # JWT Settings
   SECRET_KEY=generate_a_random_long_string_here
   ALGORITHM=HS256
   ACCESS_TOKEN_EXPIRE_MINUTES=43200
   ```
   Save and close the file (`Ctrl+O`, `Enter`, `Ctrl+X`).

4. Start the app in detached mode:
   ```bash
   docker compose up -d --build
   ```
5. You can now access your app on any device connected to the home WiFi at: `http://climb.local:5173`. You can log in using the `SUPER_ADMIN_USERNAME` and `SUPER_ADMIN_PASSWORD` you set in the `.env` file!

## [Done] Phase 5: Automatic Continuous Deployment (Polling)

To ensure the server pulls new changes from GitHub automatically, we will use a `cron` job that triggers our `update.sh` script every 5 minutes. The script will check if there are any new changes, and only rebuild the server if necessary.

1. Ensure your scripts are executable:
   ```bash
   chmod +x ~/Climbing-wall-app/scripts/update.sh
   chmod +x ~/Climbing-wall-app/scripts/nightly_restart.sh
   chmod +x ~/Climbing-wall-app/scripts/backup.sh
   ```
2. Open the cron editor:
   ```bash
   crontab -e
   ```
3. Add the following lines to the bottom of the file (replace `/root/Climbing-wall-app/` with your actual path):
   ```cron
   # Poll GitHub every 5 minutes for updates
   */5 * * * * /root/Climbing-wall-app/scripts/update.sh >> /root/Climbing-wall-app/update.log 2>&1
   
   # Restart Docker containers every night at 4:00 AM to flush RAM
   0 4 * * * /root/Climbing-wall-app/scripts/nightly_restart.sh >> /root/Climbing-wall-app/restart.log 2>&1
   
   # Backup the SQLite database and photos every Sunday at 5:00 AM
   0 5 * * 0 /root/Climbing-wall-app/scripts/backup.sh >> /root/Climbing-wall-app/backup.log 2>&1
   ```
4. Save and exit. 

## Phase 6: Hardware Resilience (BIOS)
Because this is an old laptop, you want it to automatically recover from a power outage.
1. Restart the laptop.
2. As it boots up, repeatedly press the BIOS key (usually `F2`, `F12`, `Delete`, or `Esc` depending on the laptop brand).
3. Look through the BIOS menus for a setting called **"Power Management"**, **"AC Recovery"**, or **"Restore on AC/Power Loss"**.
4. Change the setting to **Power On** or **Always On**.
5. Save changes and exit. If your house loses power, the laptop will automatically turn itself back on when power is restored, and Docker will automatically start your app!

## Phase 7: Closed-Lid Headless Mode
By default, closing a laptop lid will put it to sleep, taking your server offline. Since DietPi is a Linux system, we need to explicitly tell the OS to ignore the lid switch.

1. SSH into the laptop:
   ```bash
   ssh root@<IP_ADDRESS>
   ```
2. Open the power management configuration file:
   ```bash
   nano /etc/systemd/logind.conf
   ```
3. Look for the line that says `#HandleLidSwitch=suspend`
4. Uncomment it (remove the `#`) and change it to `ignore`:
   ```conf
   HandleLidSwitch=ignore
   ```
5. Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).
6. Apply the change by restarting the login service (this will temporarily kick you out of your SSH session):
   ```bash
   systemctl restart systemd-logind
   ```

You can now safely shut the lid of the laptop—the screen will turn off, but the server and the app will stay perfectly online!
