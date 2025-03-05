#!/usr/bin/python3
import socket
import json
from http.server import SimpleHTTPRequestHandler
import socketserver
<<<<<<< HEAD
import picamera
=======
from picamera2 import Picamera2
>>>>>>> 61312fb (Update installation files)
import io
import time

UDP_IP = "localhost"
UDP_PORT = 5005
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)


class StreamingHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
<<<<<<< HEAD
        self.camera = picamera.PiCamera()
        self.camera.resolution = (640, 480)
        self.camera.framerate = 24
=======
        self.camera = Picamera2()
        self.camera.configure(self.camera.create_video_configuration(main={"size": (640, 480)}))
        self.camera.start()
>>>>>>> 61312fb (Update installation files)
        super().__init__(*args, **kwargs)

    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            html = """
            <html>
                <body>
                    <img src="/stream.mjpg" width="640" height="480" />
                    <div>
                        <button onclick="sendCommand('forward')">Forward</button>
                        <button onclick="sendCommand('stop')">Stop</button>
                        <button onclick="sendCommand('left')">Left</button>
                        <button onclick="sendCommand('right')">Right</button>
                        <button onclick="sendCommand('led')">LED Toggle</button>
                        <button onclick="sendCommand('shutdown')">Shutdown</button>
                    </div>
                    <script>
                        function sendCommand(cmd) {
                            fetch('/control?cmd=' + cmd)
                        }
                    </script>
                </body>
            </html>
            """
            self.wfile.write(html.encode())
        elif self.path == '/stream.mjpg':
            self.send_response(200)
            self.send_header('Content-type', 'multipart/x-mixed-replace; boundary=frame')
            self.end_headers()
<<<<<<< HEAD
            stream = io.BytesIO()
            try:
                for _ in self.camera.capture_continuous(stream, 'jpeg', use_video_port=True):
                    self.wfile.write(b'--frame\r\n')
                    self.wfile.write(b'Content-Type: image/jpeg\r\n\r\n')
                    self.wfile.write(stream.getvalue())
                    self.wfile.write(b'\r\n')
                    stream.seek(0)
                    stream.truncate()
=======
            try:
                while True:
                    buf = io.BytesIO()
                    self.camera.capture_file(buf, format='jpeg')
                    buf.seek(0)
                    self.wfile.write(b'--frame\r\n')
                    self.wfile.write(b'Content-Type: image/jpeg\r\n\r\n')
                    self.wfile.write(buf.getvalue())
                    self.wfile.write(b'\r\n')
                    time.sleep(0.04)  # ~24 fps
>>>>>>> 61312fb (Update installation files)
            except Exception as e:
                print(f"Streaming error: {e}")
        else:
            super().do_GET()

    def do_GET_control(self):
        cmd = self.path.split('cmd=')[-1]
        control_data = {"throttle": 0, "brake": 0, "steering": 0, "led": False, "shutdown": False}

        if cmd == 'forward':
            control_data["throttle"] = 50
        elif cmd == 'stop':
            control_data = {"throttle": 0, "brake": 0, "steering": 0}
        elif cmd == 'left':
            control_data["steering"] = -50
        elif cmd == 'right':
            control_data["steering"] = 50
        elif cmd == 'led':
            control_data["led"] = True
        elif cmd == 'shutdown':
            control_data["shutdown"] = True

        sock.sendto(json.dumps(control_data).encode(), (UDP_IP, UDP_PORT))
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        if self.path.startswith('/control'):
            self.do_GET_control()
        else:
            super().do_GET()


PORT = 8000
Handler = StreamingHandler

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"Serving at port {PORT}")
    httpd.serve_forever()