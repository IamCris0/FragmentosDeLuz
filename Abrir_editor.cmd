@echo off
setlocal
set "GODOT_EXE=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
  echo No se encontro Godot en su ubicacion original.
  echo Abre Godot e importa el archivo godot\project.godot de esta carpeta.
  pause
  exit /b 1
)
start "Fragmentos de Luz - Editor" "%GODOT_EXE%" --editor --path "%~dp0godot"
