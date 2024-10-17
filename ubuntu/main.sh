#!/bin/bash

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

# TODO
#   

# Color Codes:
#   Reset: 0
#   Black: 30
#   Red: 31
#   Green: 32
#   Yellow: 33
#   Blue: 34
#   Magenta: 35
#   Cyan: 36
#   White: 37
coloredOutput() { # (args: [output: string, colorCode: string])
    output=$1
    color=$2"m"

    printf "\x1B[$color$output\x1B[0m"
}

backupFile() { # (args: [dir: string])
    dir=$1
    fileName=$2

    coloredOutput "Creating backup for $dir (copying to ./Backups/$fileName) " "0"
    cp $dir ./Backups

    if [ ./Backups/$fileName ]; then
        coloredOutput "[PASS]\n" "32"
    else
        coloredOutput "[FAIL]\n" "31"
    fi
}

manageBackups() { # Check if backups are made, if not make backups
    coloredOutput "Checking Backups...\n" "33"

    if [ -d "./Backups" ]; then
        coloredOutput "Backups already exist!\n" "32"
    else # Backups does not exist
        coloredOutput "Creating backups...\n" "0"

        mkdir ./Backups

        backupFile "/etc/sudoers" "sudoers"
        backupFile "/etc/group" "group"
        backupFile "/etc/passwd" "passwd"
        backupFile "/etc/apt/sources.list" "sources.list"

        cp -r /var/log ./Backups

        if [[ $OSTYPE == 'darwin'* ]]; then # Make sure we are not on macOS
            coloredOutput "Skipping default linux user backups...\n" "0"
        else
            backupFile "/etc/shadow" "shadow"

            for x in `ls /home`
            do
                coloredOutput "Creating backup for $x (copying to ./Backups/$x) " "0"
                cp -r /home/$x ./Backups

                if [ -d ./Backups/$x ]; then
                    coloredOutput "[PASS]\n" "32"
                else
                    coloredOutput "[FAIL]\n" "31"
                fi
            done
        fi

        coloredOutput "Created Backups!\n" "32"
    fi
}

fixSources() {
    coloredOutput "Fixing Sources...\n" "33"

    coloredOutput "Fetching distro name..." "0"
    DISTRO=$(lsb_release -is)
    coloredOutput " [$DISTRO]\n" "33"

    coloredOutput "Fetching $DISTRO's code name" "0"
    CODENAME=$(lsb_release -cs)
    coloredOutput " [$CODENAME]\n" "33"
    
    coloredOutput "Fetching $DISTRO's default sources list" "0"
    DSPATH="$SCRIPT_DIR/resources/$DISTRO/sources.default"
    #if [ "$DISTRO" == "Ubuntu" ]; then
    #    URL="http://archive.ubuntu.com/ubuntu/dists/$CODENAME/main/example/sources.list"
    #elif [ "DISTRO" == "Debian" ]; then
    #    curl -o /tmp/sources.list.default $URL
    #else
    #    coloredOutput " [FAIL]\n" "31"
    #    coloredOutput "Unsupported distro : $DISTRO\n" "0"
    #    return "Unsupported distro"
    #fi
    coloredOutput " [PASS]\n" "32"

    coloredOutput "Replacing sources list..." "0"
    cp $DSPATH /etc/apt/sources.list

    if [ $? -eq 0 ]; then
        coloredOutput " [PASS]\n" "32"

        apt-get update -y
    else
        coloredOutput " [FAIL]\n" "31"
    fi
}

setupFirewall() {
    coloredOutput "Installing UFW" "0"
    #coloredOutput " [FAIL]\n" "31" # Check later on how to see if its succesfully installed
    apt-get install -y ufw

    coloredOutput " [PASS]\n" "32"

    coloredOutput "Configuring UFW" "0"

    ufw default deny incoming
    ufw default allow outgoing
    ufw logging on
    ufw logging high
    ufw enable

    coloredOutput " [PASS]\n" "32"
}

configureSSH() {
    coloredOutput "Installing SSH" "0"
    #coloredOutput " [FAIL]\n" "31" # Check later on how to see if its succesfully installed
    apt-get install -y openssh-server
    systemctl start sshd

    coloredOutput " [PASS]\n" "32"

    coloredOutput "Configuring SSH" "0"

    sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config

    coloredOutput " [PASS]\n" "32"
}

