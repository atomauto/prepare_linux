#!/bin/bash
#shellcheck disable=all

## DEFAULT ARGS
logfile=$(basename -s .sh "$0").log
logging=false      #Not implemented yet
install_sudo=false #Not used yet
install_nginx=false
install_nomad=false
#It's good idea for future to specify dev or prod and server type for motd generation
sysfunction="Nginx server" #Not implemented yet
sysenv="Dev"               #Not implemented yet
swap=false

function usage() {
    echo "Usage: $(basename $0) [-h] [-l] [-r]"
    echo " -l,  --logging             Enables logging in defaul logfile (located in same dir as script)"
    echo " -d,  --docker              Install docker"
    echo " -n,  --nginx               Install nginx-light with php-fpm"
    echo " -no, --nomad              Install nomad,vault and consul"
    echo " -s,  --swap <size>         Make swap with size and add it to fstab. Syntax of size is a syntax for -l of fallocate."
    echo " --sysfunction <string>    Sysfunction like Nginx Server, Postgres Database and etc."
    echo " --sysenv <string>         Sysenv like dev, production and etc."
    echo " -h, --help                Show this help"
    echo ""
    echo "This script performs essential initial stuff on fresh debian installation"
    echo "ATTENTION: copy your ssh key to machine BEFORE LAUNCHING this script"
    echo "Debug information can be found in $logfile, if logging is enabled"
}

while :; do
    case "$1" in
    -d | --docker)
        install_docker=true
        shift
        ;;
    -n | --nginx)
        install_nginx=true
        shift
        ;;
    -no | --nomad)
        install_nomad=true
        shift
        ;;
    -l | --logging)
        shift
        logging=true
        ;;
    -s | --swap)
        shift
        swap=true
        swap_size="$1"
        shift
        ;;
    --sysfunction)
        shift
        sysfunction="$1"
        shift
        ;;
    --sysenv)
        shift
        sysenv="$1"
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        break
        ;;
    esac
done

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
# $1 ~ /PubkeyAuthentication/ {$1="PrintMotd"; $2="yes"}
{print}
' $file.old >$file

if $swap; then
    fallocate -l $swap_size /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile    none    swap    sw    0    0" >>/etc/fstab
fi

#Curl is necessary for many things, git is necessary for getting all other scripts
apt install -y curl git

#Changes if we suggest working in console on this machine
apt install -y bash-completion
#Replacing standard .bashrc with uncommented version for more colors and aliases
mv .bashrc /home/$SUDO_USER/.bashrc

#Changing motd (ssh message after login), making it more informative with some diagnostic
apt install -y coreutils bc procps hostname mawk bind9-host lsb-release

#Need some solution with tz-data default timezone

#TODO: suggest making swap according to ram memory
#Adding swap to small VM we can free some RAM and "hack" cloud provider pricing
#Also it will help us to survive high peaks in load, memory leaks and etc, giving additional metric and time
#https://docs.rackspace.com/support/how-to/swap-space-on-cloud-servers/
#https://www.redhat.com/sysadmin/cloud-swap

#SSH informative message (MOTD - Message of the Day) is generated in motd.sh
chmod +x print_functions.sh motd.sh
cp print_functions.sh /usr/bin/print_functions.sh
cp motd.sh /usr/bin/motd.sh
grep "*/5 * * * * root /usr/bin/motd.sh > /etc/motd 2>/dev/null" /etc/crontab || echo "*/5 * * * * root /usr/bin/motd.sh > /etc/motd 2>/dev/null" >>/etc/crontab

if $install_docker; then
    source docker.sh
fi

if $install_nginx; then
    source nginx.sh
fi

if $install_nomad; then
    source nomad.sh
fi