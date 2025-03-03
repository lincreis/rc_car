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
sudo apt install -y python3-pip python3-dev python3-spidev git

# Install the NRF24 library for Python
echo "Installing NRF24 Python library..."
pip3 install git+https://github.com/BLavery/lib_nrf24.git

# Create a directory for the test files
echo "Creating test directory..."
mkdir -p ~/nrf24_test
cd ~/nrf24_test

# Create a Python transmitter script with custom CE and CSN pins
echo "Creating transmitter test script..."
cat << EOF > nrf24_transmitter.py
import spidev
import time
from lib_nrf24 import NRF24
import RPi.GPIO as GPIO

GPIO.setmode(GPIO.BCM)
pipes = [[0xe7, 0xe7, 0xe7, 0xe7, 0xe7], [0xc2, 0xc2, 0xc2, 0xc2, 0xc2]]

radio = NRF24(GPIO, spidev.SpiDev())
radio.begin(1, 8)  # CSN on GPIO 7 (SPI CE1), CE on GPIO 8
radio.setPayloadSize(32)
radio.setChannel(0x60)
radio.setDataRate(NRF24.BR_1MBPS)
radio.setPALevel(NRF24.PA_MAX)
radio.setAutoAck(True)
radio.enableDynamicPayloads()
radio.enableAckPayload()
radio.openWritingPipe(pipes[0])
radio.openReadingPipe(1, pipes[1])
radio.printDetails()

print("Starting transmission test...")
while True:
    message = list("Hello NRF24L01")
    radio.write(message)
    print("Sent: {}".format("".join(map(chr, message))))
    time.sleep(1)
EOF

# Create a Python receiver script with custom CE and CSN pins (optional)
echo "Creating receiver test script (optional)..."
cat << EOF > nrf24_receiver.py
import spidev
import time
from lib_nrf24 import NRF24
import RPi.GPIO as GPIO

GPIO.setmode(GPIO.BCM)
pipes = [[0xe7, 0xe7, 0xe7, 0xe7, 0xe7], [0xc2, 0xc2, 0xc2, 0xc2, 0xc2]]

radio = NRF24(GPIO, spidev.SpiDev())
radio.begin(1, 8)  # CSN on GPIO 7 (SPI CE1), CE on GPIO 8
radio.setPayloadSize(32)
radio.setChannel(0x60)
radio.setDataRate(NRF24.BR_1MBPS)
radio.setPALevel(NRF24.PA_MAX)
radio.setAutoAck(True)
radio.enableDynamicPayloads()
radio.enableAckPayload()
radio.openWritingPipe(pipes[1])
radio.openReadingPipe(1, pipes[0])
radio.printDetails()

print("Starting receiver test...")
radio.startListening()

while True:
    if radio.available():
        received_message = []
        radio.read(received_message, radio.getDynamicPayloadSize())
        print("Received: {}".format("".join(map(chr, received_message))))
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

# Test the transmitter
echo "Running transmitter test (Ctrl+C to stop)..."
echo "If you have a second NRF24L01 device, run nrf24_receiver.py on it to see the messages."
python3 nrf24_transmitter.py &

# Keep the script running to allow observation
echo "Transmitter is running in the background. Check output above."
echo "To stop, use 'pkill -f nrf24_transmitter.py' or reboot."
echo "If SPI was just enabled, please reboot and rerun this script with './nrf24_test.sh'."
wait