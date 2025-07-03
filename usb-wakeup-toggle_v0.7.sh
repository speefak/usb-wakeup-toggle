#!/bin/bash
# name          : usb-wake-toggle
# desciption    : configure usb device for wakeup
# autor         : speefak ( itoss@gmx.de )
# licence       : (CC) BY-NC-SA
# version       : 0.7
# notice        : erweitert mit Dialogauswahl und Udev-Funktion
# infosource    : ChatGPT

#------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#-------------------------------------------------------------------------------------------------------------------------------------------
RequiredPackets="dialog usbutils"

CheckMark=$'\033[0;32m✔\033[0m'
CrossMark=$'\033[0;31m✖\033[0m'

declare -A DeviceMap

#------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
###########################################   define functions   ###########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------------------------------------------

load_color_codes () {
	Black='\033[0;30m' && DGray='\033[1;30m'
	LRed='\033[0;31m' && Red='\033[1;31m'
	LGreen='\033[0;32m' && Green='\033[1;32m'
	LYellow='\033[0;33m' && Yellow='\033[1;33m'
	LBlue='\033[0;34m' && Blue='\033[1;34m'
	LPurple='\033[0;35m' && Purple='\033[1;35m'
	LCyan='\033[0;36m' && Cyan='\033[1;36m'
	LLGrey='\033[0;37m' && White='\033[1;37m'
	Reset='\033[0m'
	BG='\033[47m'; FG='\033[0;30m'
}

check_for_required_packages () {
	InstalledPacketList=$(dpkg -l | grep ii | awk '{print $2}' | cut -d ":" -f1)
	for Packet in $RequiredPackets; do
		if [[ -z $(grep -w "$Packet" <<< $InstalledPacketList) ]]; then
			MissingPackets="$MissingPackets $Packet"
		fi
	done
	if [[ -n $MissingPackets ]]; then
		printf "missing packets: $Red$MissingPackets$Reset \n"
		read -e -p "install required packets? (Y/N) " -i "Y" InstallMissingPackets
		if [[ $InstallMissingPackets =~ ^[Yy]$ ]]; then
			sudo apt update && sudo apt install -y $MissingPackets || exit 1
		else
			printf "programm error: $Red missing packets : $MissingPackets $Reset \n\n"
			exit 1
		fi
	else
		printf "$Green all required packets detected $Reset\n"
	fi
}

get_usb_device_list () {
	USBDeviceList=()
	DeviceIndex=0
	USBDeviceAbsolutePathList=$(grep -E "idVendor|idProduct" <<< $(find $(readlink -f /sys/bus/usb/devices/*)) | sed 's/\/\(idProduct\|idVendor\)$//' | sort | uniq )
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	for i in $USBDeviceAbsolutePathList; do
		idVendor=$(cat "$i/idVendor" 2>/dev/null)
		idProduct=$(cat "$i/idProduct" 2>/dev/null)
		USBWakeupStatus=$(printf "%8s" "$(cat "$i/power/wakeup" 2>/dev/null || echo "unknown")")
		DeviceName=$(lsusb | grep "$idVendor:$idProduct" | sed -n 's/.*ID [0-9a-f]\{4\}:[0-9a-f]\{4\} \(.*\)/\1/p')
		# fallback name
		if [[ -z $DeviceName ]]; then DeviceName="unknown device"; fi
		Entry="[$USBWakeupStatus] ${DeviceName}"
		USBDeviceList+=("$DeviceIndex" "$Entry" "off")
		DeviceMap[$DeviceIndex]="$i"
		((DeviceIndex++))
	done
	IFS=$SAVEIFS
}

#get_usb_device_list
#echo ${!DeviceMap[@]}
#printf '%s\n' "${DeviceMap[@]}"
#exit

create_dialog_menu_and_get_selection () {
	get_usb_device_list
	if [ ${#USBDeviceList[@]} -eq 0 ]; then
		echo "Keine USB-Geräte gefunden."
		exit 1
	fi
	cmd=(dialog --separate-output --checklist "Wähle USB-Geräte zum Wakeup-Umschalten aus:" 20 80 12)
	choices=$("${cmd[@]}" "${USBDeviceList[@]}" 2>&1 >/dev/tty)
	clear
	for choice in $choices; do
		DevicePath=${DeviceMap[$choice]}
		WakeFile="$DevicePath/power/wakeup"
		[[ ! -e $WakeFile ]] && echo "❌ Wakeup nicht unterstützt: $DevicePath" && continue
		status=$(cat "$WakeFile")
		if [[ $status == "enabled" ]]; then
			echo "➤ $DevicePath: disabling wakeup"
			echo "disabled" | sudo tee "$WakeFile" >/dev/null
		else
			echo "➤ $DevicePath: enabling wakeup"
			echo "enabled" | sudo tee "$WakeFile" >/dev/null
		fi
		echo
	done
}

generate_udev_rules_for_selected () {
	echo
	read -p "Möchtest du passende udev-Regeln für die Auswahl erstellen? (Y/N) " -i "N" UdevAnswer
	[[ $UdevAnswer =~ ^[Yy]$ ]] || return

	rules=""
	for idx in $choices; do
		DevicePath=${DeviceMap[$idx]}
		idVendor=$(cat "$DevicePath/idVendor")
		idProduct=$(cat "$DevicePath/idProduct")
		rules+="SUBSYSTEM==\"usb\", ATTR{idVendor}==\"$idVendor\", ATTR{idProduct}==\"$idProduct\", ATTR{power/wakeup}=\"enabled\"\n"
	done
	echo -e "\n autoload enabled: /etc/udev/rules.d/99-usb-wakeup.rules\n"
	cat "/etc/udev/rules.d/99-usb-wakeup.rules"
	echo -e "$rules"
}

#------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   start script   #############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

	if [[ "$(id -u)" -ne 0 ]]; then echo "Bitte als root ausführen."; exit 1; fi

	load_color_codes
	check_for_required_packages
	create_dialog_menu_and_get_selection
	generate_udev_rules_for_selected

#------------------------------------------------------------------------------------------------------------

exit 0

#------------------------------------------------------------------------------------------------------------

