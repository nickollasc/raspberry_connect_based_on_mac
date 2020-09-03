#!/bin/bash
# connect to raspberry doing a network scanner looking for your mac
# Usage: raspi_connect.sh [X] 
# Depends: x2x package installed only in raspberry

declare -A info=( ['mac']='EE:C7:12:C4:8E:FF' ['user']='pi' ['passwd']='123456' )	# raspberry info

test $( whoami ) != "root" && echo -e "[erro]: only root can execute this script\ntry: sudo $0" && exit

if ! type nmap &> /dev/null || ! type sshpass &> /dev/null; then # install packages if it not installed
  test -e /etc/debian_version && sudo apt install -y nmap sshpass || sudo yum install -y nmap sshpass
fi

function get_raspi_ip {
  lan_ip=$( ip route | awk '/default/ { split( $3, a, "." ); print a[1]"."a[2]"."a[3] }' )	  # get lan ip like 192.168.0

  nmap -sn ${lan_ip}.1-254									| # ping scan for a ip range 
  egrep -o '[[:digit:].]{3,}$| [[:xdigit:]:]{6,}'						| # filter only IP and MAC address
  awk 'BEGIN{ m=0 } { if ( $1 ~ /^[[:digit:].]{3,}/ ) m++; print m, $0 }'			| # create a relationship between IP and MAC 
  awk '{ a[$1] = a[$1] FS substr( $0, index( $0,$2 ) ) } END{ for( i in a ) print i a[i] }'	| # print IP and MAC on same line
  awk '$3 == "'$1'" { print $2 }'								  # get raspberry IP based on MAC
}

function change_keyboard_layout_on_remote_X11 {
  sleep 2 
  sshpass -p "${info['passwd']}" ssh -o StrictHostKeyChecking=no -X ${info['user']}@$ip DISPLAY=:0 'setxkbmap pt' &
  reset
  echo 'X11 raspberry connection ready, move mouse pointer to other Monitor/TV!'
}

ip=$( get_raspi_ip ${info['mac']} )	# get raspberry IP passing mac as parameter

test -z $ip && echo erro: IP not found for this Mac: ${info['mac']} && exit

if [ "$1" == "X" ] && [ -e ~/.ssh/pi_rsa ]; then # connect to X11 on raspberry using ssh key
  ssh -i ~/.ssh/pi_rsa -o StrictHostKeyChecking=no -X ${info['user']}@$ip x2x -north -north -to :0 &
  change_keyboard_layout_on_remote_X11

elif [ "$1" == "X" ] && [ ! -e ~/.ssh/pi_rsa ]; then # connect to X11 on raspberry using sshpass
  sshpass -p "${info['passwd']}" ssh -o StrictHostKeyChecking=no -X ${info['user']}@$ip x2x -north -north -to :0 &
  change_keyboard_layout_on_remote_X11

elif [ -e ~/.ssh/pi_rsa ];then # connect to raspberry and use terminal using ssh key
  ssh -i ~/.ssh/pi_rsa -o StrictHostKeyChecking=no ${info['user']}@$ip

else # connect to raspberry and use terminal using sshpass
  sshpass -p "${info['passwd']}" ssh -o StrictHostKeyChecking=no ${info['user']}@$ip 
fi
