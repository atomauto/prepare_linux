#!/bin/bash
#By default we install docker and docker-compose from distro repository
source='distro'
if [[ "$1" == -f || "$1" == --docker-repo ]]; then
    source='docker'
fi
echo "Script started with root privilegies, source of docker repo is $source" > $logfile
#Using deb-based distribution (checked with Kubuntu 22.04.1 LTS)
apt update >> $logfile && apt full-upgrade -y >> $logfile

if [[ $source == 'distro' ]]; then
    apt install -y docker docker-compose >> $logfile
else
    apt install -y ca-certificates curl gnupg lsb-release >> $logfile
    mkdir -p /etc/apt/keyrings
    #Auto selection Debian or Ubuntu
    if lsb_release -d | grep Debian >/dev/null; then
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg >> $logfile
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
    elif lsb_release -d | grep Ubuntu >/dev/null; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg >> $logfile
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
    else
        echo "Script supports only Ubuntu and Debian distributions if you use official Docker repository"
        echo "Docker official repo for deb is supported only for Ubuntu and Debian. You can try use Debian or Ubuntu repo on your own risk." >> $logfile
        echo "Please look Docker documentation for your distribution" >> $logfile
        exit 2
    fi
    chmod a+r /etc/apt/keyrings/docker.gpg
    apt update >> $logfile
    apt install install docker-ce docker-ce-cli containerd.io docker-compose-plugin >> $logfile
fi

#Preparing environment for rootless docker run under usual user
#https://docs.docker.com/engine/security/rootless/
apt install -y uidmap dbus-user-session >> $logfile
if lsb_release -d | grep Debian >/dev/null; then
    apt install -y slirp4netns fuse-overlayfs >> $logfile
fi