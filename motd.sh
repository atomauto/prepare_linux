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

#Colors defined in .bashrc
F1=$darkgray
F2=$lightpurple
F3=$lightgreen
F4=$red

#Colors for messages
CA="${CA:-\e[34m}" # Accent
CO="${CO:-\e[32m}" # Ok
CW="${CW:-\e[33m}" # Warning
CE="${CE:-\e[31m}" # Error
CN="${CN:-\e[0m}"  # None

# Max width used for components in second column
WIDTH="${WIDTH:-50}"

# Prints given blocks of text side by side
# $1 - left column
# $2 - right column
print_columns() {
    [[ -z $2 ]] && return
    paste <(echo -e "${CA}$1${1:+:}${CN}") <(echo -e "$2")
}

# Prints text with color according to given value and two thresholds
# $1 - text to print
# $2 - current value
# $3 - warning threshold
# $4 - error threshold
print_color() {
    local out=""
    if (($(bc -l <<<"$2 < $3"))); then
        out+="${CO}"
    elif (($(bc -l <<<"$2 >= $3 && $2 < $4"))); then
        out+="${CW}"
    else
        out+="${CE}"
    fi
    out+="$1${CN}"
    echo "${out}"
}

# Prints text as either acitve or inactive
# $1 - text to print
# $2 - literal "active" or "inactive"
print_status() {
    local out=""
    if [[ $2 == "active" ]]; then
        out+="${CO}▲${CN}"
    else
        out+="${CE}▼${CN}"
    fi
    out+=" $1${CN}"
    echo "${out}"
}

