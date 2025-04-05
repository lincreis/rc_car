#!/home/pi/rc_car/venv/bin/python3
import socket
import struct
import time
import RPi.GPIO as GPIO
import pigpio

# Pin Definitions
LEFT_IN1 = 17
LEFT_IN2 = 27
RIGHT_IN3 = 18
RIGHT_IN4 = 23
SERVO_PIN = 19

# Calibration Constants (adjust as needed)
STEERING_ZERO_POINT = 0.0
STEERING_DEADBAND = 5
BRAKE_ZERO_POINT = 0.0
BRAKE_DEADBAND = 5
STEERING_RANGE = 90  # Max servo angle in degrees

# GPIO and pigpio Setup
GPIO.setmode(GPIO.BCM)
GPIO.setup([LEFT_IN1, LEFT_IN2, RIGHT_IN3, RIGHT_IN4], GPIO.OUT)

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
    print("Error: pigpio daemon not running. Start with 'sudo pigpiod'")
    exit()
pi.set_mode(SERVO_PIN, pigpio.OUTPUT)
pi.set_PWM_frequency(SERVO_PIN, 50)

# UDP Setup
UDP_IP = "0.0.0.0"
UDP_PORT = 5005
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((UDP_IP, UDP_PORT))

def set_servo(angle):
    """Sets servo angle."""
    angle = max(-STEERING_RANGE, min(STEERING_RANGE, angle))
    pulse_width = int(((angle + 90) / 180) * (1330 - 630) + 630)  # Map -90 to 90 degrees to 630-1330 µs
    pi.set_servo_pulsewidth(SERVO_PIN, pulse_width)

def set_motors(speed):
    """Controls motor speed."""
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
        left_reverse_pwm.ChangeDutyCycle(0)
        right_forward_pwm.ChangeDutyCycle(0)
        right_reverse_pwm.ChangeDutyCycle(0)

try:
    print("Listening for joystick data...")
    while True:
        data, _ = sock.recvfrom(1024)
        throttle_percent, brake_percent, steering_value = struct.unpack('fff', data)

        # Apply deadbands
        steering_value = 0.0 if abs(steering_value - STEERING_ZERO_POINT) < STEERING_DEADBAND else steering_value
        brake_percent = 0.0 if abs(brake_percent - BRAKE_ZERO_POINT) < BRAKE_DEADBAND else brake_percent

        # Clamp values
        throttle = max(0, min(100, throttle_percent))
        steering = max(-STEERING_RANGE, min(STEERING_RANGE, steering_value))
        brake = max(0, min(100, brake_percent))

        # Calculate speed
        speed = throttle - brake
        set_motors(speed)
        set_servo(steering)

        print(f"Throttle: {throttle:.2f}, Brake: {brake:.2f}, Steering: {steering:.2f}, Speed: {speed:.2f}")

except KeyboardInterrupt:
    print("Shutting down...")
except Exception as e:
    print(f"Error: {e}")
finally:
    set_motors(0)
    set_servo(0)
    left_forward_pwm.stop()
    left_reverse_pwm.stop()
    right_forward_pwm.stop()
    right_reverse_pwm.stop()
    GPIO.cleanup()
    pi.stop()
    sock.close()
    print("Clean shutdown complete.")