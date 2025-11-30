' LM Light Launcher (Hidden Console)
' Run PowerShell script without showing window

Set shell = CreateObject("WScript.Shell")
shell.Run "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%LOCALAPPDATA%\lmlight\LMLight.ps1""", 0, False
