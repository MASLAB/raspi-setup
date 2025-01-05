#!/bin/bash
cd ~/raspi-setup
git pull
python3 stm32prog.py -d $STM32_DEVICE -b ./files/firmware.bin -rst $STM32_RST_PIN -bt0 $STM32_BT0_PIN -sbd 460800

pip install --upgrade git+https://github.com/MASLAB/maslab-lib.git