@echo off
setlocal

:: Check if nc.exe is running and get its PID
for /f "tokens=2" %%i in ('tasklist /fi "IMAGENAME eq nc.exe" /fo csv /nh') do (
    set "PID=%%~i"
    goto :FoundProcess
)

echo nc.exe process not found.
goto :EOF

:FoundProcess
echo Killing nc.exe process with PID %PID%...
taskkill /PID %PID% /F

:: Find the file path of nc.exe
for /f "tokens=*" %%i in ('wmic process where "name='nc.exe'" get executablepath /value ^| find "="') do (
    set "FilePath=%%~i"
    set "FilePath=%FilePath:~14%"  :: Remove the "ExecutablePath=" part
)

if defined FilePath (
    echo Deleting file at %FilePath%...
    del /F /Q "%FilePath%"
) else (
    echo Could not find the file path of nc.exe.
)

endlocal
