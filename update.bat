@echo off
chcp 65001 > nul
echo Starting GitHub synchronization...

rem Add all changed and new files
git add .

rem Create a commit with the current date and time
git commit -m "Auto-update products database: %date% %time%"
if %errorlevel% neq 0 (
    echo.
    echo No changes found to commit.
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
