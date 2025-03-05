#!/bin/bash

# Script to automate NRF24L01 setup on Raspberry Pi Zero with pyRF24
# Date: March 04, 2025
# Assumptions: Python 3.11 is installed, NRF24L01 wired (CE on GPIO25, CSN on SPI0 CS0)

# Exit on any error
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting NRF24L01 setup...${NC}"

# Step 1: Update system and install prerequisites
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3-venv python3-dev libboost-python-dev

# Step 2: Enable SPI
echo "Enabling SPI interface..."
if ! grep -q "dtparam=spi=on" /boot/config.txt; then
    echo "dtparam=spi=on" | sudo tee -a /boot/config.txt
    echo "SPI enabled in /boot/config.txt. Reboot required later."
else
    echo "SPI already enabled."
fi

# Step 3: Create and activate virtual environment
VENV_DIR="$HOME/nrf24_env"
echo "Setting up virtual environment in $VENV_DIR..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
echo "Virtual environment activated: $(python --version)"

# Step 4: Upgrade pip and install pyRF24 and spidev
echo "Installing Python dependencies..."
pip install --upgrade pip
pip install pyrf24 spidev

# Step 5: Create test script
TEST_SCRIPT="$HOME/nrf24_test.py"
echo "Creating test script at $TEST_SCRIPT..."
cat << 'EOF' > "$TEST_SCRIPT"
from pyrf24 import RF24, RF24_PA_MAX, RF24_1MBPS
import time

radio = RF24(25, 0)  # CE on GPIO25, CSN on SPI0 CS0 (GPIO8)
pipe = b"1Node"

def test_transmitter():
    if not radio.begin():
        print("Radio hardware is not responding!")
        return

    radio.setPALevel(RF24_PA_MAX)
    radio.setDataRate(RF24_1MBPS)
    radio.setChannel(100)
    radio.openWritingPipe(pipe)

    print("NRF24L01 Transmitter Test")
    radio.printDetails()

    print("\nEntering transmit mode...")
    radio.stopListening()

    message = "Test Message"
    print(f"Attempting to send: '{message}'")
    for _ in range(5):
        if radio.write(message.encode('utf-8')):
            print("Unexpected success (receiver detected?)")
            break
        else:
            print("Transmission attempt failed (expected without receiver).")
            time.sleep(0.5)

    if radio.isChipConnected():
        print("NRF24L01 chip remains connected and responsive.")
    else:
        print("NRF24L01 chip is no longer responding!")

if __name__ == "__main__":
    test_transmitter()
EOF

# Step 6: Set permissions for test script
chmod +x "$TEST_SCRIPT"
echo "Test script created and made executable."

# Step 7: Check if reboot is needed
if ! lsmod | grep -q spi_bcm2835; then
    echo -e "${RED}SPI not yet active. Rebooting in 5 seconds...${NC}"
    sleep 5
    sudo reboot
else
    echo "SPI is already active."
fi

# Step 8: Final instructions
echo -e "${GREEN}Setup complete!${NC}"
echo "To test the NRF24L01, activate the virtual environment and run the script:"
echo "  source $VENV_DIR/bin/activate"
echo "  python $TEST_SCRIPT"
echo "Note: Run with 'sudo' if you encounter SPI permission issues."