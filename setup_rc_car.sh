#!/bin/bash

# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y python3-pip python3-venv git libatlas-base-dev pigpio python3-picamera

# Start pigpio daemon
sudo systemctl enable pigpiod
sudo systemctl start pigpiod

# Create directory structure
mkdir -p ~/rc_car
cd ~/rc_car

# Clone repository
git clone https://github.com/lincreis/rc_car.git
cd rc_car

# Create virtual environments
python3 -m venv car_venv
python3 -m venv web_venv

# Activate and install dependencies for car control
source car_venv/bin/activate
pip install --upgrade pip
pip install RPi.GPIO pigpio
deactivate

# Activate and install dependencies for web server
source web_venv/bin/activate
pip install --upgrade pip
pip install picamera
deactivate

# Make scripts executable
chmod +x car_control.py web_server.py

# Create systemd services
cat << EOF | sudo tee /etc/systemd/system/rc_car_control.service
[Unit]
Description=RC Car Control Service
After=network.target

[Service]
ExecStart=/home/pi/rc_car/rc_car/car_venv/bin/python3 /home/pi/rc_car/rc_car/car_control.py
WorkingDirectory=/home/pi/rc_car/rc_car
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
EOF

cat << EOF | sudo tee /etc/systemd/system/rc_car_web.service
[Unit]
Description=RC Car Web Service
After=network.target

[Service]
ExecStart=/home/pi/rc_car/rc_car/web_venv/bin/python3 /home/pi/rc_car/rc_car/web_server.py
WorkingDirectory=/home/pi/rc_car/rc_car
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
sudo systemctl enable rc_car_control.service
sudo systemctl enable rc_car_web.service
sudo systemctl start rc_car_control.service
sudo systemctl start rc_car_web.service

echo "Setup complete! Access the web interface at http://<raspberry_pi_ip>:8000"
echo "Rebooting in 5 seconds..."
sleep 5
sudo reboot