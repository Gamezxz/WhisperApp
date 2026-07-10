@echo off
rem Build (if needed) and launch WhisperApp
if not exist "%~dp0WhisperApp.exe" (
  call "%~dp0build.bat"
  if errorlevel 1 exit /b 1
)
start "" "%~dp0WhisperApp.exe"
