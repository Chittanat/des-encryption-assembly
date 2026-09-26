@echo off
echo Assembling files...
ml /c /coff /I"C:\Irvine" main.asm keygen.asm des_core.asm utils.asm
if errorlevel 1 goto end

echo Linking files...
link /SUBSYSTEM:CONSOLE /MACHINE:X86 /LIBPATH:"C:\Irvine" main.obj keygen.obj des_core.obj utils.obj irvine32.lib kernel32.lib user32.lib
if errorlevel 1 goto end

echo Build Success! Running Shell...
echo ===================================
main.exe
echo ===================================
:end