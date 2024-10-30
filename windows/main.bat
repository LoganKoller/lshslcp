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

:: TODO
:: GO THROUGH ALL ADMINISTRATIVE TEMPLATES AND SECURE THEM
:: 
::
::

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
    echo "1)  Backup                                            2)  Revert to Backup"
    echo "3)  Create User                                       4)  Disable User"
    echo "5)  Change All Passwords                              6)  Create Group"
    echo "7)  Add Users to Group                                8)  Remove Group"
    echo "9)  Remove Users from Group                           10)  Install Secure Group Policy"
    echo "11) Enable Firewall                                   12)  Enable Automatic Updates"
    echo "13) Enable & Secure User Account Control(UAC)         14)  Manage Services"
    echo "15) Print user files                                  16)  List Shares"
    echo "17) Disable share                                     18)  Configure Remote Desktop"
    echo "19) Automatic User Management                         20)  "
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
        if "%answer%"=="14" call :disableServices
        if "%answer%"=="15" call :listUserFiles
        if "%answer%"=="16" call :listShares
        if "%answer%"=="17" call :disableShare
        if "%answer%"=="18" call :toggleRemoteDesktop
        if "%answer%"=="19" call :automaticUserManagement
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
    call :toggleRemoteDesktop
    call :disableServices
    call :automaticUserManagement

    exit /b

:listUserFiles
    tree "C:\Users" /f
    exit /b

:listShares
    net share
    exit /b

:disableShare
    call :listShares
    set /p targetShare=Target Share: 

    echo Disabling share: %share_name%
    net share %share_name% /delete
    if %ERRORLEVEL%==0 (
        echo Share %share_name% has been successfully disabled.
    ) else (
        echo Failed to disable the share %share_name%. Please check the share name.
    )

    exit /b

:toggleRemoteDesktop
    set /p needsRDP=Is Remote Desktop required?[y/n]: 
	if /I "%needsRDP%"=="y" (
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Remote Assistance" /v fAllowToGetHelp /t REG_DWORD /d 1 /f
    ) else (
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 1 /f
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Remote Assistance" /v fAllowToGetHelp /t REG_DWORD /d 0 /f
    )

    exit /b

:automaticUserManagement
    set /p usersConfigured=Are users configured in the text files?[y/n]: 
	if /I "%usersConfigured%"=="n" (
        exit /b
    )

    setlocal enabledelayedexpansion
    set "batchDir=%~dp0"
    REM Read you.txt and set to variable
    set "you="
    for /f "delims=" %%A in (%batchDir%you.txt) do set "you=%%A"

    REM Read authadmins.txt and store as a list
    set "authadmins="
    for /f "delims=" %%A in (%batchDir%authorizedAdmins.txt) do (
        set "authadmins=!authadmins! %%A"
    )

    REM Read authusers.txt and store as a list
    set "authusers="
    for /f "delims=" %%A in (%batchDir%authorizedUsers.txt) do (
        set "authusers=!authusers! %%A"
    )

    REM Print out the variables
    echo You: %you%
    echo Authorized Admins: %authadmins%
    echo Authorized Users: %authusers%

    REM Loop through authadmins (split by space due to concatenation)
    echo Looping through Authorized admins:
    for %%A in (%authadmins%) do (
        echo Admin: %%A
    )

    REM Loop through authusers (split by space due to concatenation)
    echo Looping through Authorized users:
    for %%A in (%authusers%) do (
        echo User: %%A
    )

    set /p isCorrect=Does this look correct?[y/n]: 
	if /I "%isCorrect%"=="y" (
		set "validUsers=%you% %authadmins% %authusers% Administrator Guest DefaultAccount"
        set "newpassword=Lakeside24$"
        
        REM Get all valid local users using WMIC
        for /f "tokens=2 delims==" %%B in ('wmic useraccount where "LocalAccount='TRUE' and Disabled='FALSE'" get Name /value') do (
            set "username=%%B"
            REM Trim any leading/trailing spaces
            set "username=!username:~0,-1!"
            set "username=!username: =!"

            if not "!username!"=="" (
                REM Check if the username is NOT in validUsers
                set "found=0"
                for %%C in (!validUsers!) do (
                    if /i "%%C"=="!username!" (
                        set "found=1"

                        if not "!username!"=="%you%" (
                            wmic UserAccount where "Name='!username!'" set PasswordExpires=true

                            echo Changing password for user %%C...
                            net user "!username!" "!newpassword!"

                            set "found2=0"

                            for %%D in (!authadmins!) do (
                                if /i "%%D"=="!username!" (
                                    set "found2=1" 
                                )
                            )

                            if !found2! equ 0 (
                                net localgroup "Administrators" "!username!" /delete
                            ) else (
                                net localgroup "Administrators" "!username!" /add
                            )
                        )
                    )
                )

                REM If not found, delete the user account
                if !found! equ 0 (
                    echo Deleting user account: !username!
                    net user "!username!" /delete
                )
            )
        )
	)

    exit /b


