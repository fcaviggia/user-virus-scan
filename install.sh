#!/bin/sh
###############################################################################
# Automated Virus Scanning for User Sessions
#
# This script was written by Frank Caviggia
# Last update was 11 September 2016
#
# Author: Frank Caviggia (fcaviggia@gmail.com)
# Copyright: Frank Caviggia, (c) 2016
# License: GPLv3
# Description: Automated Virus Scan using clamscan and inotify for CentOS 7+, 
#              RHEL 7+, Fedora 19+
###############################################################################

# Check for root user
if [[ $EUID -ne 0 ]]; then
	tput setaf 1;echo -e "\033[1mPlease re-run this script as root!\033[0m";tput sgr0
	exit 1
fi

# Check Fedora or RHEL/CentOS
if [ -e /etc/redhat-release ]; then
	if [ $(grep -c "Fedora" /etc/redhat-release) -eq 0 ]; then
		if [ $(grep -c "CentOS\|Red Hat" /etc/redhat-release) -gt 0 ]; then
			# EPEL Repository required for RHEL/CentOS
			rpm -q epel-release &> /dev/null
			if [ $? -ne 0 ]; then
				tput setaf 1;echo -e "\033[1mEPEL Repository Required for CentOS or RHEL!\033[0m";tput sgr0
				echo -ne "\033[1mDo you want to try to install EPEL?\033[0m [y/n]: "
				while read a; do
					case "$a" in
					y|Y)	break;;
					n|N)	exit 2;;
					*)	echo -n "[y/n]: ";;
					esac
				done
				wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
				if [ $? -ne 0 ]; then
					tput setaf 1;echo -e "\033[1mEPEL Repository download failed!\033[0m";tput sgr0
					exit 3
				fi
				yum localinstall epel-release-latest-7*.rpm
			fi
		else
			tput setaf 1;echo -e "\033[1mScript is designed for Fedora, CentOS, or RHEL!\033[0m";tput sgr0
			exit 4
		fi
	fi
else
	tput setaf 1;echo -e "\033[1mScript is designed for Fedora, CentOS, or RHEL!\033[0m";tput sgr0
	exit 4
fi 

# Check RPM requirements

## Install inotify-tools to monitor directories
rpm -q inotify-tools &> /dev/null
if [ $? -ne 0 ]; then
	yum install inotify-tools -y
	if [ $? -ne 0 ]; then
		tput setaf 1;echo -e "\033[1mError: Install failed for inotify-tools!\033[0m";tput sgr0
		exit 5
	fi
fi

## Install clamav to virus scan files
rpm -q clamav &> /dev/null
if [ $? -ne 0 ]; then
        yum install clamav clamav-update -y
	if [ $? -ne 0 ]; then
		tput setaf 1;echo -e "\033[1mError: Install failed for clamav!\033[0m";tput sgr0
		exit 5
	fi
	sed -i '/Example/d' /etc/freshclam.conf
	/usr/bin/freshclam
fi

cat <<EOF > /usr/local/bin/virus-scan.sh
#!/bin/sh

LOGFILE="\$HOME/.virus-scan.log"
SCANDIR="\$HOME \$(find \$HOME -maxdepth 1 -type d | grep -i 'desktop\|downloads\|documents\|pictures')"

touch \$LOGFILE

inotifywait -q -m -e create -e move --format '%w%f' \$SCANDIR | while read FILE; do
	date &>> \$LOGFILE
	echo "File \$FILE has been detected. Scanning it for viruses now ..." &>> \$LOGFILE
	# Sophos Free 
        if [ -x /usr/bin/sweep ]; then
                /usr/bin/sweep \$FILE &>> \$LOGFILE
        fi
        # ClamAV Scan
	clamscan --scan-archive=yes --scan-pdf=yes --scan-elf=yes --scan-ole2=yes --remove=yes \$FILE &>> \$LOGFILE
	if [ \$? -eq 1 ]; then
		notify-send 'Virus Found' "\$(basename \$FILE) has been removed for your safety." --icon=dialog-warning
	fi
	echo &>> \$LOGFILE
	SCANDIR="\$HOME \$(find \$HOME -maxdepth 1 -type d | grep -i 'desktop\|downloads\|documents\|pictures')"
done

exit 0
EOF
chmod 0555 /usr/local/bin/virus-scan.sh

cat <<EOF > /etc/xdg/autostart/virus-scan.desktop
[Desktop Entry]
Name=Virus Scan
Exec=sh -c "/usr/local/bin/virus-scan.sh &"
Comment=Virus Scan Utility
Type=Application
Encoding=UTF-8
Version=1.0
MimeType=application/shell;
Categories=Utility;
X-GNOME-Autostart-enabled=true
StartupNotify=false
Terminal=false
EOF
chmod 0444 /etc/xdg/autostart/virus-scan.desktop

exit 0
