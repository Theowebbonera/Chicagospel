@echo off
rem Kor alla tester headless.
set G="C:\Users\Theo\Godot\Godot_v4.7.2-stable_win64_console.exe"
cd /d "%~dp0"
for %%t in (test_regler test_figurer test_online test_online_scen) do (
  echo === %%t
  %G% --headless --path . --script res://tests/%%t.gd
)
pause
