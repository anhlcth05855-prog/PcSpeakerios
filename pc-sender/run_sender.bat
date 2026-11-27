@echo off
cd /d "%~dp0"
title PC Speaker Sender
echo ===================================================
echo             PC SPEAKER - AUDIO SENDER
echo ===================================================
echo [1/3] Checking and freeing audio port 8080...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8080 ^| findstr LISTENING') do (
    if not "%%a"=="0" (
        taskkill /F /PID %%a >nul 2>&1
    )
)
echo [2/3] Checking dependencies and firewall...
pip install -r requirements.txt
netsh advfirewall firewall add rule name="PC Speaker WebSocket" dir=in action=allow protocol=TCP localport=8080 >nul 2>&1
netsh advfirewall firewall add rule name="PC Speaker Discovery" dir=in action=allow protocol=UDP localport=8888 >nul 2>&1
echo [3/3] Starting WASAPI audio loopback stream...
python pc_sender.py
pause
