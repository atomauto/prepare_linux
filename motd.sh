#!/bin/bash
#Thanks to:
#https://github.com/rtulke/dynmotd
#https://github.com/dylanaraps/neofetch
#https://github.com/bcyran/fancy-motd

#WARNING: getting public IP takes nearly a one second
#Whole script execution may take even two seconds
#NOTICE: practically all error output (pipe 2) is redirectered to /dev/null
#No error logging or debug info is generated

#Changing locales give us two benefits:
#1.Execution speed is slightly increased by not using unicode
#2.Some script logic expects english output of commands, if locale is other then english e.g. apt upgradeable grep isn't working
LC_ALL=C
LANG=C
source print_functions.sh

#Colors defined in .bashrc
F1=$darkgray
F2=$lightpurple
F3=$lightgreen
F4=$red

function get_local_ip() {
    #Get local ip
    # Local IP interface, by default we suggest 'auto' (interface on default route)
    # Possible values:  'auto', 'en0', 'en1'
    local_ip_interface=('auto')
    if [[ "${local_ip_interface[0]}" == "auto" ]]; then
        local_ip="$(ip route get 1 | awk -F'src' '{print $2; exit}')"
        local_ip="${local_ip/uid*/}"
        [[ "$local_ip" ]] || local_ip="$(ifconfig -a | awk '/broadcast/ {print $2; exit}')"
    else
        for interface in "${local_ip_interface[@]}"; do
            local_ip="$(ip addr show "$interface" 2>/dev/null |
                awk '/inet / {print $2; exit}')"
            local_ip="${local_ip/\/*/}"
            [[ "$local_ip" ]] ||
                local_ip="$(ifconfig "$interface" 2>/dev/null |
                    awk '/broadcast/ {print $2; exit}')"
            if [[ -n "$local_ip" ]]; then
                prin "$interface" "$local_ip"
            else
                err "Local IP: Could not detect local ip for $interface"
            fi
        done
    fi
}

function get_public_ip() {
    #Get public ip
    #Security warning: we connect to external site in internet
    #TODO: getting public IP takes 1-1.5 seconds
    if [[ ! -n "$public_ip_host" ]] && type -p dig >/dev/null; then
        public_ip="$(dig +time=1 +tries=1 +short myip.opendns.com @resolver1.opendns.com)"
        [[ "$public_ip" =~ ^\; ]] && unset public_ip
    fi
    if [[ ! -n "$public_ip_host" ]] && [[ -z "$public_ip" ]] && type -p drill >/dev/null; then
        public_ip="$(drill myip.opendns.com @resolver1.opendns.com |
            awk '/^myip\./ && $3 == "IN" {print $5}')"
    fi
    if [[ -z "$public_ip" ]] && type -p curl >/dev/null; then
        public_ip="$(curl -L --max-time "$public_ip_timeout" -w '\n' "$public_ip_host")"
    fi
    if [[ -z "$public_ip" ]] && type -p wget >/dev/null; then
        public_ip="$(wget -T "$public_ip_timeout" -qO- "$public_ip_host")"
    fi
}

function get_uptime() {
    #UPTIME=$(uptime | cut -c2- | cut -d, -f1)
    #More pretty uptime from neofetch
    if [[ -r /proc/uptime ]]; then
        s=$(</proc/uptime)
        s=${s/.*/}
    else
        boot=$(date -d"$(uptime -s)" +%s)
        now=$(date +%s)
        s=$((now - boot))
    fi
    d="$((s / 60 / 60 / 24)) days"
    h="$((s / 60 / 60 % 24)) hours"
    m="$((s / 60 % 60)) minutes"
    # Remove plural if < 2.
    ((${d/ */} == 1)) && d=${d/s/}
    ((${h/ */} == 1)) && h=${h/s/}
    ((${m/ */} == 1)) && m=${m/s/}
    # Hide empty fields.
    ((${d/ */} == 0)) && unset d
    ((${h/ */} == 0)) && unset h
    ((${m/ */} == 0)) && unset m
    uptime=${d:+$d, }${h:+$h, }$m
    uptime=${uptime%', '}
    uptime=${uptime:-$s seconds}
}

