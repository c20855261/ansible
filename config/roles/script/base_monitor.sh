#!/bin/bash
TIME=$(date +"%Y-%m-%d %H:%M")
TOKEN=""
CHAT_ID=""
#CHAT_ID=""
ALERT_URL="https://api.telegram.org/bot${TOKEN}/sendMessage"
ENVIR="prod"
HOST=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)
   
CPU_THRESHOLD=80
MEM_THRESHOLD=80
   
SAMPLE_INTERVAL=30  #採樣秒數
HIGH_LOAD_DURATION=180 #持續時間段
SAMPLES=$((HIGH_LOAD_DURATION / SAMPLE_INTERVAL))
   
send_alert() {
    local MESSAGE=$1
    curl -s -X POST $ALERT_URL \
        -d chat_id="$CHAT_ID" \
        -d text="時間：${TIME}%0A環境：${ENVIR}%0A主機：${HOSTNAME}%0A位址：${HOST}%0A狀況：${MESSAGE}" \
        -d parse_mode="HTML"
}  
   
monitor() {
    local cpu_high_count=0
    local mem_high_count=0
   
    for ((i=0; i<$SAMPLES; i++)); do
        local cpu_usage=$(mpstat 1 1 | awk '/Average:/ {printf "%.2f", 100 - $12}')
        local mem_usage=$(free | awk '/Mem:/ {printf "%.2f", ($3/$2) * 100}')
   
        (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )) && ((cpu_high_count++))
        (( $(echo "$mem_usage > $MEM_THRESHOLD" | bc -l) )) && ((mem_high_count++))
   
        sleep $SAMPLE_INTERVAL
    done
   
    if ((cpu_high_count == SAMPLES)); then
        send_alert "持續 3/m CPU使用率超過 ${CPU_THRESHOLD}%"
    fi
    if ((mem_high_count == SAMPLES)); then
        send_alert "持續 3/m 記憶體使用率超過 ${MEM_THRESHOLD}%"
    fi
}  
   
# Check Disk usage       
check_disk_usage() {
  local path=$1
  local threshold=$2
  local usage=$(df -h "$path" | awk 'NR==2{gsub(/%/,"",$5); print $5}')
  local used=$(df -h "$path" | awk 'NR==2{print $3}')
  local avail=$(df -h "$path" | awk 'NR==2{print $4}')
   
if [ "$usage" -gt "$threshold" ]; then
  send_alert "* High Disk Usage for $path * ${usage}% (Used: ${used}, Available: ${avail})"                                                                       
fi 
}  
   
if [ -d "/data" ]; then
  check_disk_usage "/data" 75
else
  check_disk_usage "/" 75
fi 
   
monitor