:disableServices
    set /p ftpEnabled=Is FTP Required(y/n): 
    set /p telnetEnabled=Is Telnet Required(y/n): 
    set /p sshEnabled=Is SSH Required(y/n): 
    set /p rdpEnabled=Is Remote Desktop Required(y/n): 
    set /p IISEnabled=Is IIS Required(y/n):
    set /p lanmanEnabled=Is lanman/Simple File Sharing Required(y/n): 

    :: Stop and disable Windows Update
    sc stop "wuauserv"
    sc config "wuauserv" start= disabled

    :: Stop and disable Background Intelligent Transfer Service (BITS)
    sc stop "bits"
    sc config "bits" start= disabled

    if "%ftpEnabled%"=="n" (
        :: Stop and disable FTP service (if not needed)
        sc stop "ftpsvc"
        sc config "ftpsvc" start= disabled
    )

    if "%telnetEnabled%"=="n" (
        :: Stop and disable Telnet (if not needed)
        sc stop "TlntSvr"
        sc config "TlntSvr" start= disabled
    )

    if "%sshEnabled%"=="n" (
        :: Stop and disable Microsoft OpenSSH Server (if not needed)
        sc stop "sshd"
        sc config "sshd" start= disabled

        :: Stop and disable SSH Agent (if not needed)
        sc stop "ssh-agent"
        sc config "ssh-agent" start= disabled
    )

    if "%IISEnabled%"=="n" (
        :: Stop and disable World Wide Web Publishing Service (if not needed)
        sc stop "W3SVC"
        sc config "W3SVC" start= disabled

    )

    if "%lanmanEnabled%"=="n" (
        : Stop and disable Simple File Sharing (if not needed)
        sc stop "lanmanserver"
        sc config "lanmanserver" start= disabled
    )

    :: Stop and disable Windows Remote Management (WinRM)
    sc stop "WinRM"
    sc config "WinRM" start= disabled

    :: Stop and disable Simple TCP/IP Services (includes services like ECHO, DISCARD)
    sc stop "simptcp"
    sc config "simptcp" start= disabled

    if "%rdpEnabled%"=="n" (
        :: Stop and disable Remote Desktop Services (if not needed)
        sc stop "TermService"
        sc config "TermService" start= disabled

        :: Stop and disable Remote Desktop Configuration (if not needed)
        sc stop "SessionEnv"
        sc config "SessionEnv" start= disabled

        :: Stop and disable Remote Desktop UserMode Port Redirector (if not needed)
        sc stop "UmRdpService"
        sc config "UmRdpService" start= disabled

        :: Stop and disable Remote Desktop Licensing (if not needed)
        sc stop "TermServLicensing"
        sc config "TermServLicensing" start= disabled
    )

    :: Stop and disable Remote Registry (for security reasons)
    sc stop "RemoteRegistry"
    sc config "RemoteRegistry" start= disabled

    :: Stop and disable Print Spooler (if no printers are used)
    sc stop "Spooler"
    sc config "Spooler" start= disabled

    :: Stop and disable Telephony (if not needed)
    sc stop "TapiSrv"
    sc config "TapiSrv" start= disabled

    :: Stop and disable RIP Listener (if not needed)
    sc stop "Iprip"
    sc config "Iprip" start= disabled

    :: Stop and disable SNMP Trap (if not needed)
    sc stop "SNMPTRAP"
    sc config "SNMPTRAP" start= disabled

    :: Stop and disable SSDP Discovery Service (if not needed)
    sc stop "SSDPSRV"
    sc config "SSDPSRV" start= disabled

    :: Stop and disable SMTP (if not needed)
    sc stop "smtpsvc"
    sc config "smtpsvc" start= disabled


:secureUAC
    echo "Enabling & Securing UAC"

    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 1 /f
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 1 /f
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v PromptOnSecureDesktop /t REG_DWORD /d 1 /f

    echo Done.
    exit /b

:automaticUpdates
    :: First Iteration
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 0 /f
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 4 /f
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v WUServer /t REG_SZ /d "" /f
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v WUStatusServer /t REG_SZ /d "" /f
    
    :: Second Iteration
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 4 /f
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v ScheduledInstallDay /t REG_DWORD /d 0 /f
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v ScheduledInstallTime /t REG_DWORD /d 3 /f

    :: Force group policy to refresh
    gpupdate /force
    
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

    netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound
    echo Disabled inbound connections!

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
    echo "PLEASE NOTE THAT SECURE GROUP POLICY MAY NOT COVER EVERYTHING IN USER RIGHTS ASSIGNMENT AND SECURITY OPTIONS"
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