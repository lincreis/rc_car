#!/home/pi/rc_car/venv/bin/python3
import time
import struct
from RF24 import RF24, RF24_PA_MAX, RF24_1MBPS
import RPi.GPIO as GPIO
from threading import Thread

# Pin Definitions
LEFT_IN1, LEFT_IN2 = 17, 27
RIGHT_IN3, RIGHT_IN4 = 18, 23
ENA, ENB = 12, 13
SERVO_PIN = 19
LED1, LED2 = 20, 21

# GPIO Setup
GPIO.setmode(GPIO.BCM)
GPIO.setup([LEFT_IN1, LEFT_IN2, RIGHT_IN3, RIGHT_IN4, ENA, ENB, SERVO_PIN, LED1, LED2], GPIO.OUT)
left_pwm = GPIO.PWM(ENA, 100)
right_pwm = GPIO.PWM(ENB, 100)
servo_pwm = GPIO.PWM(SERVO_PIN, 50)
left_pwm.start(0)
right_pwm.start(0)
servo_pwm.start(0)

# NRF24 Setup
radio = RF24(8, 7)  # CE GPIO 8, CSN GPIO 7
radio.begin()
radio.setRetries(15, 15)
radio.setPayloadSize(32)
radio.setChannel(0x60)
radio.setDataRate(RF24_1MBPS)
radio.setPALevel(RF24_PA_MAX)
radio.openReadingPipe(1, bytes([0xe7, 0xe7, 0xe7, 0xe7, 0xe7]))
radio.startListening()
radio.printDetails()

def set_servo(angle):
    angle = max(-90, min(90, angle))
    duty = 2.5 + (angle + 90) / 18
    servo_pwm.ChangeDutyCycle(duty)

def set_motors(speed):
    speed = max(-100, min(100, speed))
    if speed > 0:
        GPIO.output(LEFT_IN1, GPIO.HIGH)
        GPIO.output(LEFT_IN2, GPIO.LOW)
        GPIO.output(RIGHT_IN3, GPIO.HIGH)
        GPIO.output(RIGHT_IN4, GPIO.LOW)
        left_pwm.ChangeDutyCycle(speed)
        right_pwm.ChangeDutyCycle(speed)
    elif speed < 0:
        GPIO.output(LEFT_IN1, GPIO.LOW)
        GPIO.output(LEFT_IN2, GPIO.HIGH)
        GPIO.output(RIGHT_IN3, GPIO.LOW)
        GPIO.output(RIGHT_IN4, GPIO.HIGH)
        left_pwm.ChangeDutyCycle(abs(speed))
        right_pwm.ChangeDutyCycle(abs(speed))
    else:
        GPIO.output(LEFT_IN1, GPIO.LOW)
        GPIO.output(LEFT_IN2, GPIO.LOW)
        GPIO.output(RIGHT_IN3, GPIO.LOW)
        GPIO.output(RIGHT_IN4, GPIO.LOW)
        left_pwm.ChangeDutyCycle(0)
        right_pwm.ChangeDutyCycle(0)

def control_loop():
    try:
        print("Robot Pi: Listening for data...")
        while True:
            if radio.available():
                payload = radio.read(32)
                speed, steering, button = struct.unpack("ffb", payload[:9])
                set_motors(speed)
                set_servo(steering)
                print(f"Received: Speed={speed:.1f}, Steering={steering:.1f}, Button={button}")
            time.sleep(0.1)
    except KeyboardInterrupt:
        print("Shutting down control...")
    finally:
        set_motors(0)
        set_servo(0)
        GPIO.cleanup()

if __name__ == "__main__":
    Thread(target=control_loop).start()