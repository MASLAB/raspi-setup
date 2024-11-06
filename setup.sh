#!/bin/bash

# Set to exit on error
set -e

# Constants to be updated
ROS_VERSION=jazzy
STM32_DEVICE=STM32F411xE
STM32_RST_PIN=17
STM32_BT0_PIN=18
UART=uart0

# Update and upgrade
sudo apt install -y software-properties-common
sudo add-apt-repository universe -y
sudo apt update && sudo apt upgrade -y

# Install build-essential
sudo apt install -y build-essential

# Install gpiozero
sudo apt install -y python3-gpiozero

# Setup ROS 2 and dependencies
sudo apt install -y curl
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
sudo apt update
sudo apt install -y ros-$ROS_VERSION-ros-base python3-rosdep python3-colcon-common-extensions python3-pip
sudo rosdep init
rosdep update
echo "source /opt/ros/$ROS_VERSION/setup.bash" >> ~/.bashrc
echo "export PIP_BREAK_SYSTEM_PACKAGES=1" >> ~/.bashrc
source ~/.bashrc

# Setup networking
## Copy and apply netplan configuration
sudo cp ./files/01-netcfg.yaml /etc/netplan/
sudo netplan apply
## Setup dhcp server
sudo apt install -y isc-dhcp-server
sudo cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak
sudo cp ./files/dhcpd.conf /etc/dhcp/
sudo cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.bak
sudo cp ./files/isc-dhcp-server /etc/default/
sudo systemctl restart isc-dhcp-server.service
## Setup wifi bridging
sudo cp /etc/sysctl.conf /etc/sysctl.conf.bak
sudo cp ./files/sysctl.conf /etc/sysctl.conf
sudo apt install -y iptables-persistent
sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
sudo iptables -A FORWARD -i wlan0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o wlan0 -j ACCEPT
sudo netfilter-persistent save
sudo netfilter-persistent reload
## Skip waiting for eth0 to load
sudo mkdir -p /etc/systemd/system/systemd-networkd-wait-online.service.d
sudo cp ./files/wait-online-override.conf /etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf
sudo systemctl daemon-reload

# Setup Poll Me Maybe
sudo cp ./files/pollmemaybe.sh /usr/local/bin/
crontab -l 2> /dev/null | { cat; echo "* * * * * sh /usr/local/bin/pollmemaybe.sh > /dev/null"; } | crontab -

# Setup hardware
sudo apt install -y raspi-config
## Enable interfaces
sudo raspi-config nonint do_i2c 0
sudo raspi-config nonint do_spi 0
sudo raspi-config nonint do_serial 0
sudo raspi-config nonint disable_raspi_config_at_boot 0
sudo cp /boot/firmware/config.txt /boot/firmware/config.txt.bak
## Setup power option
sudo sh -c "echo "usb_max_current_enable=1" >> /boot/firmware/config.txt"
## Add UART param
sudo sh -c "echo "dtparam=$UART" >> /boot/firmware/config.txt"
## Setup GPIO pins
sudo sh -c "echo "gpio=$STM32_RST_PIN=pu" >> /boot/firmware/config.txt"
sudo sh -c "echo "gpio=$STM32_BT0_PIN=pd" >> /boot/firmware/config.txt"

# Install adafruit-blinka
sudo apt install -y i2c-tools libgpiod-dev python3-libgpiod
pip3 install --upgrade RPi.GPIO
pip3 install --upgrade adafruit-blinka

# Setup Raven
sudo apt install python3-numpy
echo "export STM32_DEVICE=$STM32_DEVICE" >> ~/.bashrc
echo "export STM32_RST_PIN=$STM32_RST_PIN" >> ~/.bashrc
echo "export STM32_BT0_PIN=$STM32_BT0_PIN" >> ~/.bashrc

# Set up Git
git config --global user.name "Team $1"
git config --global user.email maslab-$2-team-$1@mit.edu
ssh-keygen -t rsa -b 4096 -C "maslab-$2-team-$1@mit.edu"
cat ~/.ssh/id_rsa.pub
read -p "Add SSH to team repository deploy key then press any key to continue... " -n1 -s
git clone git@github.mit.edu:maslab-$2/team-$1.git ~/ros_ws
