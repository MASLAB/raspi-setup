# MASLAB Raspberry Pi Setup

This repository contains the scripts used for setting up the Raspberry Pi development environment for MASLAB.

Currently, the script handles the following:
- Updating software
- Installing `build-essential`
- Installing `gpiozero`
- Installing the base ROS Jazzy with `colcon` extensions
- Enabling `PIP_BREAK_SYSTEM_PACKAGES` to allow installation of python libraries
- Setting up network connections
    - Connect to EECS-Labs
    - DHCP server on ethernet to remote in over ethernet at fixed `192.168.1.1` IP
    - WiFi to ethernet forwarding to have internet access when connected through ethernet
- Setting up Poll Me Maybe
- Setting up Raspberry Pi hardware
    - Enable UART, SPI, I2C interfaces
    - Set up Raspberry Pi USB Power option
    - Set up GPIO pins for [Raven](https://github.com/MASLAB/raven)
- Install `adafruit-blinka`
- Load [Raven](https://github.com/MASLAB/raven) firmware
- Configurating Git + generating SSH key
- Cloning team's MASLAB repo 

## Setup Steps

Prerequisites:
- Git repo set up for each team (normally on MIT Github)
- A Raspberry Pi per team with SSD and RAM installed
- SD card set up by Raspberry Pi Imager with
    - Ubuntu 24.04 **server**
    - These customisations (change `x` to team number)  
    ![general](images/imager-general.png)  
    ![services](images/imager-services.png)  

For each Raspberry Pi:  
1. Clone and `cd` into this repo with:  
    `git clone https://github.com/MASLAB/raspi-setup ~/raspi-setup && cd ~/raspi-setup`
3. Run setup script, passing in these argument in correct order:  
    1. Team number
    2. MASLAB year  
    `./setup.sh <team-number> <maslab-year>`
4. Copy SSH public key (output of script) and add it as a deploy key to the team repo
5. Reboot
6. Go back into this repository and run  
`./update-firmware.sh`
   
And you're done! Keep this repo to update [Raven](https://github.com/MASLAB/raven) firmware:  
`git pull && ./update-firmware.sh`