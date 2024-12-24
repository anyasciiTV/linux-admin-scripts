#!/bin/bash

user="$1"

# Check if a username was provided
if [ -z "$user" ]; then
  echo "Usage: $0 <username>"
  exit 1
fi

# Display account information
awk -F: -v user="$user" '$1 == user { 
  print "Login: " $1 
  print "UID: " $3 
  print "GID: " $4 
  print "GECOS: " $5 
  print "Home Directory: " $6 
  print "Shell: " $7 
}' /etc/passwd
