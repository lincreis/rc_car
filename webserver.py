#!/usr/bin/python3
from flask import Flask, Response, render_template
import cv2
import RPi.GPIO as GPIO
from pyrf24 import RF24, RF24_PA_MAX, RF24_1MBPS
import struct
import threading

app = Flask(__name__)

# GPIO Setup
GPIO.setmode(GPIO.BCM)
LED_PIN1, LED_PIN2 = 20, 21
GPIO.setup([LED_PIN1, LED_PIN2], GPIO.OUT)

# NRF24 Setup
radio = RF24(25, 0)
pipes = [0xF0F0F0F0E1, 0xF0F0F0F0D2]

camera = cv2.VideoCapture(0)
control_lock = threading.Lock()

def setup_radio():
    radio.begin()
    radio.setPALevel(RF24_PA_MAX)
    radio.setDataRate(RF24_1MBPS)
    radio.openWritingPipe(pipes[1])

def gen_frames():
    while True:
        success, frame = camera.read()
        if not success:
            break
        ret, buffer = cv2.imencode('.jpg', frame)
        frame = buffer.tobytes()
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')

def send_control(throttle, brake, steering):
    with control_lock:
        payload = struct.pack('fff', float(throttle), float(brake), float(steering))
        radio.write(payload)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/video_feed')
def video_feed():
    return Response(gen_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/control/<action>/<value>')
def control(action, value):
    if action == 'move':
        throttle, steering = map(float, value.split(','))
        send_control(throttle, 0, steering)
    elif action == 'led1':
        GPIO.output(LED_PIN1, int(value))
    elif action == 'led2':
        GPIO.output(LED_PIN2, int(value))
    elif action == 'shutdown':
        send_control(0, 0, 0)  # Stop car
        threading.Timer(1.0, lambda: os.system('sudo shutdown now')).start()
    return 'OK'

if __name__ == '__main__':
    setup_radio()
    try:
        app.run(host='0.0.0.0', port=5000, threaded=True)
    finally:
        camera.release()
        GPIO.cleanup()
        radio.powerDown()