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
    radio.openWritingPipe(pipe)
    radio.stopListening()  # Set to TX mode
    print("Transmitter initialized.")
    return True

def send_message(message):
    payload = message.encode('utf-8')
    if len(payload) > 32:
        print("Error: Message exceeds 32 bytes! Truncating to 32 bytes.")
        payload = payload[:32]
    print(f"Sending: '{message}' ({len(payload)} bytes)")
    if radio.write(payload):
        print("Message sent successfully!")
    else:
        print("Transmission failed (no acknowledgment from receiver).")
    time.sleep(0.5)  # Small delay between sends

if __name__ == "__main__":
    if not setup_radio():
        exit()

    print("Enter a message to send (max 32 bytes). Type 'exit' to quit.")
    while True:
        message = input("Message: ").strip()
        if message.lower() == "exit":
            print("Exiting transmitter.")
            break
        if not message:
            print("Empty message ignored.")
            continue
        send_message(message)