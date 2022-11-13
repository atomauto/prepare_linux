#!/bin/bash
#Help message

function usage() {
    echo "This script performs essential initial stuff on fresh debian installation"
    echo "Right now it doesn't accept any arguments"
}

if [[ "$1" == -h || "$1" == --help ]]; then
    usage
    exit 0
fi

#Attention: sudo isn't installed by default in some variants of debian installation
#apt install sudo
#usermod -a -G sudo $user
#Note: I consider apt is better to use then apt-get (longer in typing) or aptitude (not installed by default, longer to type)
apt update
apt full-upgrade -y
#TODO: maybe we need some apt sources files check and correction
#Note: if access by ssh key isn't configured, before execution run ssh-copy-id on your machine
#Check and edit sshd_config with awk
#TODO: Script changes only existing lines, it doesn't add new
file=/etc/ssh/sshd_config
cp -p $file $file.old &&
awk '
$1 ~ /StrictModes/ {$1="StrictModes"; $2="yes"}
$1 ~ /PasswordAuthentication/ {$1="PasswordAuthentication"; $2="no"}
$1 ~ /PermitEmptyPasswords/ {$1="PermitEmptyPasswords"; $2="no"}
$1 ~ /PubkeyAuthentication/ {$1="PubkeyAuthentication"; $2="yes"}
#Attention: some cloud providers and etc. can use prohibit-password to allow root ssh key auth
$1 ~ /PermitRootLogin/ {$1="PermitRootLogin"; $2="no"}
{print}
' $file.old > $file

#Curl is necessary for many things, git is necessary for getting all other scripts
apt install -y curl git

#Changes if we suggest working in console on this machine
apt install -y bash-completion
#Replacing standard .bashrc with uncommented version for more colors and aliases
mv .bashrc ~/.bashrc

#Changing motd (ssh message after login), making it more informative with some diagnostic
apt install -y coreutils bc procps hostname mawk bind9-host lsb-release

#It's good idea for future to specify dev or prod and server type for motd generation
#Should be taken as script argument
SYSFUNCTION="Nginx server"
SYSENV="Dev"

#Need some solution with tz-data default timezone

#TODO: suggest making swap according to ram memory
#Adding swap to small VM we can free some RAM and "hack" cloud provider pricing
#Also it will help us to survive high peaks in load, memory leaks and etc, giving additional metric and time
#https://docs.rackspace.com/support/how-to/swap-space-on-cloud-servers/
#https://www.redhat.com/sysadmin/cloud-swap

#SSH informative message (MOTD - Message of the Day) is generated in motd.sh
#We should decide whether move it to cron or generate only on ssh login via user