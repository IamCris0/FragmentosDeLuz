@echo off
setlocal
set "GODOT_EXE=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
  echo No se encontro Godot en su ubicacion original.
  echo Abre Godot e importa el archivo godot\project.godot de esta carpeta.
  pause
  exit /b 1
)
echo Preparando los modelos, sonidos y texturas del juego...
"%GODOT_EXE%" --headless --editor --path "%~dp0godot" --import --quit --log-file "%~dp0importacion.log"
if errorlevel 1 (
  echo No se pudo preparar el juego. Revisa importacion.log.
  pause
  exit /b 1
)
findstr /C:"SCRIPT ERROR:" /C:"Failed loading resource" "%~dp0importacion.log" >nul
if not errorlevel 1 (
  echo Hay un error en los recursos. Revisa importacion.log.
  pause
  exit /b 1
)
start "Fragmentos de Luz" "%GODOT_EXE%" --path "%~dp0godot" --log-file "%~dp0juego.log" -- %*
