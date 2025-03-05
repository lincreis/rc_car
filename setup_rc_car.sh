#!/bin/bash

set -e  # Exit on any error

# Update system
sudo apt update
sudo apt upgrade -y

# Install required system packages
sudo apt install -y \
    python3-dev \
    python3-pip \
    git \
    libopenjp2-7 \
    libatlas-base-dev \
    pigpio \
    libcamera0.4 \
    python3-libcamera \
    libopenblas-dev \
    python3-numpy \
    python3-picamera2 \
    python3-flask \
    python3-werkzeug \
    python3-jinja2 \
    python3-markupsafe \
    python3-evdev

# Install pyrf24 via pip
sudo pip3 install pyrf24

# Clone repository
git clone https://github.com/lincreis/rc_car.git
cd rc_car

# Enable camera and SPI
sudo raspi-config nonint do_camera 0
sudo raspi-config nonint do_spi 0

# Add pi user to spi and gpio groups
sudo usermod -a -G spi,gpio pi

# Create systemd services
sudo bash -c 'cat > /etc/systemd/system/rc_car_joystick.service << EOL
[Unit]
Description=RC Car Joystick Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /home/pi/rc_car/joystick.py
WorkingDirectory=/home/pi/rc_car
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
EOL'

sudo bash -c 'cat > /etc/systemd/system/rc_car_wheels.service << EOL
[Unit]
Description=RC Car Wheels Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /home/pi/rc_car/robot_wheels.py
WorkingDirectory=/home/pi/rc_car
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
EOL'

sudo bash -c 'cat > /etc/systemd/system/rc_car_web.service << EOL
[Unit]
Description=RC Car Web Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /home/pi/rc_car/webserver.py
WorkingDirectory=/home/pi/rc_car
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
EOL'

# Enable and start services
sudo systemctl daemon-reload
sudo systemctl enable rc_car_joystick.service rc_car_wheels.service rc_car_web.service
sudo systemctl start rc_car_joystick.service rc_car_wheels.service rc_car_web.service

# Start pigpiod
sudo systemctl enable pigpiod
sudo systemctl start pigpiod

echo "Setup complete! Rebooting in 5 seconds..."
sleep 5
sudo reboot