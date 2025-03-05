#!/usr/bin/python3
import socket
import struct
import time
import RPi.GPIO as GPIO
import pigpio
import json
import os

# Pin Definitions
LEFT_IN1 = 17
LEFT_IN2 = 27
RIGHT_IN3 = 18
RIGHT_IN4 = 23
SERVO_PIN = 19
LED_PIN = 20  # Added LED control pin

# Calibration Constants
STEERING_ZERO_POINT = 0.0
STEERING_DEADBAND = 5
BRAKE_ZERO_POINT = 0.0
BRAKE_DEADBAND = 5

# GPIO Setup
GPIO.setmode(GPIO.BCM)
GPIO.setup([LEFT_IN1, LEFT_IN2, RIGHT_IN3, RIGHT_IN4, LED_PIN], GPIO.OUT)
GPIO.output(LED_PIN, GPIO.LOW)

left_forward_pwm = GPIO.PWM(LEFT_IN1, 100)
left_reverse_pwm = GPIO.PWM(LEFT_IN2, 100)
right_forward_pwm = GPIO.PWM(RIGHT_IN3, 100)
right_reverse_pwm = GPIO.PWM(RIGHT_IN4, 100)

left_forward_pwm.start(0)
left_reverse_pwm.start(0)
right_forward_pwm.start(0)
right_reverse_pwm.start(0)

pi = pigpio.pi()
if not pi.connected:
    print("Error: pigpio daemon not running")
    exit()
pi.set_mode(SERVO_PIN, pigpio.OUTPUT)
pi.set_PWM_frequency(SERVO_PIN, 50)

# UDP Setup
UDP_IP = "0.0.0.0"
UDP_PORT = 5005
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((UDP_IP, UDP_PORT))


def set_servo(angle):
    angle = max(-90, min(90, angle))
    pulse_width = int(((angle + 90) / 180) * (1330 - 630) + 630)
    pi.set_servo_pulsewidth(SERVO_PIN, pulse_width)


def set_motors(speed):
    speed = max(-100, min(100, speed))
    if speed > 0:
        left_forward_pwm.ChangeDutyCycle(speed)
        left_reverse_pwm.ChangeDutyCycle(0)
        right_forward_pwm.ChangeDutyCycle(speed)
        right_reverse_pwm.ChangeDutyCycle(0)
    elif speed < 0:
        left_forward_pwm.ChangeDutyCycle(0)
        left_reverse_pwm.ChangeDutyCycle(abs(speed))
        right_forward_pwm.ChangeDutyCycle(0)
        right_reverse_pwm.ChangeDutyCycle(abs(speed))
    else:
        left_forward_pwm.ChangeDutyCycle(0)
        left_reverse_pwm.start(0)
        right_forward_pwm.ChangeDutyCycle(0)
        right_reverse_pwm.ChangeDutyCycle(0)


def control_led(state):
    GPIO.output(LED_PIN, GPIO.HIGH if state else GPIO.LOW)


def shutdown():
    set_motors(0)
    set_servo(0)
    control_led(False)
    os.system("sudo shutdown -h now")


try:
    print("Listening for control data...")
    while True:
        data, _ = sock.recvfrom(1024)
        try:
            # Try to decode as JSON for web control
            control_data = json.loads(data.decode())
            if "shutdown" in control_data and control_data["shutdown"]:
                shutdown()
            throttle = control_data.get("throttle", 0)
            brake = control_data.get("brake", 0)
            steering = control_data.get("steering", 0)
            led_state = control_data.get("led", False)
            control_led(led_state)
        except json.JSONDecodeError:
            # Fallback to original UDP format
            throttle, brake, steering = struct.unpack('fff', data)

        # Apply deadbands
        steering = 0.0 if abs(steering - STEERING_ZERO_POINT) < STEERING_DEADBAND else steering
        brake = 0.0 if abs(brake - BRAKE_ZERO_POINT) < BRAKE_DEADBAND else brake

        # Clamp values
        throttle = max(0, min(100, throttle))
        steering = max(-100, min(100, steering))
        brake = max(0, min(100, brake))

        speed = throttle - brake
        set_motors(speed)
        set_servo(steering)

except Exception as e:
    print(f"Error: {e}")
finally:
    set_motors(0)
    set_servo(0)
    GPIO.cleanup()
    pi.stop()
    sock.close()