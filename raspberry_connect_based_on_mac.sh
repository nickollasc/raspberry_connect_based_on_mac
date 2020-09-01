#!/bin/bash
# connect to raspberry doing a network scanner looking for your mac
# Usage: raspi_connect.sh [X] 
# Depends: nmap, sshpass, ssh

if ! type nmap &> /dev/null; then
  test -e /etc/debian_version && sudo apt install -y nmap || sudo yum install -y nmap
fi

raspi_mac='DC:A6:32:3C:4C:C0'
raspi_passwd='putRaspberryPasswordHere'

function get_raspi_ip {
  lan_ip=$( ip route | awk '/default/ { split( $3, a, "." ); print a[1]"."a[2]"."a[3] }' )	  # get lan ip like 192.168.0

  sudo nmap -sn ${lan_ip}.1-254									| # ping scan for a ip range 
  egrep -o '[[:digit:].]{3,}$| [[:xdigit:]:]{6,}'						| # filter only IP and MAC address
  awk 'BEGIN{ m=0 } { if ( $1 ~ /^[[:digit:].]{3,}/ ) m++; print m, $0 }'			| # create a relationship between IP and MAC 
  awk '{ a[$1] = a[$1] FS substr( $0, index( $0,$2 ) ) } END{ for( i in a ) print i a[i] }'	| # print IP and MAC on same line
  awk '$3 == "'$raspi_mac'" { print $2 }'							  # get raspberry IP based on MAC
}

if [ "$1" == "X" ] ; then 
  raspi_ip=$( get_raspi_ip )
  sshpass -p "$raspi_passwd" ssh -o StrictHostKeyChecking=no -X pi@$raspi_ip x2x -north -north -to :0 &	# connect to raspberry
  sleep 1 
  ssh -o StrictHostKeyChecking=no -X pi@$raspi_ip DISPLAY=:0 'setxkbmap pt'	# send a command to raspberry changing keyboard layout
  reset
  echo 'raspi connection ready!'
elif [ -e ~/.ssh/pi_rsa ];then
  test $# -eq 0 && ssh -i ~/.ssh/pi_rsa -o StrictHostKeyChecking=no pi@$( get_raspi_ip ) || ssh -i ~/.ssh/pi_rsa -o StrictHostKeyChecking=no pi@$1
else 
  ssh -o StrictHostKeyChecking=no pi@$( get_raspi_ip )
fi
