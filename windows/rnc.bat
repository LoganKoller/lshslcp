@echo off
setlocal

:: Search for the process "nc.exe" and capture its PID and path
for /f "tokens=2 delims==;" %%A in ('wmic process where "name='nc.exe'" get processid /format:value 2^>nul') do set pid=%%A
for /f "tokens=2 delims==;" %%A in ('wmic process where "name='nc.exe'" get executablepath /format:value 2^>nul') do set exePath=%%A

:: Check if the process was found
if defined pid (
    echo Found nc.exe with PID: %pid%
    echo Executable path: %exePath%
    
    :: End the process
    taskkill /PID %pid% /F
    echo Process nc.exe terminated.
    
    :: Take ownership of the file
    takeown /f "%exePath%" /a
    :: Grant full control permissions
    icacls "%exePath%" /grant %username%:F

    :: Delete the executable file
    if exist "%exePath%" (
        del "%exePath%"
        echo File deleted: %exePath%
    ) else (
        echo File not found: %exePath%
    )
) else (
    echo Process nc.exe not found.
)

endlocal
