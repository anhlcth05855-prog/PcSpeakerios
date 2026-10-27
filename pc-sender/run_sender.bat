@echo off
title PC Speaker Sender
echo [PC Speaker] Checking requirements...
pip install -r requirements.txt
echo [PC Speaker] Starting PC Audio Loopback Streamer...
python pc_sender.py
pause