# Prints one line of text, truncates it at specified width and add ellipsis.
# Truncation can occur either at the start or at the end of the string.
# $1 - line to print
# $2 - width limit
# $3 - "start" or "end", default "end"
print_truncate() {
    local out
    local new_length=$(($2 - 1))
    # Just echo the string if it's shorter than the limit
    if [[ ${#1} -le "$2" ]]; then
        out="$1"
    elif [[ -z "$3" || "$3" == "end" ]]; then
        out="${1::${new_length}}…"
    else
        out="…${1: -${new_length}}"
    fi
    echo "${out}"
}

# Prints given text n times
# $1 - text to print
# $2 - how many times to print
print_n() {
    local out=""
    for ((i = 0; i < $2; i++)); do
        out+="$1"
    done
    echo "${out}"
}

# Prints bar divided in two parts by given percentage
# $1 - bar width
# $2 - percentage
print_bar() {
    local bar_width=$(($1 - 2))
    local used_width=$(($2 * bar_width / 100))
    local free_width=$((bar_width - used_width))
    local out=""
    out+="["
    out+="${CE}"
    out+=$(print_n "=" ${used_width})
    out+="${CO}"
    out+=$(print_n "=" ${free_width})
    out+="${CN}"
    out+="]"
    echo "${out}"
}


# Prints comma-separated arguments wrapped to the given width
# $1 - width to wrap to
# $2, $3, ... - values to print
print_wrap() {
    local width=$1
    shift
    local out=""
    local line_length=0
    for element in "$@"; do
        element="${element},"
        local visible_elelement future_length
        visible_elelement=$(strip_ansi "${element}")
        future_length=$((line_length + ${#visible_elelement}))
        if [[ ${line_length} -ne 0 && ${future_length} -gt ${width} ]]; then
            out+="\n"
            line_length=0
        fi
        out+="${element} "
        line_length=$((line_length + ${#visible_elelement}))
    done
    [[ -n "${out}" ]] && echo "${out::-2}"
}

# Prints some text justified to left and some justified to right
# $1 - total width
# $2 - left text
# $3 - right text
print_split() {
    local visible_first visible_second invisible_first_width invisible_second_width total_width \
        first_half_width second_half_width format_string

    visible_first=$(strip_ansi "$2")
    visible_second=$(strip_ansi "$3")
    invisible_first_width=$((${#2} - ${#visible_first}))
    invisible_second_width=$((${#3} - ${#visible_second}))
    total_width=$(($1 + invisible_first_width + invisible_second_width))

    if ((${#visible_first} + ${#visible_second} < $1)); then
        first_half_width=${#2}
    else
        first_half_width=$(($1 / 2))
    fi
    second_half_width=$((total_width - first_half_width))

    format_string="%-${first_half_width}s%${second_half_width}s"
    # shellcheck disable=SC2059
    printf ${format_string} "${2:0:${first_half_width}}" "${3:0:${second_half_width}}"
}

# Strips ANSI color codes from given string
# $1 - text to strip
strip_ansi() {
    echo -e "$1" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"
}

function show_system_info() {
    #Get my fqdn hostname.domain.name.tld
    #HOSTNAME=$(hostname --fqdn)
    #username@hostname looks better
    HOSTNAME=$(id -un)@$(hostname)
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
    #Get current kernel version
    UNAME=$(uname -r)
    #Get runnig sles distribution name
    DISTRIBUTION=$(lsb_release -s -d)
    #Get hardware platform
    PLATFORM=$(uname -m)

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

    ## get amount of cpu processors
    CPUS=$(cat /proc/cpuinfo | grep processor | wc -l)
    ## get system cpu model
    CPUMODEL=$(cat /proc/cpuinfo | egrep 'model name' | uniq | awk -F ': ' {'print $2'})

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
    memory="${mem_used}${mem_label:-MiB} / ${mem_total}${mem_label:-MiB} ${mem_perc:+(${mem_perc}%)}"

    ## get current free swap space
    SWAPFREE=$(echo $(cat /proc/meminfo | egrep SwapFree | awk {'print $2'})/1024 | bc)
    ## get maxium usable swap space
    SWAPMAX=$(echo $(cat /proc/meminfo | egrep SwapTotal | awk {'print $2'})/1024 | bc)
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

    #Get current procs
    PROCCOUNT=$(ps -Afl | egrep -v 'ps|wc' | wc -l)
    #Get maxium usable procs
    PROCMAX=$(ulimit -u)

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

    #Display system information
    #TODO: change relevant string colour if load average/cpu/memory usage is high
    echo -e "
${F2}============[ ${F1}System Info${F2} ]====================================================
${F1}        Hostname ${F2}= ${F3}$HOSTNAME
${F1}            Host ${F2}= ${F3}$model
${F1}              OS ${F2}= ${F3}$DISTRIBUTION ${PLATFORM}
${F1}          Kernel ${F2}= ${F3}$UNAME
${F1}        Local IP ${F2}= ${F3}$local_ip
${F1}       Public IP ${F2}= ${F3}$public_ip
${F1}          Uptime ${F2}= ${F3}$uptime
${F1}             CPU ${F2}= ${F3}$CPUS x $CPUMODEL
${F1}    Load average ${F2}= ${F3}$load_average
${F1}          Memory ${F2}= ${F3}$memory
${F1}     Swap Memory ${F2}= ${F3}$SWAPFREE MB Free of $SWAPMAX MB Total
${F1}       Processes ${F2}= ${F3}$PROCCOUNT of $PROCMAX MAX${F1}"
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

function show_disk_info() {
    excluded_types=(
        "devtmpfs"
        "ecryptfs"
        "squashfs"
        "tmpfs"
    )
    # shellcheck disable=SC2046
    disks="$(df -h --local --print-type $(printf " -x %s" "${excluded_types[@]}") | tail -n +2 | sort -u -k 7)"
    text=""
    while IFS= read -r disk; do
        IFS=" " read -r filesystem _ total used free percentage mountpoint <<<"${disk}"

        device=$(sed 's|/dev||g;s|/mapper||g;s|^/||g' <<<"${filesystem}")
        left_label="${device} () - ${used} used, ${free} free"
        right_label="/ ${total}"
        free_width=$((WIDTH - ${#left_label} - ${#right_label} - 1))
        mountpoint=$(print_truncate "${mountpoint}" ${free_width} "start")
        left_label="${device} (${mountpoint}) - ${used} used, ${free} free"

        label=$(print_split "${WIDTH}" "${left_label}" "${right_label}")
        text+="${label}\n$(print_bar "${WIDTH}" "${percentage::-1}")\n"
    done <<<"${disks}"
    print_columns "Disk space" "${text::-2}"
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
function show_services_info() {
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

    statuses=()

    for key in "${!services[@]}"; do
        if [[ $(systemctl list-unit-files "${key}*" | wc -l) -gt 3 ]]; then
            status=$(systemctl show -p ActiveState --value "${key}")
            statuses+=("$(print_status "${services[${key}]}" "${status}")")
        fi
    done

    text=$(print_wrap "${WIDTH}" "${statuses[@]}")

    print_columns "Services" "${text}"
}

function show_docker_info() {
    #If there is no docker, do nothing
    #Suspend type command output by redirecting std pipe and error pipe to /dev/null
    if type docker >/dev/null 2>&1; then
        containers=$(docker ps -a --format "{{ .Names }}\t{{ .Status }}\t{{ .State }}")
        text=""
        if [[ -z "${containers}" ]]; then
            text+="no containers\n"
        else
            while IFS= read -r line; do
                IFS=$'\t' read -r name description state <<<"${line}"
                case ${state} in
                running) color="${CO}" ;;
                paused | restarting) color="${CW}" ;;
                exited | dead) color="${CE}" ;;
                *) color="${CN}" ;;
                esac
                text+="$(print_split "${WIDTH}" "${name}" "${color}${description,,}${CN}")\n"
            done <<<"${containers}"
        fi

        print_columns "Docker" "${text::-2}"
    fi

}

function show_updates_info() {
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
    text="$(print_color "${updates} available" ${updates} 1 50)"
    print_columns "Updates" "${text}"
}
function show_info() {
    show_system_info
    show_disk_info
    show_services_info
    show_docker_info
    show_updates_info

    #TODO: implement parallel execution, but save output order
    #For this we need save temporary output and divide all in smaller functions
    # show_system_info &
    # show_storage_info &
    # show_services_info &
    # show_docker_info &
    # show_updates_info &
    # wait

    # show_user_info
    # show_update_info
    # show_environment_info
}

#If no parameter is passed then start show_info
if [ -z "$1" ]; then
    show_info
fi
