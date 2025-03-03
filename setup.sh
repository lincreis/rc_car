#!/bin/bash

# Exit on any error
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)"
    exit 1
fi

# Update system
apt update && apt upgrade -y

# Install required packages including build dependencies for RF24 and FFmpeg
apt install -y python3-pip python3-venv git libatlas-base-dev libopenjp2-7 \
    raspberrypi-kernel-headers libjpeg-dev libpng-dev libcamera-apps-lite \
    python3-pyqt5 python3-prctl libcap-dev build-essential python3-dev \
    libraspberrypi-dev libavcodec-dev libavformat-dev libswscale-dev libavutil-dev

# Enable SPI and Camera interfaces
echo "Enabling SPI and Camera interfaces..."
raspi-config nonint do_spi 0    # 0 enables SPI
raspi-config nonint do_camera 0 # 0 enables camera

# Set up project directory by cloning from GitHub
echo "Setting up project directory..."
cd /home/pi
git clone https://github.com/lincreis/rc_car.git
cd rc_car
chmod +x joystick_pi.py robot_pi.py web_server.py

# Create virtual environment and install Python packages
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
# Install packages with pre-built wheels where possible
pip install flask RPi.GPIO spidev numpy
# Install picamera2 with minimal dependencies (no av if possible)
pip install "picamera2[min]"
# Force reinstall spidev to ensure it’s there
pip install spidev --no-cache-dir --force-reinstall

# Install RF24 from source
echo "Installing RF24 from source..."
git clone https://github.com/nRF24/RF24.git
cd RF24
./configure --driver=SPIDEV
make
make install
cd pyRF24
python3 setup.py install
cd ../..
rm -rf RF24

# Verify installations
echo "Verifying Python package installations..."
python3 -c "import spidev; print('spidev installed:', spidev.__version__)"
python3 -c "import RF24; print('RF24 installed:', RF24.__version__)"
python3 -c "import picamera2; print('picamera2 installed:', picamera2.__version__)"

# Create systemd services for Robot Pi
cat > /etc/systemd/system/robot_web.service << 'EOF'
[Unit]
Description=Robot Web Interface Service
After=network.target

[Service]
ExecStart=/home/pi/rc_car/venv/bin/python3 /home/pi/rc_car/web_server.py
WorkingDirectory=/home/pi/rc_car
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/robot_rf24.service << 'EOF'
[Unit]
Description=Robot RF24 Receiver Service
After=network.target

[Service]
ExecStart=/home/pi/rc_car/venv/bin/python3 /home/pi/rc_car/robot_pi.py
WorkingDirectory=/home/pi/rc_car
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for Joystick Pi
cat > /etc/systemd/system/joystick.service << 'EOF'
[Unit]
Description=Joystick Transmitter Service
After=network.target

[Service]
ExecStart=/home/pi/rc_car/venv/bin/python3 /home/pi/rc_car/joystick_pi.py
WorkingDirectory=/home/pi/rc_car
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
EOF

# Set proper permissions
chown -R pi:pi /home/pi/rc_car
chmod 644 /etc/systemd/system/robot_web.service
chmod 644 /etc/systemd/system/robot_rf24.service
chmod 644 /etc/systemd/system/joystick.service

# Reload systemd
systemctl daemon-reload

# Instructions for user
echo "Setup complete!"
echo "For Robot Pi:"
echo "  systemctl enable robot_web.service"
echo "  systemctl enable robot_rf24.service"
echo "  systemctl start robot_web.service"
echo "  systemctl start robot_rf24.service"
echo ""
echo "For Joystick Pi:"
echo "  systemctl enable joystick.service"
echo "  systemctl start joystick.service"
echo ""
echo "Web interface will be available at http://<robot_pi_ip>:5000"
echo "Reboot recommended to ensure all hardware interfaces are active"