configureLoginSettings() {
    coloredOutput "Configuring Login Settings" "0"

    sudo sed -i 's/pam_unix\.so/pam_unix.so minlen=8 remember=5/g' /etc/pam.d/common-password
    sudo sed -i 's/nullok//g' /etc/pam.d/common-auth
    #sudo sed -i 's/password[[:space:]]\+requisite[[:space:]]\+pam_cracklib.so retry=3 minlen=8 difok=3/password        requisite                       pam_cracklib.so retry=3 minlen=8 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1/g' /etc/pam.d/common-password
    
    sed -i 's/PASS_MAX_DAYS\t99999/PASS_MAX_DAYS\t90/g' /etc/login.defs
    sed -i 's/PASS_MIN_DAYS\t0/PASS_MIN_DAYS\t7/g' /etc/login.defs
    sed -i 's/PASS_WARN_AGE\t7/PASS_WARN_AGE\t14/g' /etc/login.defs

    coloredOutput " [PASS]\n" "32"
}

configureUpdates() {
    DISTRO=$(lsb_release -is)

    if [[ " ${DISTRO} " == " Ubuntu " ]]; then
        sudo apt-get install -y unattended-upgrades
        sudo dpkg-reconfigure --priority=low unattended-upgrades
        
        # Edit the configuration file for unattended upgrades
        sudo bash -c 'cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";'

        # Ensure the update frequency is set to daily
        sudo bash -c 'cat > /etc/apt/apt.conf.d/10periodic << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";'

        sudo dpkg-reconfigure unattended-upgrades
    fi
}

getExcludedUsers() {
    coloredOutput "Enter usernames to exclude(space-separated):" "0"
    read -p " " EXCLUDE_USERS_INPUT
    IFS=' ' read -r -a EXCLUDE_USERS <<< "$EXCLUDE_USERS_INPUT"
    coloredOutput "\n" "0"
}

getIncludedUsers() {
    coloredOutput "Enter usernames to include(space-separated):" "0"
    read -p " " INCLUDE_USERS_INPUT
    IFS=' ' read -r -a INCLUDE_USERS <<< "$INCLUDE_USERS_INPUT"
    coloredOutput "\n" "0"
}

getNewPassword() {
    coloredOutput "Enter new password:" "0"
    read -e NEW_PASSWORD
    coloredOutput "\nConfirm new password:" "0"
    read -e CONFIRM_PASSWORD

    coloredOutput "\n" "0"

    if [ "$NEW_PASSWORD" != "$CONFIRM_PASSWORD" ]; then
        coloredOutput "Passwords do not match, try again\n" "31"
        getNewPassword
    fi
}

setAllPasswords() {
    getExcludedUsers
    getNewPassword

    coloredOutput "" "0"

    ALL_USERS=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)

    for USER in $ALL_USERS; do
        if [[ ! " ${EXCLUDE_USERS[@]} " =~ " ${USER} " ]]; then
            echo "$USER:$NEW_PASSWORD" | chpasswd
            echo "Password for $USER has been changed."
        fi
    done
}

listUsers() {
    coloredOutput "Users for this system:\n" "0"
    awk -F: '$3 >= 1000 && $1 != "nobody" { print $1 }' /etc/passwd
}

addGroup() {
    coloredOutput "New Group Name:" "0"
    read -e NEW_GROUP

    getIncludedUsers

    sudo groupadd $NEW_GROUP

    for USER in "${INCLUDE_USERS[@]}"; do
        sudo usermod -a -G $NEW_GROUP $USER
        echo "Added $USER to $NEW_GROUP."
    done
}

removeGroup() {
    coloredOutput "Group to remove:" "0"
    read -e OLD_GROUP

    coloredOutput "\n" "0"

    sudo groupdel $OLD_GROUP
}

addUsrGroup() {
    coloredOutput "Group:" "0"
    read -e ADD_USR_GROUP_NAME
    coloredOutput "\nUser:" "0"
    read -e ADD_USR_USERNAME

    sudo usermod -a -G $ADD_USR_GROUP_NAME $ADD_USR_USERNAME
}

addUsrsGroup() {
    coloredOutput "Group:" "0"
    read -e ADD_USRR_GROUP_NAME

    getIncludedUsers

    for USER in "${INCLUDE_USERS[@]}"; do
        sudo usermod -a -G $ADD_USRR_GROUP_NAME $USER
        echo "Added $USER to $ADD_USRR_GROUP_NAME."
    done
}

removeUsrGroup() {
    coloredOutput "Group:" "0"
    read -e REMOVE_USR_GROUP_NAME
    coloredOutput "\nUser:" "0"
    read -e REMOVE_USR_USERNAME

    sudo gpasswd -d $REMOVE_USR_USERNAME $REMOVE_USR_GROUP_NAME
}

