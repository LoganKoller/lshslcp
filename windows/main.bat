@echo off
setlocal enabledelayedexpansion
net session

echo Checking for admin rights...

if %errorlevel%==0 (
	echo OK
) else (
    echo Failed, please restart with admin rights.
	pause
    exit
)

goto :menu

:menu
    echo.
    echo "      #########################################      "
    echo "      ##                                     ##      "
    echo "      ##        LSHS WINDOWS SCRIPT          ##      "
    echo "      ##                                     ##      "
    echo "      #########################################      "
    echo "      ##    Logan Koller & Ryan Slay         ##      "
    echo "      #########################################      "
    echo.
    echo "1)  Backup                       2)  Revert to Backup"
    echo "3)  Create User                  4)  Disable User"
    echo "5)  Change All Passwords         6)  Create Group"
    echo "7)  Add Users to Group           8)  Remove Group"
    echo "9)  Remove Users from Group     10)  Install Secure Group Policy"
    echo "11) Enable Firewall             12) Enable Automatic Updates"
    echo "13) Enable & Secure UAC         "
    echo.
    echo "auto) Applies Security Fixes Automatically"
    echo "exit) Exits                     reboot) Reboots"
    echo.
    set /p answer=Please choose an option: 
        if "%answer%"=="1" call :backup
        if "%answer%"=="2" call :revertToBackup
        if "%answer%"=="3" call :createUser
        if "%answer%"=="4" call :disableUser
        if "%answer%"=="5" call :changeAllPasswords
        if "%answer%"=="6" call :newGroup
        if "%answer%"=="7" call :addUsrsGroup
        if "%answer%"=="8" call :removeGroup
        if "%answer%"=="9" call :removeUsrsGroup
        if "%answer%"=="10" call :installSecureGroupPolicy
        if "%answer%"=="11" call :enableFirewall
        if "%answer%"=="12" call :automaticUpdates
        if "%answer%"=="13" call :secureUAC
        if "%answer%"=="auto" call :autoMode
        if "%answer%"=="exit" exit
        if "%answer%"=="reboot" shutdown /r
    goto :menu


:autoMode
    call :backup
    call :secureUAC
    call :automaticUpdates
    call :enableFirewall
    call :installSecureGroupPolicy
    call :changeAllPasswords

    exit /b

:secureUAC
    echo "Enabling & Securing UAC"

    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 1 /f
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 1 /f
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v PromptOnSecureDesktop /t REG_DWORD /d 1 /f

    echo Done.
    exit /b

:automaticUpdates
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 0 /f
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 4 /f
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v WUServer /t REG_SZ /d "" /f
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v WUStatusServer /t REG_SZ /d "" /f
    echo Automatic updates have been enabled.

    exit /b

:enableFirewall
	netsh advfirewall set allprofiles state on
	netsh advfirewall reset
	
    if %errorlevel% neq 0 (
        echo Failed to enable firewall!
    ) else (
        echo Firewall enabled!
    )

	exit /b

:addUsrsGroup
    net users

    set /p "groupName=Enter the name of the group to add users to: "
    set /p "users=Enter the users to add to the group (separate by space): "

    for %%u in (%users%) do (
        echo Adding user %%u to group "%groupName%"...
        net localgroup "%groupName%" %%u /add
        if %errorlevel% neq 0 (
            echo Failed to add user %%u to group "%groupName%"!
        ) else (
            echo User %%u added successfully.
        )
    )

    echo Process completed.

    exit /b

:removeUsrsGroup
    net users

    set /p "groupName=Enter the name of the group to remove users from: "
    set /p "users=Enter the users to add to the group (separate by space): "

    for %%u in (%users%) do (
        echo Adding user %%u to group "%groupName%"...
        net localgroup "%groupName%" %%u /delete
        if %errorlevel% neq 0 (
            echo Failed to remove user %%u from group "%groupName%"!
        ) else (
            echo User %%u removed successfully.
        )
    )

    echo Process completed.

    exit /b

:removeGroup
    set /p "groupName=Enter the name of the group to remove: "

    net localgroup "%groupName%" /remove
    if %errorlevel% neq 0 (
        echo Failed to remove group "%groupName%"!
        pause
        exit /b
    )

    exit /b

