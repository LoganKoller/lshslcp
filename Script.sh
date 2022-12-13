echo "Please enter user this is running from: "
read localUser

echo "Update system? (y/n): "
read isSystemUpdated

if [ $isSystemUpdated = "y" ] 
then
    apt-get update -y
    apt-get upgrade -y
    apt-get dist-upgrade -y
    apt-get install -f -y
    apt-get autoremove -y
    apt-get autoclean -y
    apt-get check
    echo "Finished upgrading system, please restart OS."
    exit
fi

echo "Create backups? (y/n): "
read createBackups

if [ $createBackups = "y" ] 
then
    mkdir /Backups
    cp /etc/shadow /Backups
    cp /etc/sudoers /Backups
    cp /etc/group /Backups
    cp /etc/passwd /Backups
    cp -r /var/log /Backups
    for x in `ls /home`
    do
        cp -r /home/$x /Backups
    done
fi

installDependencies() {
    apt-get update -y
    apt-get upgrade -y
    apt-get autoremove -y
    apt-get autoclean -y
    apt-get check
    killall firefox
    apt-get --purge --reinstall install firefox -y
    apt-get install ufw -y # Install Firewall
    apt-get install chkrootkit -y # Install chkrootkit (antivirus 1)
    apt-get install lynis -y # Install lynis (antivirus 2 & very helpful system checker)
    apt-get install clamav -y # Installs ClamAV (antivirus 3)
    apt-get install rkhunter -y # Installs rkhunter (antivirus 4)
}

runCLAMAV() {
    echo "Running Clam AV(Antivirus)"
    systemctl stop clamav-freshclam
    echo "Freshclam Service \e[31m[STOPPED]\e[0m"
    freshclam
    echo "Database Up-To-Date \e[32m[OK]\e[0m"
    systemctl start clamav-freshclam
    echo "Freshclam Service \e[32m[STARTED]\e[0m"
    echo "Starting scan..."
    clamscan -r -i --exclude-dir="^/sys"
    echo "Saving results..."
    clamscan -r -i --exclude-dir="^/sys" > "/home/$localUser/Desktop/clamav_results.log"
    echo "\n\e[32mScan Complete, check above for results or check the log file created in the current user's Desktop directory.\e[0m"
}

runLynis() {
    echo "Running Lynis(Antivirus and detailed system logger)"
    lynis update info
    lynis audit system
    echo "\n\e[32mScan Complete, saving the log file in the current user's Desktop directory...\e[0m"
    lynis audit system > "/home/$localUser/Desktop/lynis_results.log"
    echo "Done!"
}

runCHKRK() {
    echo "Running chkrootkit(Antivirus)"
    chkrootkit -q
    echo "Finished, saving results..."
    chkrootkit -q > "/home/$localUser/Desktop/chkrootkit_results.log"
    echo "Done!"
}

runRKH() {
    echo "Running rootkithunter(Antivirus)"
    rkhunter --update
    rkhunter --propupd
    rkhunter -c --enable all --disable none
    echo "Finished!"
}

runAllAVs() {
    runCLAMAV
    runLynis
    runCHKRK
    runRKH
}
