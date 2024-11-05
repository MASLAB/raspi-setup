#!/bin/bash

# Constants to be updated
ROS_VERSION=jazzy
STM32_DEVICE=STM32F411xE
STM32_RST_PIN=17
STM32_BT0_PIN=18
UART_OVERLAY=uart0-pi5

# Update and upgrade
sudo apt install software-properties-common
sudo add-apt-repository universe
sudo apt update && sudo apt upgrade

# Install git
sudo apt install -y git

# Install build-essential
sudo apt install -y build-essential

# Install gpiozero
sudo apt install python3-gpiozero

# Setup ROS 2 and dependencies
sudo apt install -y curl
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
sudo apt update
sudo apt install ros-$ROS_VERSION-ros-base python3-rosdep python3-colcon-common-extensions python3-pip
sudo rosdep init
rosdep update
echo "source /opt/ros/$ROS_VERSION/setup.bash" >> ~/.bashrc
echo "export PIP_BREAK_SYSTEM_PACKAGES=1" >> ~/.bashrc

# Setup networking
## Copy and apply netplan configuration
sudo cp ./files/01-netcfg.yaml /etc/netplan/
sudo netplan apply
## Setup dhcp server
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
sudo iptables -A FORWARD -i wlan0 -o eth0 -m state -—state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o wlan0 -j ACCEPT
sudo netfilter-persistent save
sudo netfilter-persistent reload

# Setup Poll Me Maybe
sudo cp ./files/pollmemaybe.sh /usr/local/bin/
crontab -l 2> /dev/null | { cat; echo "* * * * * sh /usr/local/bin/pollmemaybe.sh > /dev/null"; } | crontab -

# Setup hardware
sudo cp /boot/firmware/config.txt /boot/firmware/config.txt.bak
## Setup power option
sudo echo "usb_max_current_enable=1" >> /boot/firmware/config.txt
## Add permissions
sudo usermod -G tty,gpio,dialout ${USER}
## Enable UART
sudo dtoverlay $UART_OVERLAY
sudo echo "dtoverlay=$UART_OVERLAY" >> /boot/firmware/config.txt
## Setup GPIO pin
sudo echo "gpio=$STM32_RST_PIN=pu" >> /boot/firmware/config.txt
sudo echo "gpio=$STM32_BT0_PIN=pd" >> /boot/firmware/config.txt
echo "export STM32_RST_PIN=$STM32_RST_PIN" >> ~/.bashrc
echo "export STM32_BT0_PIN=$STM32_BT0_PIN" >> ~/.bashrc

# Setup Raven
./update-firmware.sh

# Set up Git
git config --global user.name "Team $1"
git config --global user.email maslab-$2-team-$1@mit.edu
ssh-keygen -t rsa -b 4096 -C "maslab-$2-team-$1@mit.edu"
cat ~/.ssh/id_rsa.pub
read -p "Add SSH to team repository deploy key then press any key to continue... " -n1 -s
git clone git@github.mit.edu:maslab-$2/team-$1.git ~/ros_ws