:newGroup
    setlocal enabledelayedexpansion

    net users

    set /p "groupName=Enter the name of the group to create: "
    set /p "users=Enter the users to add to the group (separate by space): "

    net localgroup "%groupName%" /add
    if %errorlevel% neq 0 (
        echo Failed to create group "%groupName%"!
        pause
        exit /b
    )

    echo Group "%groupName%" created successfully.

    for %%u in (%users%) do (
        echo Adding user %%u to group "%groupName%"...
        net localgroup "%groupName%" %%u /add
        if %errorlevel% neq 0 (
            echo Failed to add user %%u to group "%groupName%"!
        ) else (
            echo User %%u added successfully.
        )
    )

    echo Process completed.

    exit /b

:changeAllPasswords
    setlocal enabledelayedexpansion

    :: Prompt for the new password
    set /p "newpassword=Enter the new password for all users: "

    :: Default excluded users (Administrator and Guest)
    set "excludedUsers=Administrator Guest DefaultAccount"

    :: Ask for additional users to exclude
    set /p "additionalExcluded=Enter any additional users to exclude (separate by space, or leave blank for none): "

    :: Combine default excluded users with the additional ones entered
    if not "%additionalExcluded%"=="" set "excludedUsers=%excludedUsers% %additionalExcluded%"

    :: Get all users on the system
    for /f "skip=1 tokens=1" %%u in ('wmic useraccount get name') do (
        if not "%%u"=="" (
            set "excludeFlag=0"
            
            :: Check if the user is in the exclusion list
            for %%e in (%excludedUsers%) do (
                if /i "%%u"=="%%e" set "excludeFlag=1"
            )
            
            :: If the user is not excluded, change their password
            if !excludeFlag!==0 (
                echo Changing password for user %%u...
                net user %%u %newpassword%
            )
        )
    )

    echo Password change process completed.

    exit /b

:createUser
	set /p answer=Would you like to create a user?[y/n]: 
	if /I "%answer%"=="y" (
		set /p NAME=What is the user you would like to create?:
		net user !NAME! /add
		echo !NAME! has been added
		pause 
		goto :createUser
	) 
	if /I "%answer%"=="n" (
		exit /b
	)

:disableUser
	cls
	net users
	set /p answer=Would you like to disable a user?[y/n]: 
	if /I "%answer%"=="y" (
		cls
		net users
		set /p DISABLE=What is the name of the user?:
			net user !DISABLE! /active:no
		echo !DISABLE! has been disabled
		pause
		goto :disableUser
	)
	
	pause
	exit /b

:installSecureGroupPolicy
    set "importPath=%~dp0Resources\"
    set "infPath=%importPath%group_policy_config.inf"
    call :installPolicyConfig
    exit /b

    REM BELOW SHOULD BE DEFINED IF WINDOWS SERVER GROUP POLICY ~= WINDOWS CLIENT GROUP POLICY (NOT SURE YET)
    REM for /f "tokens=2 delims==" %%a in ('wmic os get producttype /value') do (
    REM    set "productType=%%a"
    REM )
    REM if %productType%==1 (
        REM Regular Windows Client edition
    REM 
    REM ) else (
        REM Windows Server edition

    REM )

:installPolicyConfig
    REM set "importPath=%~dp0"
    REM set "infPath=%importPath%secedit_export.inf"
    set "logPath=%importPath%import_log.txt"

    REM Check if the security settings file exists
    if not exist "%infPath%" (
        echo Error: Security settings file %infPath% not found.
        exit /b 1
    )

    REM Import the security settings
    secedit /configure /db secedit.sdb /cfg "%infPath%" /log "%logPath%" /verbose

    echo Security settings imported from %infPath%.

:revertToBackup
    set "importPath=%~dp0Backup"
    set "infPath=%importPath%secedit_export.inf"
    call :installPolicyConfig
    exit /b

:backupCurrentPolicy
    set "exportPath=%~dp0Backup"
    set "dbPath=%exportPath%\secedit.sdb"
    set "infPath=%exportPath%\secedit_export.inf"
    if not exist "%exportPath%" mkdir "%exportPath%"
    secedit /export /cfg "%infPath%" /log "%exportPath%\export_log.txt" /verbose

    echo Security settings exported to %infPath%.

    exit /b

:backup
    mkdir Backup
    call :backupCurrentPolicy
    echo Backup complete!
    exit /b