removeUsrsGroup() {
    coloredOutput "Group:" "0"
    read -e REMOVE_USRR_GROUP_NAME

    getIncludedUsers

    for USER in "${INCLUDE_USERS[@]}"; do
        sudo gpasswd -d $USER $REMOVE_USRR_GROUP_NAME
        echo "Removed $USER from $REMOVE_USRR_GROUP_NAME."
    done
}

listUsersInGroup() {
    coloredOutput "Group to check:" "0"
    read -e GROUP_TO_CHECK_USERS

    coloredOutput "\n" "0"

    GROUP_INFO_USRS=$(getent group "$GROUP_TO_CHECK_USERS")

    # Check if the group exists
    if [ -z "$GROUP_INFO_USRS" ]; then
        echo "Group '$GROUP_TO_CHECK_USERS' does not exist."
        exit 1
    fi

    users=$(echo "$GROUP_INFO_USRS" | awk -F: '{print $4}')

    # Check if the group has any users
    if [ -z "$users" ]; then
        echo "Group '$GROUP_TO_CHECK_USERS' has no users."
    else
        echo "Users in group '$GROUP_TO_CHECK_USERS':"
        echo "$users" | tr ',' '\n'
    fi
}

addUser() {
    coloredOutput "User to add:" "0"
    read -e NEW_USER

    coloredOutput "\n" "0"

    sudo adduser $NEW_USER

    coloredOutput "Added new user $NEW_ADMIN_USER.\n" "0"
}

removeUser() {
    coloredOutput "User to remove:" "0"
    read -e OLD_USER

    coloredOutput "\n" "0"

    sudo deluser $OLD_USER
}

listAdmins() {
    coloredOutput "Admins for this system:\n" "0"
    getent group sudo | awk -F: '{print$4}'
}

addAdmin() {
    coloredOutput "User to give admin to:" "0"
    read -e NEW_ADMIN_USER

    coloredOutput "\n" "0"

    usermod -aG sudo $NEW_ADMIN_USER

    coloredOutput "Gave user $NEW_ADMIN_USER sudo permissions.\n" "0"
}

removeAdmin() {
    coloredOutput "User to remove admin from:" "0"
    read -e OLD_ADMIN_USER

    coloredOutput "\n" "0"

    gpasswd -d $OLD_ADMIN_USER sudo
}

listAllMediaFilesInHome() {
    sudo find /home -type d \( -path '*/.config' -o -path '*/.cache' \) -prune -o -type f \( -name '*.mp3' -o -name '*.mp4' -o -name '*.mov' -o -name "*.ogg" -o -name "*.avi" -o -name "*.mpg" -o -name "*.mpeg" -o -name "*.flv" -o -name "*.m4a" -o -name "*.gif" -o -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) -print
}

listAllUnownedFiles() {
    find / -nouser
}

removeFilesDir() {
    coloredOutput "Path:" "0"
    read -e RFDPATH

    coloredOutput "\nAre you sure you want to delete all contents of $RFDPATH? (y/n): " "0"
    read -e CONFIRM_RFDPATH

    if [[ " ${CONFIRM_RFDPATH} " == " y " ]]; then
        rm -r $RFDPATH
    fi
}

updateApplications() {
    apt-get update -y
    apt-get upgrade -y
}

setupFilePermissions() {
    chmod -R 444 /var/log
    chmod 440 /etc/passwd
    chmod 440 /etc/shadow
    chmod 440 /etc/group
    chmod -R 444 /etc/ssh
}

manageRequiredSoftware() {
    echo "Is Telnet required? (y/n):"
    read -e TELNETR
    echo "Is SSH required? (y/n):"
    read -e SSHR
    echo "Is FTP required? (y/n):"
    read -e FTPR
    echo "Is Dovecot(mailing server) required? (y/n):"
    read -e DCR
    echo "Is Courier-pop(mailing server) required? (y/n):"
    read -e CPR

    if [[ " ${TELNETR} " == " n " ]]; then
        apt-get purge -y telnet
    fi

    if [[ " ${SSHR} " == " n " ]]; then
        apt-get purge -y openssh-server
        apt-get purge -y openssh-client
    fi

    if [[ " ${FTPR} " == " n " ]]; then
        apt-get remove -y pure-ftpd
    fi

    if [[ " ${DCR} " == " n " ]]; then
        systemctl stop dovecot
        apt-get purge -y dovecot-*
    fi

    if [[ " ${CPR} " == " n " ]]; then
        systemctl stop courier-pop
        apt-get purge -y courier-pop
    fi

    apt-get autoclean -y
}

