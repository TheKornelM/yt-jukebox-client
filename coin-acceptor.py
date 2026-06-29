import os
import sys
import time
import queue
import threading
import requests
import OPi.GPIO as GPIO

API_KEY = os.getenv("COIN_API_KEY")
if not API_KEY:
    print("[CRITICAL] COIN_API_KEY environment variable is not set. Terminating execution.")
    sys.exit(1)

TARGET_URL = "https://yt-jukebox.duckdns.org/api/coins/throw"

COIN_PIN = 23
MIN_PULSE_GAP = 0.05  # 50ms software debouncing window

last_pulse_time = 0
pulse_lock = threading.Lock()
offline_queue = queue.Queue()

def send_coin_request(amount):
    """Dispatches HTTP POST transaction. Returns False on failure to trigger queuing."""
    headers = {
        "X-Coin-Api-Key": API_KEY
    }
    params = {
        "amount": amount
    }
    
    try:
        response = requests.post(TARGET_URL, headers=headers, params=params, timeout=5)
        if response.status_code == 200:
            print(f"[OK] {amount} HUF successfully processed by server.")
            return True
        else:
            print(f"[ERROR] Server side failure ({response.status_code}). Preserving locally.")
            return False
    except requests.RequestException as e:
        print(f"[NETWORK] Target host unreachable ({type(e).__name__}). Enqueuing token.")
        return False

def queue_worker():
    """Asynchronous background channel processing transactional backlogs sequentially."""
    print("[INIT] Offline sync service initialized.")
    while True:
        amount = offline_queue.get()
        
        while not send_coin_request(amount):
            time.sleep(10)
            
        offline_queue.task_done()
        time.sleep(0.5)

def coin_callback(channel):
    """ISR hardware interrupt listener execution block tracking rising edges."""
    global last_pulse_time
    current_time = time.time()
    
    with pulse_lock:
        delta = current_time - last_pulse_time
        if delta > MIN_PULSE_GAP:
            print("[HARDWARE] Valid pulse detected. Staging 100 HUF deposit.")
            offline_queue.put(100)
            last_pulse_time = current_time

GPIO.setmode(GPIO.BOARD)
GPIO.setup(COIN_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
GPIO.add_event_detect(COIN_PIN, GPIO.FALLING, callback=coin_callback)
worker_thread = threading.Thread(target=queue_worker, daemon=True)
worker_thread.start()

print("[RUNNING] Listening for hard-currency telemetry streams...")

try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print("\nShutting down hardware abstraction layers.")
    GPIO.cleanup()
    sys.exit(0)