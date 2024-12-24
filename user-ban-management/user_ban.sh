#!/bin/bash

# Function to check if the script is run as root; script must be run with an administrative account for security purposes
function runningusercheck() {
    if [[ $UID == "0" ]]; then
        echo "You are currently logged-in as root."
        echo "You must run this as your admin  account."
        echo "Exiting..."
        exit 1
    fi

     # Check if the admin account has sudo privileges
    if ! sudo -v &>/dev/null; then
        echo "You must have sudo privileges to run this script."
        echo "Exiting..."
        exit 1
    fi
}

# Function to ban a user (add to banned_users group that is not in the access.conf file and also kill processes)
function banuser() {
    if [ -z "$1" ]; then
        echo "Please enter a username to ban: "
        read user2ban
    else
        user2ban=$1
    fi

    if [ -z "$user2ban" ]; then
        echo "Username not provided! Exiting!"
        exit 1
    fi

    # Ask the admin to confirm the action
    echo "Are you sure you want to ban user: $user2ban? (YES to proceed)"
    read bananswer

    if [[ $bananswer != "YES" ]]; then
        echo "Exiting! No changes made!"
        exit 1
    fi

    # Log the initial ban information
    banlog="/var/log/bannedusers.log"
    bandate=$(date)

    # Ensure log file exists, if not create it
    if [ ! -f "$banlog" ]; then
        touch "$banlog"
    fi

    echo "Disabling user account: $user2ban" >> $banlog
    echo "Changes made by: $USER" >> $banlog
    echo "Changes made on: $bandate" >> $banlog

    # Add user to the banned_users group (group is not in the access.conf file)
    echo "Adding $user2ban to banned_users group..."
    if usermod -a -G banned_users $user2ban; then
        echo "$user2ban added to banned_users group" >> $banlog
    else
        echo "Failed to add $user2ban to banned_users group." >> $banlog
        echo "Exiting..."
        exit 1
    fi

    # Get user UID to kill processes
    uid2ban=$(id -u $user2ban)

    # Kill all processes for the user
    echo "Killing all processes for user $user2ban..."
    if pkill -u $user2ban; then
        echo "All processes for user $user2ban have been killed." >> $banlog
    else
        echo "Failed to kill processes for $user2ban." >> $banlog
    fi

    # Log the action of banning
    banned_log="/var/log/current_banned_users.log"
    if [ ! -f "$banned_log" ]; then
        touch "$banned_log"
    fi
    echo "$user2ban - banned on: $bandate by $USER" >> $banned_log

    echo "User $user2ban has been banned and all their processes killed."
}

# Main script logic
runningusercheck
banuser "$1"
