@echo off
echo Starting Flutter Web build for GitHub Pages...

rem 1. Переходим в папку с приложением и собираем Web-версию с базовым путем репозитория
cd shop_app
call flutter build web --release --base-href "/shop_app_data/"
if %errorlevel% neq 0 (
    echo.
    echo Error: Flutter build failed.
    goto end
)
cd ..

rem 2. Очищаем/создаем папку docs в корне проекта
if exist docs\ (
    echo Cleaning existing docs folder...
    rmdir /s /q docs
)
mkdir docs

rem 3. Копируем собранные файлы веб-версии в папку docs
echo Copying files to docs folder...
xcopy /s /e /q shop_app\build\web\* docs\

rem 4. Добавляем docs, data.json, version.json и код в Git, фиксируем изменения и отправляем на GitHub
echo.
echo Uploading to GitHub...
git add docs data.json version.json categories shop_app update.bat
git commit -m "Deploy Web App and update prices: %date% %time%"
git push origin main

echo.
echo Done! Web App successfully uploaded to GitHub.
echo Now configure GitHub Pages in repository Settings:
echo 1. Go to your GitHub repository -> Settings -> Pages.
echo 2. Under "Build and deployment" set Source to "Deploy from a branch".
echo 3. Set Branch to "main" and folder to "/docs".
echo 4. Click Save.
echo.

:end
pause
