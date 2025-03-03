#!/bin/bash

# Script to set up and test NRF24L01+PA+LNA on Raspberry Pi Zero
# Custom pinout: CE on GPIO 8, CSN on GPIO 7
# Date: March 03, 2025

echo "Starting NRF24L01+PA+LNA setup and test on Raspberry Pi Zero..."

# Update the system
echo "Updating package lists..."
sudo apt update -y
sudo apt upgrade -y

# Enable SPI interface
echo "Enabling SPI interface..."
if ! grep -q "dtparam=spi=on" /boot/config.txt; then
    echo "dtparam=spi=on" | sudo tee -a /boot/config.txt
    echo "SPI enabled in /boot/config.txt. Reboot may be required after script."
else
    echo "SPI is already enabled."
fi

# Install required packages
echo "Installing necessary dependencies..."
sudo apt install -y python3-pip python3-dev python3-spidev python3-venv git

# Create a directory for the test files
echo "Creating test directory..."
mkdir -p ~/nrf24_test
cd ~/nrf24_test

# Create and activate a Python virtual environment
echo "Creating and activating Python virtual environment..."
python3 -m venv nrf24_venv
source nrf24_venv/bin/activate

# Install required Python libraries in the virtual environment
echo "Installing NRF24 and spidev Python libraries in virtual environment..."
pip3 install circuitpython-nrf24l01 spidev

# Create a Python transmitter script with custom CE and CSN pins
echo "Creating transmitter test script..."
cat << EOF > nrf24_transmitter.py
import time
import board
import busio
import digitalio
from circuitpython_nrf24l01 import RF24

# SPI setup with custom pins
spi = busio.SPI(board.SCK, MOSI=board.MOSI, MISO=board.MISO)
ce = digitalio.DigitalInOut(board.D8)  # CE on GPIO 8
csn = digitalio.DigitalInOut(board.D7)  # CSN on GPIO 7

# Initialize NRF24L01
radio = RF24(spi, csn, ce)
radio.set_pa_level(0)  # 0 = max power (PA_MAX), adjust if needed
radio.channel = 0x60  # Set channel (hex)
radio.data_rate = 1000  # 1 Mbps
radio.open_tx_pipe(b"\xe7\xe7\xe7\xe7\xe7")  # Writing pipe
radio.open_rx_pipe(1, b"\xc2\xc2\xc2\xc2\xc2")  # Reading pipe

print("NRF24L01 configuration:")
radio.print_details()

print("Starting transmission test...")
while True:
    message = "Hello NRF24L01"
    radio.send(message.encode('utf-8'))
    print(f"Sent: {message}")
    time.sleep(1)
EOF

# Create a Python receiver script with custom CE and CSN pins (optional)
echo "Creating receiver test script (optional)..."
cat << EOF > nrf24_receiver.py
import time
import board
import busio
import digitalio
from circuitpython_nrf24l01 import RF24

# SPI setup with custom pins
spi = busio.SPI(board.SCK, MOSI=board.MOSI, MISO=board.MISO)
ce = digitalio.DigitalInOut(board.D8)  # CE on GPIO 8
csn = digitalio.DigitalInOut(board.D7)  # CSN on GPIO 7

# Initialize NRF24L01
radio = RF24(spi, csn, ce)
radio.set_pa_level(0)  # 0 = max power (PA_MAX), adjust if needed
radio.channel = 0x60  # Set channel (hex)
radio.data_rate = 1000  # 1 Mbps
radio.open_tx_pipe(b"\xc2\xc2\xc2\xc2\xc2")  # Writing pipe
radio.open_rx_pipe(1, b"\xe7\xe7\xe7\xe7\xe7")  # Reading pipe

print("NRF24L01 configuration:")
radio.print_details()

print("Starting receiver test...")
radio.listen = True

while True:
    if radio.available():
        data = radio.recv()
        print(f"Received: {data.decode('utf-8')}")
    time.sleep(0.1)
EOF

# Set permissions
chmod +x nrf24_transmitter.py nrf24_receiver.py

# Check if SPI is loaded
echo "Checking SPI module..."
if lsmod | grep -q spi; then
    echo "SPI module is loaded."
else
    echo "Loading SPI module..."
    sudo modprobe spi-bcm2835
fi

# Test the transmitter using the virtual environment
echo "Running transmitter test (Ctrl+C to stop)..."
echo "If you have a second NRF24L01 device, run nrf24_receiver.py on it to see the messages."
~/nrf24_test/nrf24_venv/bin/python3 nrf24_transmitter.py &

# Keep the script running to allow observation
echo "Transmitter is running in the background. Check output above."
echo "To stop, use 'pkill -f nrf24_transmitter.py' or reboot."
echo "If SPI was just enabled, please reboot and rerun this script with './nrf24_test.sh'."
wait

# Deactivate the virtual environment
deactivate