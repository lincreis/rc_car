#!/usr/bin/python3
from evdev import InputDevice, ecodes, list_devices
import socket
import struct
import time

def find_joystick_device():
    """Finds the event device path for the Thrustmaster T150RS."""
    devices = [InputDevice(path) for path in list_devices()]
    for device in devices:
        if "Thrustmaster Thrustmaster T150RS" in device.name:
            print(f"Found Thrustmaster T150RS at: {device.path}")
            return device.path
    print("Thrustmaster T150RS not found.")
    return None

device_path = find_joystick_device()
if device_path is None:
    exit()

joystick = InputDevice(device_path)
print("Connected to: {}".format(joystick))

UDP_IP = "myrobot.local"
UDP_PORT = 5005
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

# Calibration Constants (MUST BE CALIBRATED!)
X_CENTER = 32767
X_MIN = 0
X_MAX = 65535
THROTTLE_MAX = 1023
BRAKE_MAX = 255
Y_CENTER = 128
Z_CENTER = 128

# Steering Range Tuning (0-100)
STEERING_RANGE_PERCENT = 100

# Initialize variables
throttle_percent = 100.0
brake_percent = 100.0
steering_value = 0.0

try:
    for event in joystick.read_loop():
        if event.type == ecodes.EV_ABS:
            # Steering (ABS_X)
            if event.code == ecodes.ABS_X:
                if event.value > X_CENTER:
                    steering_value = (event.value - X_CENTER) / (X_MAX - X_CENTER) * STEERING_RANGE_PERCENT
                elif event.value < X_CENTER:
                    steering_value = (event.value - X_CENTER) / (X_CENTER - X_MIN) * STEERING_RANGE_PERCENT
                else:
                    steering_value = 0
                steering_value = max(-STEERING_RANGE_PERCENT, min(STEERING_RANGE_PERCENT, steering_value))

            # Throttle (ABS_RZ)
            elif event.code == ecodes.ABS_RZ:
                throttle_percent = event.value / THROTTLE_MAX * 100
                throttle_percent = max(0, min(100, throttle_percent))

            # Brake (ABS_Y or ABS_Z)
            elif event.code == ecodes.ABS_Y:
                brake_percent = event.value / BRAKE_MAX * 100
                brake_percent = max(0, min(100, brake_percent))

            # Pack and send data
            data = struct.pack('fff', throttle_percent, brake_percent, steering_value)
            sock.sendto(data, (UDP_IP, UDP_PORT))
            print("Sent: T={:.1f}, B={:.1f}, S={:.1f}".format(
                throttle_percent, brake_percent, steering_value))

except KeyboardInterrupt:
    print("Shutting down...")
finally:
    sock.close()
    print("Socket closed.")