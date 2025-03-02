#!/home/pi/rc_car/venv/bin/python3
from flask import Flask, Response, render_template_string
import picamera2
import io
import time
import RPi.GPIO as GPIO
from threading import Lock

app = Flask(__name__)
camera = picamera2.Picamera2()
camera.configure(camera.create_preview_configuration(main={"size": (640, 480)}))
camera.start()
lock = Lock()

LEFT_IN1, LEFT_IN2 = 17, 27
RIGHT_IN3, RIGHT_IN4 = 18, 23
ENA, ENB = 12, 13
SERVO_PIN = 19
LED1, LED2 = 20, 21
GPIO.setmode(GPIO.BCM)
GPIO.setup([LEFT_IN1, LEFT_IN2, RIGHT_IN3, RIGHT_IN4, ENA, ENB, SERVO_PIN, LED1, LED2], GPIO.OUT)
left_pwm = GPIO.PWM(ENA, 100)
right_pwm = GPIO.PWM(ENB, 100)
servo_pwm = GPIO.PWM(SERVO_PIN, 50)
left_pwm.start(0)
right_pwm.start(0)
servo_pwm.start(0)

global_speed = 0
global_steering = 0

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

def gen_frames():
    while True:
        with lock:
            stream = io.BytesIO()
            camera.capture_file(stream, format='jpeg')
            frame = stream.getvalue()
            stream.close()
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')
        time.sleep(0.1)

@app.route('/video_feed')
def video_feed():
    return Response(gen_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/')
def index():
    return render_template_string('''
    <html>
    <head><title>Robot Control</title></head>
    <body>
        <h1>Robot Control</h1>
        <img src="{{ url_for('video_feed') }}" width="640" height="480">
        <br>
        <button onclick="control('forward')">Forward</button>
        <button onclick="control('backward')">Backward</button>
        <button onclick="control('left')">Left</button>
        <button onclick="control('right')">Right</button>
        <button onclick="control('stop')">Stop</button>
        <br><br>
        <button onclick="control('led1')">LED 1</button>
        <button onclick="control('led2')">LED 2</button>
        <button onclick="control('shutdown')">Shutdown</button>
        <script>
        function control(action) {
            fetch('/control/' + action);
        }
        </script>
    </body>
    </html>
    ''')

@app.route('/control/<action>')
def control(action):
    global global_speed, global_steering
    with lock:
        if action == 'forward':
            global_speed = 50
        elif action == 'backward':
            global_speed = -50
        elif action == 'left':
            global_steering = -50
        elif action == 'right':
            global_steering = 50
        elif action == 'stop':
            global_speed = 0
            global_steering = 0
        elif action == 'led1':
            GPIO.output(LED1, not GPIO.input(LED1))
        elif action == 'led2':
            GPIO.output(LED2, not GPIO.input(LED2))
        elif action == 'shutdown':
            set_motors(0)
            set_servo(0)
            GPIO.cleanup()
            import os
            os.system('sudo shutdown now')
        set_motors(global_speed)
        set_servo(global_steering)
    return '', 204

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, threaded=True)