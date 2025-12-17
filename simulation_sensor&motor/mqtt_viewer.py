import json
import paho.mqtt.client as mqtt

BROKER = "192.168.0.43"     # or 192.168.0.43
TOPIC  = "almed/ahu/#"

def on_connect(client, userdata, flags, rc):
    print("✅ Connected, listening for telemetry...\n")
    client.subscribe(TOPIC)

def on_message(client, userdata, msg):
    try:
        data = json.loads(msg.payload.decode())
        t = data.get("temperature")
        h = data.get("humidity")
        if t is not None and h is not None:
            print(f"[{msg.topic}]  Temp: {t:.2f}°C  |  Humidity: {h:.2f}%")
        else:
            print(f"[{msg.topic}] {msg.payload.decode()}")
    except Exception:
        print(f"[{msg.topic}] {msg.payload.decode()}")

client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message
client.connect(BROKER, 1883)
client.loop_forever()
