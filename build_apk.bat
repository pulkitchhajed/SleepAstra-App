@echo off
echo Starting flutter build...
SET PATH=%PATH%;C:\Program Files\Flutter\bin
cd /d c:\flutter
flutter build apk --suppress-analytics > c:\flutter\build_out.log 2>&1
echo Exit code: %ERRORLEVEL% >> c:\flutter\build_out.log
echo BUILD DONE
