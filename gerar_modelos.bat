@echo off
rem Gera de novo todos os modelos .glb no Blender e reimporta no Godot.
rem Uso: gerar_modelos.bat            (todos)
rem      gerar_modelos.bat hum_tank   (só os que contêm o filtro no nome)
cd /d "%~dp0"
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b --factory-startup --python art_src\blender\make_models.py -- models %1
if errorlevel 1 exit /b 1
"H:\Jogos\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import
echo Modelos prontos.