function get_memory() {
    # Get current free memory
    # MEMFREE=$(echo $(cat /proc/meminfo | egrep MemFree | awk {'print $2'})/1024 | bc)
    # Get maxium usable memory
    # MEMMAX=$(echo $(cat /proc/meminfo | egrep MemTotal | awk {'print $2'})/1024 | bc)

    # Memory calculation above is wrong
    # MemUsed = Memtotal + Shmem - MemFree - Buffers - Cached - SReclaimable
    # Source: https://github.com/KittyKatt/screenFetch/issues/386#issuecomment-249312716
    while IFS=":" read -r a b; do
        case $a in
        "MemTotal")
            ((mem_used += ${b/kB/}))
            mem_total="${b/kB/}"
            ;;
        "Shmem") ((mem_used += ${b/kB/})) ;;
        "MemFree" | "Buffers" | "Cached" | "SReclaimable")
            mem_used="$((mem_used -= ${b/kB/}))"
            ;;
        "MemAvailable")
            mem_avail=${b/kB/}
            ;;
        esac
    done </proc/meminfo
    mem_used=$(((mem_total - mem_avail) / 1024))
    mem_total="$((mem_total / 1024))"
    ((mem_perc = mem_used * 100 / mem_total))
    mem_used=$(awk '{printf "%.2f", $1 / $2}' <<<"$mem_used 1024")
    mem_total=$(awk '{printf "%.2f", $1 / $2}' <<<"$mem_total 1024")
    mem_label=GiB
    #Calculation in Kib, may be suitable for Raspberry Pi and etc.
    # mem_used=$((mem_used * 1024))
    # mem_total=$((mem_total * 1024))
    # mem_label=KiB
    memory_bar=$(print_bar $WIDTH $mem_perc)
    mem_used=$(print_color ${mem_used}${mem_label:-MiB} $mem_perc 65 85)
    mem_perc_text=$(print_color ${mem_perc:+(${mem_perc}%)} $mem_perc 65 85)
    # memory="${mem_used}${mem_label:-MiB} / ${mem_total}${mem_label:-MiB} ${mem_perc:+(${mem_perc}%)}"
    memory="${mem_used} / ${CO}${mem_total}${mem_label:-MiB} $mem_perc_text"

}

