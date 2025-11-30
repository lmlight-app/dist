@echo off
cd /d "%LOCALAPPDATA%\lmlight"

:: Load .env
for /f "tokens=*" %%a in (.env) do set %%a

:: Check Node
where node >nul 2>&1 || (echo Node.js not found & exit /b 1)

:: Kill existing
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8000') do taskkill /PID %%a /F >nul 2>&1
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :3000') do taskkill /PID %%a /F >nul 2>&1

if not exist logs mkdir logs

:: Start API
start /b "" bin\lmlight-api.exe > logs\api.log 2>&1

:: Start Web
cd frontend
start /b "" node server.js > ..\logs\web.log 2>&1

echo Started: http://localhost:3000
