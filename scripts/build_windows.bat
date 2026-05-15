@echo off
REM DABPlayer Windows Build Script
REM Ensure you have Visual Studio with C++ desktop development installed.

echo Building DABPlayer for Windows...
call flutter build windows
echo Build complete. Output found in build\windows\x64\runner\Release\
pause
