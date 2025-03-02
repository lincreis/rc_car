# joystick_pi.py
#!/usr/bin/python3
import spidev
import time
from nrf24 import NRF24
import RPi.GPIO as GPIO

# MCP3008 Setup
spi = spidev.SpiDev()
spi.open(0, 0)
spi.max_speed_hz = 1350000

def read_adc(channel):
    if channel < 0 or channel > 7:
        return -1
    r = spi.xfer2([1, (8 + channel) << 4, 0])
    return ((r[1] & 3) << 8) + r[2]

# NRF24 Setup
radio = NRF24()
radio.begin(0, 0, 8, 7)  # CE GPIO 8, CSN GPIO 7
radio.setRetries(15, 15)
radio.setPayloadSize(32)
radio.setChannel(0x60)
radio.setDataRate(NRF24.BR_1MBPS)
radio.setPALevel(NRF24.PA_MAX)
radio.openWritingPipe([0xe7, 0xe7, 0xe7, 0xe7, 0xe7])
radio.printDetails()

# Joystick Button Setup
GPIO.setmode(GPIO.BCM)
GPIO.setup(6, GPIO.IN, pull_up_down=GPIO.PUD_UP)

try:
    print("Joystick Pi: Sending data...")
    while True:
        x_pos = read_adc(0)  # X-axis (0-1023)
        y_pos = read_adc(1)  # Y-axis (0-1023)
        button = not GPIO.input(6)  # Button pressed = 1

        # Normalize to -100 to 100 for steering and speed
        steering = ((x_pos - 512) / 512) * 100  # -100 to 100
        speed = ((512 - y_pos) / 512) * 100     # -100 to 100

        payload = struct.pack("ffb", speed, steering, button)
        radio.write(payload)
        print(f"Sent: Speed={speed:.1f}, Steering={steering:.1f}, Button={button}")
        time.sleep(0.1)

except KeyboardInterrupt:
    print("Shutting down...")
finally:
    spi.close()
    GPIO.cleanup()