#!/bin/bash
# desc:  Automated reboot cycle test with counter
# repo:  https://github.com/Timc21/bios_tools
# usage: ./reboot_go.sh [--start|--stop]

path="$(dirname "$(readlink -f "$0")")"
echo path=$path
job="@reboot sleep 180 && $path/reboot_go.sh"
reboot_cnt="$path/reboot_count.log"
cron=null

for arg in "$@"; do
	case "$arg" in
		--start) cron=true ;;
		--stop) cron=false ;;
	esac
done

if [ "$cron" == "true" ]; then
	crontab -l 2>/dev/null | grep -Fq "$job"
	if [ $? -ne 0 ]; then
		(crontab -l 2>/dev/null; echo "$job") | crontab -
	fi
elif [ "$cron" == "false" ]; then
	crontab -l | grep -v "$job" | crontab -
	echo "cron jib will be stop in next boot."
	exit 1
fi

if [ ! -f "$reboot_cnt" ]; then
	echo 0 > "$reboot_cnt"
else
	num=$(($(tail -n 1 "$reboot_cnt" | awk -F ':' '{print $NF}') + 1))
	date=$(date '+%Y-%m-%d %H:%M:%S')
	echo "$date : $num" >> "$reboot_cnt"
fi


echo "10 sec to reboot..."
sudo sleep 10
sudo reboot
