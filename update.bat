@echo off
chcp 65001 > nul
echo Starting GitHub synchronization...

rem Add all changed and new files
git add .

rem Create a commit with the current date and time
git commit -m "Auto-update products database: %date% %time%"

rem Push files to GitHub
git push origin main

echo.
echo Done! Data successfully updated on GitHub.
pause
