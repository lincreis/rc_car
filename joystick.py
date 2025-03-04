#!/home/pi/rc_car_venv/bin/python3
from evdev import InputDevice, ecodes, list_devices
import socket
import struct
import time
from pyrf24 import RF24, RF24_PA_MAX, RF24_1MBPS

# NRF24 Setup
radio = RF24(25, 0)  # CE on GPIO25, CSN on SPI0
pipes = [0xF0F0F0F0E1, 0xF0F0F0F0D2]


def setup_radio():
    if not radio.begin():
        raise RuntimeError("Radio hardware not responding!")
    radio.setPALevel(RF24_PA_MAX)
    radio.setDataRate(RF24_1MBPS)
    radio.openWritingPipe(pipes[0])
    radio.openReadingPipe(1, pipes[1])


# Joystick Setup
def find_joystick_device():
    devices = [InputDevice(path) for path in list_devices()]
    for device in devices:
        if "Thrustmaster" in device.name:
            print(f"Found joystick at: {device.path}")
            return device.path
    return None


def main():
    setup_radio()
    device_path = find_joystick_device()
    if not device_path:
        print("No joystick found!")
        exit(1)

    joystick = InputDevice(device_path)
    print(f"Connected to: {joystick}")

    # Calibration constants
    X_CENTER = 32767
    X_MIN = 0
    X_MAX = 65535
    THROTTLE_MAX = 1023
    BRAKE_MAX = 255
    STEERING_RANGE = 100

    try:
        for event in joystick.read_loop():
            if event.type == ecodes.EV_ABS:
                throttle = 0.0
                brake = 0.0
                steering = 0.0

                if event.code == ecodes.ABS_X:
                    value = event.value
                    steering = ((value - X_CENTER) / (X_MAX - X_CENTER)) * STEERING_RANGE if value > X_CENTER else \
                        ((value - X_CENTER) / (X_CENTER - X_MIN)) * STEERING_RANGE if value < X_CENTER else 0

                elif event.code == ecodes.ABS_RZ:
                    throttle = (event.value / THROTTLE_MAX) * 100

                elif event.code == ecodes.ABS_Y:
                    brake = (event.value / BRAKE_MAX) * 100

                # Pack and send via NRF24
                payload = struct.pack('fff', throttle, brake, steering)
                radio.write(payload)
                print(f"Sent: T={throttle:.1f}, B={brake:.1f}, S={steering:.1f}")

    except KeyboardInterrupt:
        print("Shutting down...")
    finally:
        radio.powerDown()


if __name__ == "__main__":
    main()