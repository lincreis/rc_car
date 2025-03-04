#!/usr/bin/python3
import RPi.GPIO as GPIO
import pigpio
from pyrf24 import RF24, RF24_PA_MAX, RF24_1MBPS
import struct
import time

# Pin Definitions
LEFT_IN1, LEFT_IN2 = 17, 27
RIGHT_IN3, RIGHT_IN4 = 18, 23
SERVO_PIN = 19

# NRF24 Setup
radio = RF24(25, 0)  # CE on GPIO25, CSN on SPI0
pipes = [0xF0F0F0F0E1, 0xF0F0F0F0D2]

# GPIO Setup
GPIO.setmode(GPIO.BCM)
GPIO.setup([LEFT_IN1, LEFT_IN2, RIGHT_IN3, RIGHT_IN4], GPIO.OUT)
pi = pigpio.pi()

# PWM Setup
left_forward = GPIO.PWM(LEFT_IN1, 100)
left_reverse = GPIO.PWM(LEFT_IN2, 100)
right_forward = GPIO.PWM(RIGHT_IN3, 100)
right_reverse = GPIO.PWM(RIGHT_IN4, 100)


def setup_hardware():
    if not radio.begin():
        raise RuntimeError("Radio hardware not responding!")
    radio.setPALevel(RF24_PA_MAX)
    radio.setDataRate(RF24_1MBPS)
    radio.openWritingPipe(pipes[1])
    radio.openReadingPipe(1, pipes[0])
    radio.startListening()

    pi.set_PWM_frequency(SERVO_PIN, 50)
    for pwm in [left_forward, left_reverse, right_forward, right_reverse]:
        pwm.start(0)


def set_servo(angle):
    angle = max(-90, min(90, angle))
    pulse = int(((angle + 90) / 180) * (1330 - 630) + 630)
    pi.set_servo_pulsewidth(SERVO_PIN, pulse)


def set_motors(speed):
    speed = max(-100, min(100, speed))
    if speed > 0:
        left_forward.ChangeDutyCycle(speed)
        left_reverse.ChangeDutyCycle(0)
        right_forward.ChangeDutyCycle(speed)
        right_reverse.ChangeDutyCycle(0)
    elif speed < 0:
        left_forward.ChangeDutyCycle(0)
        left_reverse.ChangeDutyCycle(abs(speed))
        right_forward.ChangeDutyCycle(0)
        right_reverse.ChangeDutyCycle(abs(speed))
    else:
        for pwm in [left_forward, left_reverse, right_forward, right_reverse]:
            pwm.ChangeDutyCycle(0)


def main():
    setup_hardware()
    try:
        print("Listening for controls...")
        while True:
            if radio.available():
                payload = radio.read(12)  # 3 floats = 12 bytes
                throttle, brake, steering = struct.unpack('fff', payload)

                speed = max(0, min(100, throttle)) - max(0, min(100, brake))
                set_motors(speed)
                set_servo(steering)

                print(f"Received: T={throttle:.1f}, B={brake:.1f}, S={steering:.1f}")
            time.sleep(0.01)

    except KeyboardInterrupt:
        print("Shutting down...")
    finally:
        set_motors(0)
        set_servo(0)
        for pwm in [left_forward, left_reverse, right_forward, right_reverse]:
            pwm.stop()
        GPIO.cleanup()
        pi.stop()
        radio.powerDown()


if __name__ == "__main__":
    main()