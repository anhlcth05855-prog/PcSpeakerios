@echo off
cd /d "%~dp0"
title PC Speaker Sender
echo ===================================================
echo             PC SPEAKER - AUDIO SENDER
echo ===================================================
echo [1/3] Checking and installing Python dependencies...
pip install -r requirements.txt
echo [2/3] Configuring Windows Firewall for PC Speaker (Ports 8080 and 8888)...
netsh advfirewall firewall add rule name="PC Speaker WebSocket" dir=in action=allow protocol=TCP localport=8080 >nul 2>&1
netsh advfirewall firewall add rule name="PC Speaker Discovery" dir=in action=allow protocol=UDP localport=8888 >nul 2>&1
echo [3/3] Starting WASAPI audio loopback stream...
python pc_sender.py
pause
