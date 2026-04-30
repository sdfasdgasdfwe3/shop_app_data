@echo off
echo Starting GitHub synchronization...

rem Add all changed and new files
git add .gitignore
git add data.json
git add version.json
git add update.bat
if exist images\ git add images\
if exist shop_app\ git add shop_app\

rem Remove admin.html from GitHub if it was pushed before
git rm --cached admin.html >nul 2>&1

rem Create a commit with the current date and time
git commit -m "Auto-update database and code: %date% %time%"
if %errorlevel% neq 0 (
    echo.
    echo No new changes found to commit. Checking for pending commits to push...
)

rem Pull latest changes from GitHub to avoid conflicts
git pull origin main --rebase
if %errorlevel% neq 0 (
    echo.
    echo Error: Failed to pull data from GitHub. Please resolve conflicts manually.
    goto end
)

rem Push files to GitHub
git push origin main
if %errorlevel% neq 0 (
    echo.
    echo Error: Failed to push data to GitHub. Check your internet connection or resolve conflicts.
    goto end
)

echo.
echo Done! Data successfully updated on GitHub.

:end
pause
