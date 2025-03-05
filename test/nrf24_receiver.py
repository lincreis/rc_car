from pyrf24 import RF24, RF24_PA_MAX, RF24_1MBPS
import time

# Initialize NRF24L01: CE on GPIO25, CSN on SPI0 CS0 (GPIO8)
radio = RF24(25, 0)
pipe = b"1Node"

def setup_radio():
    if not radio.begin():
        print("Radio hardware is not responding!")
        return False
    radio.setPALevel(RF24_PA_MAX)
    radio.setDataRate(RF24_1MBPS)
    radio.setChannel(100)
    radio.openReadingPipe(1, pipe)  # Listen on pipe "1Node"
    radio.startListening()  # Set to RX mode
    print("Receiver initialized. Listening for messages...")
    return True

def receive_message():
    while True:
        if radio.available():
            length = radio.getDynamicPayloadSize()
            if length > 0:
                received = radio.read(length)
                try:
                    message = received.decode('utf-8')
                    print(f"Received: '{message}' ({length} bytes)")
                except UnicodeDecodeError:
                    print(f"Received raw bytes: {received} ({length} bytes)")
        time.sleep(0.1)  # Small delay to avoid busy-waiting

if __name__ == "__main__":
    if not setup_radio():
        exit()
    try:
        receive_message()
    except KeyboardInterrupt:
        print("\nReceiver stopped by user.")
        radio.stopListening()