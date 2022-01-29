#!/bin/bash
# connect to raspberry doing a network scanner looking for your mac
# Usage: raspi_connect.sh [X] [4] 
# Depends: x2x package installed only in raspberry

declare -A info=( ['device']='pi-zero' ['mac']='B1:37:EC:DD:AA:C6' ['user']='pi' ['passwd']='123456' ) # raspberry pi zero info
# raspberry pi 4 info - will connect only if 4 was the last param passed to script
test "${@: -1}" == 4 && declare -A info=( ['device']='pi4' ['mac']='DC:A6:32:3C:4C:C0' ['user']='pi' ['passwd']='123456' )

if ! type nmap &> /dev/null || ! type sshpass &> /dev/null || ! type sudo &> /dev/null; then # install packages if it not installed
  test -e /etc/debian_version && sudo apt install -y nmap sshpass sudo || sudo yum install -y nmap sshpass sudo
fi

echo -e "\ntrying to connect to: ${info['device']}\n"

function check_and_set_last_ip { # if last known ip has the defined mac address use it
  ip=
  if [ -n "$ip" ]; then

    # check if destination mac of ip variable is equal to target mac
    for i in {1..3};do
      test "$( nc -z $ip 22 | awk '{ print $NF }' )" != "REACHABLE" && nc -z $ip 22
    done 
    test $( ip neighbor | grep $ip |  awk '{ print toupper( $(NF-1) ) }' ) == ${info['mac']} &> /dev/null && echo $ip > /tmp/${info['device']} 
  fi
}

function get_raspi_ip {
  lan_ip=$( ip route | awk '/default/ { split( $3, a, "." ); print a[1]"."a[2]"."a[3] }' )	  # get lan ip like 192.168.0

  sudo nmap -sn ${lan_ip}.2-254									| # ping scan for a ip range 
  egrep -o '[[:digit:].()]{3,}$| [[:xdigit:]:]{6,}'						| # filter only IP and MAC address
  sed 's/[()]//g'										| # remove () chars from IPs	
  awk 'BEGIN{ m=0 } { if ( $1 ~ /^[[:digit:].]{3,}/ ) m++; print m, $0 }'			| # create a relationship between IP and MAC 
  awk '{ a[$1] = a[$1] FS substr( $0, index( $0,$2 ) ) } END{ for( i in a ) print i a[i] }'	| # print IP and MAC on same line
  awk '$3 == "'${info['mac']}'" { print $2 }'							| # get raspberry IP based on MAC
  tee /tmp/${info['device']}									  # save IP on cache file

  sed -i "s/^  ip=.*/  ip=$( cat /tmp/${info['device']} )/" $( whereis $0 | awk '{ print $NF }' ) # save ip on this script
}

function change_keyboard_layout_on_remote_X11 {
  sleep 2 
  sshpass -p "${info['passwd']}" ssh -o StrictHostKeyChecking=no -X ${info['user']}@$ip DISPLAY=:0 'setxkbmap pt' &
  reset
  echo 'X11 raspberry connection ready, move mouse pointer to other Monitor/TV!'
}

check_and_set_last_ip

# get raspberry IP from cache file OR from function 
test -e /tmp/${info['device']} && ip=$( cat /tmp/${info['device']} ) || ip=$( get_raspi_ip )

test -s $ip && echo erro: IP not found for this Mac: ${info['mac']} && rm -f /tmp/${info['device']} && exit

if [ "$1" == "X" ] && [ -e ~/.ssh/pi_rsa ]; then # connect to X11 on raspberry using ssh key
  rm -f /tmp/control*
  ssh -i ~/.ssh/pi_rsa -o StrictHostKeyChecking=no -X ${info['user']}@$ip x2x -north -to :0 &
  change_keyboard_layout_on_remote_X11

elif [ "$1" == "X" ] && [ ! -e ~/.ssh/pi_rsa ]; then # connect to X11 on raspberry using sshpass
  rm -f /tmp/control*
  sshpass -p "${info['passwd']}" ssh -o StrictHostKeyChecking=no -X ${info['user']}@$ip x2x -north -to :0 &
  change_keyboard_layout_on_remote_X11

elif [ -e ~/.ssh/pi_rsa ];then # connect to raspberry and use terminal using ssh key
  ssh -i ~/.ssh/pi_rsa -o StrictHostKeyChecking=no ${info['user']}@$ip

else # connect to raspberry and use terminal using sshpass
  sshpass -p "${info['passwd']}" ssh -o StrictHostKeyChecking=no ${info['user']}@$ip 
fi