function get_model() {
    if [[ -d /system/app/ && -d /system/priv-app ]]; then
        model="$(getprop ro.product.brand) $(getprop ro.product.model)"

    elif [[ -f /sys/devices/virtual/dmi/id/board_vendor ||
        -f /sys/devices/virtual/dmi/id/board_name ]]; then
        model=$(</sys/devices/virtual/dmi/id/board_vendor)
        model+=" $(</sys/devices/virtual/dmi/id/board_name)"

    elif [[ -f /sys/devices/virtual/dmi/id/product_name ||
        -f /sys/devices/virtual/dmi/id/product_version ]]; then
        model=$(</sys/devices/virtual/dmi/id/product_name)
        model+=" $(</sys/devices/virtual/dmi/id/product_version)"

    elif [[ -f /sys/firmware/devicetree/base/model ]]; then
        model=$(</sys/firmware/devicetree/base/model)

    elif [[ -f /tmp/sysinfo/model ]]; then
        model=$(</tmp/sysinfo/model)
    fi
    # Remove dummy OEM info.
    model=${model//To be filled by O.E.M./}
    model=${model//To Be Filled*/}
    model=${model//OEM*/}
    model=${model//Not Applicable/}
    model=${model//System Product Name/}
    model=${model//System Version/}
    model=${model//Undefined/}
    model=${model//Default string/}
    model=${model//Not Specified/}
    model=${model//Type1ProductConfigId/}
    model=${model//INVALID/}
    model=${model//All Series/}
    model=${model//�/}

    case $model in
    "Standard PC"*) model="KVM/QEMU (${model})" ;;
    OpenBSD*) model="vmm ($model)" ;;
    esac
}

function get_loads_average() {
    #Loads average
    loads=$(cut -d ' ' -f '1,2,3' /proc/loadavg)
    nproc=$(nproc)
    warning_threshold=$(bc -l <<<"${nproc} * 0.9")
    error_threshold=$(bc -l <<<"${nproc} * 1.5")
    load_average=""
    for load in ${loads}; do
        load_average+="$(print_color "${load}" "${load}" "${warning_threshold}" "${error_threshold}"), "
    done
    # print_columns "Load average" "${text::-2}"
}

function generate_system_info() {
    #Get my fqdn hostname.domain.name.tld
    #HOSTNAME=$(hostname --fqdn)
    #username@hostname looks better
    HOSTNAME=$(id -un)@$(hostname)
    #Get current kernel version
    UNAME=$(uname -r)
    #Get runnig sles distribution name
    DISTRIBUTION=$(lsb_release -s -d)
    #Get hardware platform
    PLATFORM=$(uname -m)
    #Get amount of cpu processors
    CPUS=$(cat /proc/cpuinfo | grep processor | wc -l)
    #Get system cpu model
    CPUMODEL=$(cat /proc/cpuinfo | egrep 'model name' | uniq | awk -F ': ' {'print $2'})
    #Get current free swap space
    SWAPFREE=$(echo $(cat /proc/meminfo | egrep SwapFree | awk {'print $2'})/1024 | bc)
    #Get maxium usable swap space
    SWAPMAX=$(echo $(cat /proc/meminfo | egrep SwapTotal | awk {'print $2'})/1024 | bc)
    #Get current procs
    PROCCOUNT=$(ps -Afl | egrep -v 'ps|wc' | wc -l)
    #Get maxium usable procs
    PROCMAX=$(ulimit -u)

    get_local_ip
    get_public_ip
    get_uptime
    get_memory
    get_model
    get_loads_average


echo "Welcome to $HOSTNAME" >system_info
print_columns "Host model" "$model" >>system_info
print_columns "OS" "$DISTRIBUTION ${PLATFORM}" >>system_info
print_columns "Kernel" "$UNAME" >>system_info
print_columns "Local IP" "$local_ip" >>system_info
print_columns "Public IP" "$public_ip" >>system_info
print_columns "Uptime" "$uptime" >>system_info
print_columns "CPU" "$CPUS x $CPUMODEL" >>system_info
print_columns "Load Average" "$load_average" >>system_info
print_columns "Memory" "$memory" >>system_info
echo -e $memory_bar >>system_info
print_columns "Swap Memory" "$SWAPFREE MB Free of $SWAPMAX MB Total" >>system_info
print_columns "Processes" "$PROCCOUNT of $PROCMAX MAX" >>system_info
}

## Storage Informations
function show_storage_info() {
    ## get current storage information, how many space a left :)
    STORAGE=$(df -hT | sort -r -k 6 -i | sed -e 's/^File.*$/\x1b[0;37m&\x1b[1;32m/' | sed -e 's/^Datei.*$/\x1b[0;37m&\x1b[1;32m/' | egrep -v docker)
    ## display storage information
    echo -e "
${F2}============[ ${F1}Storage Info${F2} ]===================================================
${F3}${STORAGE}${F1}"
}

function generate_disk_info() {
    excluded_types=(
        "devtmpfs"
        "ecryptfs"
        "squashfs"
        "tmpfs"
    )
    # shellcheck disable=SC2046
    disks="$(df -h --local --print-type $(printf " -x %s" "${excluded_types[@]}") | tail -n +2 | sort -u -k 7)"
    disk_info=""
    while IFS= read -r disk; do
        IFS=" " read -r filesystem _ total used free percentage mountpoint <<<"${disk}"
        device=$(sed 's|/dev||g;s|/mapper||g;s|^/||g' <<<"${filesystem}")
        left_label="${device} () - ${used} used, ${free} free"
        right_label="/ ${total}"
        free_width=$((WIDTH - ${#left_label} - ${#right_label} - 1))
        mountpoint=$(print_truncate "${mountpoint}" ${free_width} "start")
        left_label="${device} (${mountpoint}) - ${used} used, ${free} free"
        label=$(print_split "${WIDTH}" "${left_label}" "${right_label}")
        disk_info+="${label}\n$(print_bar "${WIDTH}" "${percentage::-1}")\n"
    done <<<"${disks}"
    print_columns "Disk space" "${disk_info::-2}" >disk_info
}

#User Informations
function show_user_info() {
    ## get my username
    WHOIAM=$(whoami)
    ## get my own user groups
    GROUPZ=$(groups)
    ## get my user id
    ID=$(id)
    ## how many users are logged in
    SESSIONS=$(who | wc -l)
    ## get a list of all logged in users
    LOGGEDIN=$(echo $(who | awk {'print $1" " $5'} | awk -F '[()]' '{ print $1 $2 '} | uniq -c | awk {'print "(" $1 ") "$2" " $3","'}) | sed 's/,$//' | sed '1,$s/\([^,]*,[^,]*,[^,]*,\)/\1\n\\033[1;32m\t          /g')
    ## how many system users are there, only check uid <1000 and has a login shell
    SYSTEMUSERCOUNT=$(cat /etc/passwd | egrep '\:x\:10[0-9][0-9]' | grep '\:\/bin\/bash' | wc -l)
    ## who is a system user, only check uid <1000 and has a login shell
    SYSTEMUSER=$(cat /etc/passwd | egrep '\:x\:10[0-9][0-9]' | egrep '\:\/bin\/bash|\:\/bin/sh' | awk '{if ($0) print}' | awk -F ':' {'print $1'} | awk -vq=" " 'BEGIN{printf""}{printf(NR>1?",":"")q$0q}END{print""}' | cut -c2- | sed 's/ ,/,/g' | sed '1,$s/\([^,]*,[^,]*,[^,]*,[^,]*,[^,]*,\)/\1\n\\033[1;32m\t          /g')
    ## how many ssh super user (root) are there
    SUPERUSERCOUNT=$(cat /root/.ssh/authorized_keys | egrep '^ssh-' | wc -l)
    ## who is super user (ignore root@)
    SUPERUSER=$(cat /root/.ssh/authorized_keys | egrep '^ssh-' | awk '{print $NF}' | awk -vq=" " 'BEGIN{printf""}{printf(NR>1?",":"")q$0q}END{print""}' | cut -c2- | sed 's/ ,/,/g' | sed '1,$s/\([^,]*,[^,]*,[^,]*,\)/\1\n\\033[1;32m\t          /g')
    ## count sshkeys
    KEYUSERCOUNT=$(for i in $(cat /etc/passwd | egrep '\:x\:10[0-9][0-9]' | awk -F ':' {'print $6'}); do cat $i/.ssh/authorized_keys 2>/dev/null | grep ^ssh- | awk '{print substr($0, index($0,$3)) }'; done | wc -l)
    ## print any authorized ssh-key-user of a existing system user
    KEYUSER=$(for i in $(cat /etc/passwd | egrep '\:x\:10[0-9][0-9]' | awk -F ':' {'print $6'}); do cat $i/.ssh/authorized_keys 2>/dev/null | grep ^ssh- | awk '{print substr($0, index($0,$3)) }'; done | awk -vq=" " 'BEGIN {printf ""}{printf(NR>1?",":"")q$0q}END{print""}' | cut -c2- | sed 's/ , /, /g' | sed '1,$s/\([^,]*,[^,]*,[^,]*,\)/\1\n\\033[1;32m\t          /g')
    ## show user information
    echo -e "
${F2}============[ ${F1}User Data${F2} ]======================================================
${F1}    Your Username ${F2}= ${F3}$WHOIAM
${F1}  Your Privileges ${F2}= ${F3}$ID
${F1} Current Sessions ${F2}= ${F3}[$SESSIONS] $LOGGEDIN
${F1}      SystemUsers ${F2}= ${F3}[$SYSTEMUSERCOUNT] $SYSTEMUSER
${F1}  SshKeyRootUsers ${F2}= ${F3}[$SUPERUSERCOUNT] $SUPERUSER
${F1}      SshKeyUsers ${F2}= ${F3}[$KEYUSERCOUNT] $KEYUSER${F1}"
}

function show_environment_info() {
    #Environment variables should be set before execution
    echo -e "
${F2}============[ ${F1}Environment Data${F2} ]===============================================
${F1}         Function ${F2}= ${F3}$SYSFUNCTION
${F1}      Environment ${F2}= ${F3}$SYSENV"

}

#Services status and info
function generate_services_info() {
    declare -A services
    services["nginx"]="Nginx"
    services["php-fpm"]="PHP"
    #TODO: workaround with shitty php-fpm services name in Debian
    services["php7.3-fpm"]="PHP 7.3"
    services["php7.4-fpm"]="PHP 7.4"
    services["memcached"]="Memcached"
    services["postgresql"]="Postgresql"
    services["postfix"]="Postfix"
    services["docker"]="Docker"
    services["sshd"]="SSH"
    services["fail2ban"]="Fail2Ban"
    services["ufw"]="UFW"
    services["jenkins"]="Jenkins"
    statuses=()
    for key in "${!services[@]}"; do
        if [[ $(systemctl list-unit-files "${key}*" | wc -l) -gt 3 ]]; then
            status=$(systemctl show -p ActiveState --value "${key}")
            statuses+=("$(print_status "${services[${key}]}" "${status}")")
        fi
    done
    services_info=$(print_wrap "${WIDTH}" "${statuses[@]}")
    print_columns "Services" "${services_info}" >services

}

function generate_docker_info() {
    #If there is no docker, do nothing
    #Suspend type command output by redirecting std pipe and error pipe to /dev/null
    if type docker >/dev/null 2>&1; then
        containers=$(docker ps -a --format "{{ .Names }}\t{{ .Status }}\t{{ .State }}")
        docker_info=""
        if [[ -z "${containers}" ]]; then
            docker_info+="no containers\n"
        else
            while IFS= read -r line; do
                IFS=$'\t' read -r name description state <<<"${line}"
                case ${state} in
                running) color="${CO}" ;;
                paused | restarting) color="${CW}" ;;
                exited | dead) color="${CE}" ;;
                *) color="${CN}" ;;
                esac
                docker_info+="$(print_split "${WIDTH}" "${name}" "${color}${description,,}${CN}")\n"
            done <<<"${containers}"
        fi
        print_columns "Docker" "${docker_info::-2}" >docker
    fi

}

function generate_updates_info() {
    if type checkupdates >/dev/null 2>&1; then
        updates=$(checkupdates 2>/dev/null | wc -l)
        if type yay >/dev/null 2>&1; then
            updates_aur=$(yay -Qum 2>/dev/null | wc -l)
            updates=$((updates + updates_aur))
        fi
    elif type dnf >/dev/null 2>&1; then
        updates=$(dnf check-update --quiet | grep -c -v "^$")
    elif type apt >/dev/null 2>&1; then
        updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
    else
        updates="N/A"
    fi
    updates_info="$(print_color "${updates} available" ${updates} 1 50)"
    print_columns "Updates" "${updates_info}" >updates

}
function show_info() {
    generate_system_info &
    generate_disk_info &
    generate_services_info &
    generate_docker_info &
    generate_updates_info &
    wait

    cat system_info
    cat disk_info
    cat services
    cat docker
    cat updates

    # show_user_info
    # show_update_info
    # show_environment_info
}

#If no parameter is passed then start show_info
if [ -z "$1" ]; then
    show_info
fi
