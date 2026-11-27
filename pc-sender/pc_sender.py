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
audio_queue = asyncio.Queue(maxsize=120)
latest_audio_peak = 0.0
active_speaker_id = None
device_switch_requested = threading.Event()


def get_local_ip():
    """Find the machine's primary local LAN IP address, prioritizing 192.168.x.x, 10.x.x.x, 172.x.x.x over virtual VPNs."""
    hostname = socket.gethostname()
    candidates = []
    try:
        for item in socket.getaddrinfo(hostname, None):
            if item[0] == socket.AF_INET:
                ip = item[4][0]
                if not ip.startswith("127."):
                    candidates.append(ip)
    except Exception:
        pass

    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        connected_ip = s.getsockname()[0]
        s.close()
        if connected_ip not in candidates:
            candidates.append(connected_ip)
    except Exception:
        pass

    # Priority score: real home LAN first, then tethering, avoid virtual adapters (like Radmin 26.x)
    def ip_score(ip):
        if ip.startswith("192.168."): return 1
        if ip.startswith("172.20."): return 2   # iPhone USB / Bluetooth PAN
        if ip.startswith("10."): return 3
        if ip.startswith("172."): return 4
        return 10  # Virtual VPNs like 26.x.x.x

    candidates.sort(key=ip_score)
    return candidates[0] if candidates else "127.0.0.1"


def udp_discovery_loop(local_ip):
    """
    Broadcasts UDP beacon on port 8888 across all LAN targets so iOS apps auto-discover this PC instantly.
    """
    hostname = socket.gethostname()
    friendly_name = f"{hostname} (PC Speaker)"
    beacon_payload = json.dumps({
        "service": "pc-speaker",
        "name": friendly_name,
        "ip": local_ip,
        "port": PORT,
        "ws_url": f"ws://{local_ip}:{PORT}"
    }).encode("utf-8")

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.settimeout(0.2)

    try:
        sock.bind(("", DISCOVERY_PORT))
    except Exception as e:
        print(f"[Auto-Discovery] Warning: Could not bind discovery port {DISCOVERY_PORT}: {e}")

    # Calculate subnet broadcast address (e.g. 192.168.1.255)
    parts = local_ip.split(".")
    subnet_broadcast = f"{parts[0]}.{parts[1]}.{parts[2]}.255" if len(parts) == 4 else "255.255.255.255"
    broadcast_targets = [
        ("255.255.255.255", DISCOVERY_PORT),
        (subnet_broadcast, DISCOVERY_PORT),
        ("172.20.10.15", DISCOVERY_PORT) # iPhone hotspot subnet
    ]

    # Fire 3 quick beacons on startup for instant pairing
    for _ in range(3):
        for b_addr in broadcast_targets:
            try:
                sock.sendto(beacon_payload, b_addr)
            except Exception:
                pass
        time.sleep(0.05)

    last_broadcast_time = time.time()
    while True:
        now = time.time()
        # Fast beaconing: 0.35s when searching, 1.2s when already streaming
        interval = 0.35 if not connected_clients else 1.2
        if now - last_broadcast_time > interval:
            for b_addr in broadcast_targets:
                try:
                    sock.sendto(beacon_payload, b_addr)
                except Exception:
                    pass
            last_broadcast_time = now

        # Listen for probe requests from phone
        try:
            data, client_addr = sock.recvfrom(1024)
            msg = data.decode("utf-8", errors="ignore").strip()
            if "DISCOVER_PC_SPEAKER" in msg:
                # Reply immediately directly to discovering phone twice to avoid UDP packet drop
                sock.sendto(beacon_payload, client_addr)
                sock.sendto(beacon_payload, client_addr)
        except (socket.timeout, BlockingIOError):
            pass
        except Exception:
            time.sleep(0.02)


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


def device_monitor_loop():
    """Monitors default audio output changes in a dedicated thread so WASAPI capture never blocks."""
    global active_speaker_id
    while True:
        time.sleep(4.0)
        try:
            curr_spk = sc.default_speaker()
            if active_speaker_id is not None and str(curr_spk.id) != active_speaker_id:
                print(f"\n[WASAPI Audio Engine] Default output switched to: {curr_spk.name}")
                device_switch_requested.set()
        except Exception:
            pass


def capture_audio_loop(loop):
    """Captures system audio via Windows WASAPI Loopback at 48kHz Float32 stereo without blocking."""
    global total_frames_sent, total_bytes_sent, latest_audio_peak, active_speaker_id

    while True:
        device_switch_requested.clear()
        try:
            speaker = sc.default_speaker()
            active_speaker_id = str(speaker.id)
            print(f"\n[WASAPI Audio Engine] Default Speaker: {speaker.name}")
            mic = sc.get_microphone(id=active_speaker_id, include_loopback=True)
            print(f"[WASAPI Audio Engine] Capturing from: {mic.name} (48,000 Hz Stereo)")

            with mic.recorder(samplerate=SAMPLE_RATE, channels=CHANNELS, blocksize=CHUNK_FRAMES) as recorder:
                while not device_switch_requested.is_set():
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

        clients = list(connected_clients)
        if clients:
            tasks = [ws.send(raw_bytes) for ws in clients]
            results = await asyncio.gather(*tasks, return_exceptions=True)
            for ws, res in zip(clients, results):
                if isinstance(res, Exception):
                    connected_clients.discard(ws)


async def ws_handler(websocket):
    """Handles new incoming client WebSocket connections with TCP_NODELAY enabled."""
    client_ip = websocket.remote_address[0] if websocket.remote_address else "Unknown"
    
    # Disable Nagle's algorithm to eliminate packet buffering latency & micro-stutter
    try:
        sock = websocket.transport.get_extra_info('socket')
        if sock:
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    except Exception:
        pass
        
    print(f"\n[+] iPhone / Receiver Connected: {client_ip} (Instant Handshake Active)")
    
    # Immediately send greeting handshake so iOS client confirms connection instantly (< 10ms)
    # Even if PC is completely silent, the app connects immediately without waiting for sound!
    try:
        handshake_payload = json.dumps({
            "status": "connected",
            "name": socket.gethostname(),
            "port": PORT,
            "sampleRate": SAMPLE_RATE,
            "channels": CHANNELS
        })
        await websocket.send(handshake_payload)
    except Exception:
        pass

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

    # 2. Start Audio Device Change Monitor thread
    monitor_thread = threading.Thread(target=device_monitor_loop, daemon=True)
    monitor_thread.start()

    # 3. Start WASAPI Audio Capture in background thread
    audio_thread = threading.Thread(target=capture_audio_loop, args=(loop,), daemon=True)
    audio_thread.start()

    # 4. Start WebSocket broadcast worker
    asyncio.create_task(broadcast_worker())

    # 5. Start WebSocket Server with compression disabled and high throughput limits
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
