#!/bin/bash

sortArgs=$1

## FUNCTION DEFINITIONS

# Incorporate the agent-add function
function agent-add () {
  [ -n "$SSH_AGENT_PID" ] && return
  eval $(ssh-agent)
  ssh-add
}

# Incorporate a function to kill the ssh-agent process
function agent-rm () {
  # Setup variables
  export SSH_AGENT_PID=$SSH_AGENT_PID
  export SSH_AUTH_SOCK=$SSH_AUTH_SOCK

  # Kill the ssh-agent process, if it exists.
  if [ -n "${SSH_AGENT_PID}" ]
  then
        printf "Killing the left-over ssh-agent process, pid #${SSH_AGENT_PID}\n"
        kill ${SSH_AGENT_PID}
        unset SSH_AGENT_PID
  fi

  sleep 2

  if [ -e "${SSH_AUTH_SOCK}" ]
  then
        printf "Removing stale ssh-agent socket file: $SSH_AUTH_SOCK\n"
        rm ${SSH_AUTH_SOCK}
        unset SSH_AUTH_SOCK
  fi
}

# Function to email the user after their user account has been disabled
function emailuser () {
  # Retrieve the user's email address from LDAP 
  useremailaddress=$(/usr/bin/ldapsearch -p 389 -h <ldap_server_address> -x -y ~/.ldappass -ZZ username=$user2ban | grep PrimaryEmail | cut -d" " -f2) # Insert your ldap server address 
  printf "\n\n"
  printf "Sending an email to the user's email address at:  $useremailaddress\n"

  # Send the email (adjust the path to the email message as needed)
  mail -s "Cluster Account Disabled" -r "HPC <email@domain.com>" $useremailaddress < /path/to/emailmsg.txt
  
  printf "\n\n"
  printf "Email sent!\n\n"
}

# Function to check to see if the user running this script is root. 
# If so, exit and run with an account with sudo priveleges
function runningusercheck () {
  if [[ $UID == "0" ]];
  then
    printf "You are currently logged-in as root.\n"
    printf "You must instead run this as your .admin account, and run \"agent-add\" first.\n"
    printf "Exiting...\n\n\n"
    exit
  fi
}

# Main function to ban the user
function banuser () {
  # Ensure a username is provided when running the script
  if [ -z "$1" ]
  then
    echo "Please enter a username to ban, or type CTRL-C to exit: "
    read user2ban
  else
    user2ban=$1
  fi

  # Check if the username is empty
  if [ -z "$user2ban" ];
  then
    printf "Username not provided! Exiting! No changes made!\n\n\n"
    kill -9 $BASHPID
    exit
  fi

  # Verify that this is the action they want to take
  printf "Are you sure you want to complete the following actions on user account: $user2ban ? \n"
  printf "\n\n"
  printf "Actions to take:\n"
  printf "   1) Add this user to the \"banned_users\" group in login nodes, which is banned from logins via access.conf\n" 
  printf "   2) Kill all of the user's processes on all login servers\n"
  printf "\n"
  printf "Would you like to proceed? (Type YES in all caps to proceed. Any other input exits without changes): "
  read bananswer

  # Proceed if the user confirms
  if [[ $bananswer == "YES" ]];
  then
    # Log the actions (adjust log paths)
    banlog=/var/log/bans.log
    banlist=/var/log/current_banned_users.log
    loginsrv="login[0-5]" 
    bandate=`date`

    # Log initial settings for the user
    printf "Disabling user account:  $user2ban\n" >> $banlog
    printf "Changes made by:  $USER\n" >> $banlog
    printf "Changes made on $bandate\n\n" >> $banlog

    # Add user to the banned_users group
    printf "Adding the user to the \"banned_users\" local group on each login node"
    pdsh -lroot -w $loginsrv "groupmems -g banned_users -a $user2ban"
    printf "\nUser \"$user2ban\" added to local group \"banned_users\" \n\n"

    # Get the user's UID
    uid2ban=`getent passwd $user2ban | cut -d ":" -f3`

    # Kill all processes for the user on the login servers
    printf "Killing all processes on the login servers for user \"$user2ban\"\n"
    pdsh -lroot -w $loginsrv "pkill -u $user2ban" > /dev/null
    printf "\nAll processes for this account have been terminated.\n\n"

    # Update the list of banned users
    numtimesonlist=`grep $user2ban $banlist | grep -v $user2ban.admin | wc -l`
    if [[ $numtimesonlist > "0" ]];
    then
        printf "User is already on currently-banned list: not adding a duplicate entry.\n"
    else
        printf "Adding entry to currently-banned list for $user2ban\n"
        printf "$user2ban - banned on: $bandate by $USER\n" >> $banlist
    fi

    # Email the user to notify them
    emailuser

  else
    printf "Exiting! No changes made!\n\n\n"
    kill -9 $BASHPID
  fi
}

# CASE statement to handle command-line options
case $sortArgs in
  -h|--help)
    printf "Usage: banuser [options] [username]\n\n"
    printf " \n"
    printf "Options:\n"
    printf -- "  -h,--help:         print this help\n"
    printf -- "  -a:                run agent-add, ban user, then remove agent-add afterwards.\n"
    printf -- "  default:           ban user, email them, then remove agent-add.\n"
    printf " \n\n"
    printf "Description: \n"
    printf -- "  Script to ban a user from login nodes. It will do the following:\n"
    printf -- "         1) Add this user to the \"banned_users\" group in login nodes\n" 
    printf -- "         2) Kill all of the user's processes on the login servers\n"
    printf " \n\n\n"
    ;;

  -a)
    runningusercheck
    agent-add
    banuser "$2"
    agent-rm
    ;;

  *)
    runningusercheck
    banuser "$@"
    ;;
esac