automatedList() {
    exec > >(tee -a /var/log/lshs_auto.log) 2>&1

    manageBackups
    fixSources
    setupFirewall
    setupFilePermissions
    configureSSH
    configureLoginSettings
    
    exec > /dev/tty 2>&1
    configureUpdates
    exec > >(tee -a /var/log/lshs_auto.log) 2>&1

    manageRequiredSoftware

    updateApplications
    
    exec > /dev/tty 2>&1

    coloredOutput "\nSaved log under /var/log/lshs_auto.log\n" "32"
}

runList() {
    coloredOutput "##################################\n" "34"
    coloredOutput "##                              ##\n" "34"
    coloredOutput "##       " "34"
    coloredOutput "LSHS LINUX SCRIPT" "33"
    coloredOutput "      ##\n" "34"
    coloredOutput "##                              ##\n" "34"
    coloredOutput "##################################\n" "34"
    coloredOutput "##          " "34"
    coloredOutput "Logan Koller" "32"
    coloredOutput "        ##\n" "34"
    coloredOutput "##################################\n" "34"

    coloredOutput "1)  Backup                        2) Fix Sources\n" "0"
    coloredOutput "3)  Setup Firewall                4) Set All Passwords\n" "0"
    coloredOutput "5)  List Admins                   6) Add Admin\n" "0"
    coloredOutput "7)  Remove Admin                  8) List All Users\n" "0"
    coloredOutput "9)  Add User                      10) Remove User\n" "0"
    coloredOutput "11) Add Group                     12) Remove Group\n" "0"
    coloredOutput "13) Add User to Group             14) Remove User from Group\n" "0"
    coloredOutput "15) Add Users to Group            16) Remove Users from Group\n" "0"
    coloredOutput "17) Display all Users in Group    18) Configure SSH\n" "0"
    coloredOutput "19) Configure Login Settings      20) Update Applications\n" "0"
    coloredOutput "21) Configure Updates             22) Manage required software\n" "0"
    coloredOutput "23) List all media files in home  24) List all unowned files\n" "0"
    coloredOutput "25) Remove all files/directory in 26) ---\n" "0"
    
    coloredOutput "auto" "33" 
    coloredOutput ") " "0" 
    coloredOutput "Auto mode\n" "33"
    
    echo "Choose:"
    read -e USRINPOPTION

    if [ "${USRINPOPTION}" == "1" ]; then
	manageBackups
    elif [ "${USRINPOPTION}" == "2" ]; then
        fixSources
    elif [ "${USRINPOPTION}" == "3" ]; then
        setupFirewall
    elif [ "${USRINPOPTION}" == "4" ]; then
        setAllPasswords
    elif [ "${USRINPOPTION}" == "5" ]; then
        listAdmins
    elif [ "${USRINPOPTION}" == "6" ]; then
        addAdmin
    elif [ "${USRINPOPTION}" == "7" ]; then
        removeAdmin
    elif [ "${USRINPOPTION}" == "8" ]; then
        listUsers
    elif [ "${USRINPOPTION}" == "9" ]; then
        addUser
    elif [ "${USRINPOPTION}" == "10" ]; then
        removeUser
    elif [ "${USRINPOPTION}" == "11" ]; then
        addGroup
    elif [ "${USRINPOPTION}" == "12" ]; then
        removeGroup
    elif [ "${USRINPOPTION}" == "13" ]; then
        addUsrGroup
    elif [ "${USRINPOPTION}" == "14" ]; then
        removeUsrGroup
    elif [ "${USRINPOPTION}" == "15" ]; then
        addUsrsGroup
    elif [ "${USRINPOPTION}" == "16" ]; then
        removeUsrsGroup
    elif [ "${USRINPOPTION}" == "17" ]; then
        listUsersInGroup
    elif [ "${USRINPOPTION}" == "18" ]; then
        configureSSH
    elif [ "${USRINPOPTION}" == "19" ]; then
        configureLoginSettings
    elif [ "${USRINPOPTION}" == "20" ]; then
        updateApplications
    elif [ "${USRINPOPTION}" == "21" ]; then
        configureUpdates
    elif [ "${USRINPOPTION}" == "22" ]; then
        manageRequiredSoftware
    elif [ "${USRINPOPTION}" == "23" ]; then
        listAllMediaFilesInHome
    elif [ "${USRINPOPTION}" == "24" ]; then
        listAllUnownedFiles
    elif [ "${USRINPOPTION}" == "25" ]; then
        removeFilesDir
    elif [ "${USRINPOPTION}" == "auto" ]; then
        automatedList
    fi

    runList
}

runList