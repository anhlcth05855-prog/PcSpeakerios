import asyncio
import io
import json
import socket
import sys
import threading
import time
import numpy as np
import qrcode
import soundcard as sc
import websockets

PORT = 8080
DISCOVERY_PORT = 8888
SAMPLE_RATE = 48000
CHANNELS = 2
CHUNK_FRAMES = 960  # 20ms chunk @ 48kHz

connected_clients = set()
total_frames_sent = 0
total_bytes_sent = 0
audio_queue = asyncio.Queue(maxsize=30)
latest_audio_peak = 0.0


def get_local_ip():
    """Find the machine's local LAN IP address."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = "127.0.0.1"
    finally:
        s.close()
    return ip


def udp_discovery_loop(local_ip):
    """
    Broadcasts UDP beacon on port 8888 so iOS/Android apps can auto-discover this PC
    without needing to scan any QR code or type any IP address.
    """
    hostname = socket.gethostname()
    beacon_payload = json.dumps({
        "service": "pc-speaker",
        "name": hostname,
        "ip": local_ip,
        "port": PORT,
        "ws_url": f"ws://{local_ip}:{PORT}"
    }).encode("utf-8")

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.settimeout(1.0)

    try:
        sock.bind(("", DISCOVERY_PORT))
    except Exception as e:
        print(f"[Auto-Discovery] Warning: Could not bind discovery port {DISCOVERY_PORT}: {e}")

    broadcast_addr = ("255.255.255.255", DISCOVERY_PORT)

    last_broadcast_time = 0
    while True:
        now = time.time()
        # Broadcast beacon every 1.5 seconds
        if now - last_broadcast_time > 1.5:
            try:
                sock.sendto(beacon_payload, broadcast_addr)
                last_broadcast_time = now
            except Exception:
                pass

        # Listen for probe requests from phone
        try:
            data, client_addr = sock.recvfrom(1024)
            msg = data.decode("utf-8", errors="ignore").strip()
            if "DISCOVER_PC_SPEAKER" in msg:
                # Reply directly to the discovering phone
                sock.sendto(beacon_payload, client_addr)
        except (socket.timeout, BlockingIOError):
            pass
        except Exception:
            time.sleep(0.1)


def push_audio_chunk(raw_bytes):
    """Thread-safe chunk queueing inside the asyncio event loop."""
    if audio_queue.full():
        try:
            audio_queue.get_nowait()
        except asyncio.QueueEmpty:
            pass
    try:
        audio_queue.put_nowait(raw_bytes)
    except asyncio.QueueFull:
        pass


def capture_audio_loop(loop):
    """Captures system audio via Windows WASAPI Loopback at 48kHz Float32 stereo, dynamically tracking default device."""
    global total_frames_sent, total_bytes_sent, latest_audio_peak

    while True:
        try:
            speaker = sc.default_speaker()
            speaker_id = str(speaker.id)
            print(f"\n[WASAPI Audio Engine] Default Speaker: {speaker.name}")
            mic = sc.get_microphone(id=speaker_id, include_loopback=True)
            print(f"[WASAPI Audio Engine] Capturing from: {mic.name} (48,000 Hz Stereo)")

            with mic.recorder(samplerate=SAMPLE_RATE, channels=CHANNELS, blocksize=CHUNK_FRAMES) as recorder:
                check_counter = 0
                while True:
                    # Every ~2 seconds, verify default speaker hasn't changed
                    check_counter += 1
                    if check_counter >= 100:
                        check_counter = 0
                        try:
                            curr_spk = sc.default_speaker()
                            if str(curr_spk.id) != speaker_id:
                                print(f"\n[WASAPI Audio Engine] Default speaker switched to: {curr_spk.name}. Reconnecting...")
                                break
                        except Exception:
                            pass

                    data = recorder.record(numframes=CHUNK_FRAMES)
                    if data is None or len(data) == 0:
                        continue

                    if data.dtype != np.float32:
                        data = data.astype(np.float32)

                    peak = float(np.max(np.abs(data)))
                    latest_audio_peak = (latest_audio_peak * 0.7) + (peak * 0.3)

                    raw_bytes = data.tobytes()

                    if connected_clients:
                        loop.call_soon_threadsafe(push_audio_chunk, raw_bytes)

        except Exception as e:
            print(f"\n[WASAPI Audio Engine] Audio device notice: {e}. Retrying in 1s...")
            time.sleep(1.0)


async def broadcast_worker():
    """Distributes PCM chunks from audio_queue to all connected iPhone/Android clients."""
    global total_frames_sent, total_bytes_sent
    while True:
        raw_bytes = await audio_queue.get()
        if not connected_clients:
            continue

        byte_count = len(raw_bytes)
        total_bytes_sent += byte_count
        total_frames_sent += byte_count // 8

        dead_clients = set()
        for ws in list(connected_clients):
            try:
                await ws.send(raw_bytes)
            except Exception:
                dead_clients.add(ws)

        for dc in dead_clients:
            connected_clients.discard(dc)


async def ws_handler(websocket):
    """Handles new incoming client WebSocket connections."""
    client_ip = websocket.remote_address[0] if websocket.remote_address else "Unknown"
    print(f"\n[+] iPhone / Receiver Connected: {client_ip}")
    connected_clients.add(websocket)
    try:
        # Keep connection open until phone disconnects or network drops
        await websocket.wait_closed()
    except Exception:
        pass
    finally:
        connected_clients.discard(websocket)
        print(f"\n[-] iPhone / Receiver Disconnected: {client_ip}")


def print_banner(local_ip):
    connection_url = f"ws://{local_ip}:{PORT}"
    print("\n" + "=" * 65)
    print("   PC SPEAKER - WINDOWS SENDER (AUTO-DISCOVERY & 48kHz HI-FI)")
    print("=" * 65)
    print(f" * Computer Name    : {socket.gethostname()}")
    print(f" * Local Network IP : {local_ip}")
    print(f" * WebSocket Port   : {PORT}")
    print(f" * Auto-Discovery   : ACTIVE (UDP port {DISCOVERY_PORT})")
    print(f" * Audio Format     : Uncompressed Float32 PCM @ 48,000 Hz Stereo")
    print("=" * 65)
    print("\n>>> TIP: Open iOS app -> Tap 'Auto Connect' or scan QR below! <<<\n")

    qr = qrcode.QRCode(border=1)
    qr.add_data(connection_url)
    qr.make(fit=True)
    f = io.StringIO()
    qr.print_ascii(out=f, invert=True)
    f.seek(0)
    print(f.read())
    print("-" * 65)
    print("Waiting for iOS app to connect...\n")


async def main():
    local_ip = get_local_ip()
    print_banner(local_ip)

    loop = asyncio.get_running_loop()

    # 1. Start UDP Discovery Broadcaster thread
    discovery_thread = threading.Thread(target=udp_discovery_loop, args=(local_ip,), daemon=True)
    discovery_thread.start()

    # 2. Start WASAPI Audio Capture in background thread
    audio_thread = threading.Thread(target=capture_audio_loop, args=(loop,), daemon=True)
    audio_thread.start()

    # 3. Start WebSocket broadcast worker
    asyncio.create_task(broadcast_worker())

    # 4. Start WebSocket Server with compression disabled and high throughput limits
    async with websockets.serve(
        ws_handler,
        "0.0.0.0",
        PORT,
        compression=None,
        write_limit=2 * 1024 * 1024,
        max_queue=128,
        ping_interval=10,
        ping_timeout=15
    ):
        while True:
            await asyncio.sleep(0.5)
            if connected_clients:
                mb_sent = total_bytes_sent / (1024 * 1024)
                bars = int(min(1.0, latest_audio_peak * 2.0) * 15)
                meter = "█" * bars + "░" * (15 - bars)
                status = f"{int(latest_audio_peak * 100):2d}%"
                if latest_audio_peak < 0.001:
                    status = "MUTE / SILENCE"
                sys.stdout.write(
                    f"\r[Streaming] Clients: {len(connected_clients)} | Sound: [{meter}] {status} | Sent: {mb_sent:.1f} MB   "
                )
                sys.stdout.flush()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n[!] PC Sender stopped.")
