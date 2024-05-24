#!/bin/bash

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
    if [ "$DISTRO" == "Ubuntu" ]; then
        URL="http://archive.ubuntu.com/ubuntu/dists/$CODENAME/main/example/sources.list"
    elif [ "DISTRO" == "Debian" ]; then
        curl -o /tmp/sources.list.default $URL
    else
        coloredOutput " [FAIL]\n" "31"
        coloredOutput "Unsupported distro : $DISTRO\n" "0"
        return "Unsupported distro"
    fi
    coloredOutput " [PASS]\n" "32"

    coloredOutput "Replacing sources list..." "0"
    cp /tmp/sources.list.default /etc/apt/sources.list

    if [ $? -eq 0 ]; then
        coloredOutput " [PASS]\n" "32"
    else
        coloredOutput " [FAIL]\n" "31"
    fi
}

setupFirewall() {
    coloredOutput "Installing UFW" "0"
    #coloredOutput " [FAIL]\n" "31" # Check later on how to see if its succesfully installed
    apt-get install ufw

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
    apt-get install openssh-server
    systemctl start sshd

    coloredOutput " [PASS]\n" "32"

    coloredOutput "Configuring SSH" "0"

    sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config

    coloredOutput " [PASS]\n" "32"
}

getExcludedUsers() {
    coloredOutput "Enter usernames to exclude(space-separated):" "0"
    read -r -a EXCLUDE_USERS
    coloredOutput "\n" "0"
}

getNewPassword() {
    coloredOutput "Enter new password:" "0"
    read -s NEW_PASSWORD
    coloredOutput "\nConfirm new password:" "0"
    read -s CONFIRM_PASSWORD

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

    ALL_USERS=$(cut -d: -f1 /etc/passwd)

    for USER in $ALL_USERS; do
        if [[ ! " ${EXCLUDE_USERS[@]} " =~ " ${USER} " ]]; then
            echo "$USER:$NEW_PASSWORD" | chpasswd
            echo "Password for $USER has been changed."
        fi
    done
}

listAdmins() {
    coloredOutput "Admins for this system:\n" "0"
    getent group sudo | awk -F: '{print$4}'
}

addAdmin() {
    coloredOutput "User to give admin to:" "0"
    read -s NEW_ADMIN_USER

    coloredOutput "\n" "0"

    usermod -aG sudo NEW_ADMIN_USER

    coloredOutput "Gave user $NEW_ADMIN_USER sudo permissions.\n" "0"
}

removeAdmin() {
    coloredOutput "User to remove admin from:" "0"
    read -s OLD_ADMIN_USER

    coloredOutput "\n" "0"

    gpasswd -d NEW_ADMIN_USER sudo

    coloredOutput "Gave user $NEW_ADMIN_USER sudo permissions.\n" "0"
}

runList() {
    coloredOutput "##################################\n" "38;5;20"
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

    coloredOutput "1) Fix Sources          2) Setup Firewall\n" "0"
    coloredOutput "3) Set All Passwords    4) List Admins\n" "0"
    coloredOutput "5) Add Admin            6) Remove Admin\n" "0"
    coloredOutput "7) Setup SSH            8) ---\n" "0"
    
    echo "Choose:"
    read -s USRINPOPTION

    if [ "${USRINPOPTION}" == "1" ]; then
        fixSources
    elif [ "${USRINPOPTION}" == "2" ]; then
        setupFirewall
    elif [ "${USRINPOPTION}" == "3" ]; then
        setAllPasswords
    elif [ "${USRINPOPTION}" == "4" ]; then
        listAdmins
    elif [ "${USRINPOPTION}" == "5" ]; then
        addAdmin
    elif [ "${USRINPOPTION}" == "6" ]; then
        removeAdmin
    elif [ "${USRINPOPTION}" == "7" ]; then
        configureSSH
    fi

    runList
}

runList
