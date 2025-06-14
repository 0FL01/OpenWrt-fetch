#!/bin/sh

# Цветовые коды
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PURPLE='\033[35m'
CYAN='\033[36m'
WHITE='\033[37m'
NC='\033[0m' # No Color

print_banner() {
    printf "\033[1;1H\033[2J" # Очистка экрана
    printf "${RED}"
    cat << 'EOF'
    ██████╗ ██████╗ ███████╗███╗   ██╗██╗    ██╗██████╗ ████████╗
   ██╔═══██╗██╔══██╗██╔════╝████╗  ██║██║    ██║██╔══██╗╚══██╔══╝
   ██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║ █╗ ██║██████╔╝   ██║   
   ██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║███╗██║██╔══██╗   ██║   
   ╚██████╔╝██║     ███████╗██║ ╚████║╚███╔███╔╝██║  ██║   ██║   
    ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚══╝╚══╝ ╚═╝  ╚═╝   ╚═╝   
EOF
    printf "${NC}\n"
}

get_cpu_temp() {
    local temp_file="/sys/class/thermal/thermal_zone0/temp"
    [ ! -f "$temp_file" ] && printf "${YELLOW}N/A${NC}" && return
    
    local temp=$(cat "$temp_file")
    local temp_c=$((temp/1000))
    
    if [ $temp_c -ge 65 ]; then
       printf "${RED}%d°C${NC}" "$temp_c"
    else
       printf "${GREEN}%d°C${NC}" "$temp_c"
    fi
}

get_uptime() {
    local uptime_sec=$(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
    local days=$((uptime_sec / 86400))
    local hours=$(((uptime_sec % 86400) / 3600))
    local minutes=$(((uptime_sec % 3600) / 60))
    
    if [ $days -gt 0 ]; then
        printf "%d дней %d часов %d минут" $days $hours $minutes
    elif [ $hours -gt 0 ]; then
        printf "%d часов %d минут" $hours $minutes
    else
        printf "%d минут" $minutes
    fi
}

get_memory_info() {
    awk '/MemTotal/{total=$2} /MemFree/{free=$2} /Buffers/{buffers=$2} /Cached/{cached=$2} 
         END{
             used_kb = total - free - buffers - cached
             used_mb = int(used_kb/1024)
             total_mb = int(total/1024)
             printf "%dМБ/%dМБ", used_mb, total_mb
         }' /proc/meminfo
}

get_load_avg() {
    cut -d' ' -f1-3 /proc/loadavg
}

get_disk_usage() {
    df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}'
}

print_system_info() {
    local current_date=$(date +'%Y-%m-%d %H:%M:%S')
    local uptime=$(get_uptime)
    local ext_ip=$(wget -qO- --timeout=3 ipinfo.io/ip 2>/dev/null || echo 'N/A')
    local cpu_model=$(awk -F': ' '/model name|system type|cpu model/{print $2; exit}' /proc/cpuinfo | head -1 || echo 'Unknown')
    local cpu_temp=$(get_cpu_temp)
    local cores=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "?")
    local architecture=$(uname -m)
    local kernel=$(uname -r)
    local processes=$(ps | wc -l)
    local disk_info=$(get_disk_usage)
    local mem_info=$(get_memory_info)
    local load_avg=$(get_load_avg)
    local board=$(grep OPENWRT_BOARD /etc/os-release | cut -d'"' -f2)
    local version=$(grep VERSION= /etc/os-release | cut -d'"' -f2)

    printf "\n"
    printf "   ${WHITE}%-15s${YELLOW}%-35s${NC}\n" "Дата:" "📆 $current_date"
    printf "   ${WHITE}%-15s${YELLOW}%-35s${NC}\n" "Время работы:" "🕐 $uptime"
    printf "   ${WHITE}%-15s${RED}%-35s${NC}\n" "OpenWrt:" "$version"
    printf "   ${WHITE}%-15s${RED}%-35s${NC}\n" "Плата:" "$board"
    printf "   ${WHITE}%-15s${RED}%-35s${NC}\n" "Внешний IP:" "$ext_ip"
    printf "   ${WHITE}%-15s${GREEN}%-35s${NC}\n" "CPU:" "$cpu_model"
    printf "   ${WHITE}%-15s${GREEN}%-35s${NC}\n" "Ядро:" "$kernel"
    printf "   ${WHITE}%-15s${GREEN}%-35s${NC}\n" "Архитектура:" "$architecture"
    printf "   ${WHITE}%-15s🌡 %-35s${NC}\n" "Температура:" "$cpu_temp"
    printf "   ${WHITE}%-15s${RED}%-35s${NC}\n" "Ядра CPU:" "$cores"
    printf "   ${WHITE}%-15s${RED}%-35s${NC}\n" "Процессы:" "$processes"
    printf "   ${WHITE}%-15s${PURPLE}%-35s${NC}\n" "Диск:" "💾 $disk_info"
    printf "   ${WHITE}%-15s${PURPLE}%-35s${NC}\n" "Память:" "🧠 $mem_info"
    printf "   ${WHITE}%-15s${PURPLE}%-35s${NC}\n" "Нагрузка:" "📈 $load_avg"
    printf "\n${NC}"
}

# Главный запуск
print_banner
print_system_info 