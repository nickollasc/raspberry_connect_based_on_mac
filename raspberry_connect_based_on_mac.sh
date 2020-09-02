#!/bin/bash
# connect to raspberry doing a network scanner looking for your mac
# Usage: raspi_connect.sh [X] 
# Depends: x2x package installed only in raspberry

# install packages if it not installed
if ! type nmap &> /dev/null || ! type sshpass &> /dev/null; then
  test -e /etc/debian_version && sudo apt install -y nmap sshpass || sudo yum install -y nmap sshpass
fi

raspi_mac='AE:C7:12:C4:8E:FF'
raspi_passwd='putRaspberryPasswordHere'

function get_raspi_ip {
  lan_ip=$( ip route | awk '/default/ { split( $3, a, "." ); print a[1]"."a[2]"."a[3] }' )	  # get lan ip like 192.168.0

  sudo nmap -sn ${lan_ip}.1-254									| # ping scan for a ip range 
  egrep -o '[[:digit:].]{3,}$| [[:xdigit:]:]{6,}'						| # filter only IP and MAC address
  awk 'BEGIN{ m=0 } { if ( $1 ~ /^[[:digit:].]{3,}/ ) m++; print m, $0 }'			| # create a relationship between IP and MAC 
  awk '{ a[$1] = a[$1] FS substr( $0, index( $0,$2 ) ) } END{ for( i in a ) print i a[i] }'	| # print IP and MAC on same line
  awk '$3 == "'$raspi_mac'" { print $2 }'							  # get raspberry IP based on MAC
}

function set_ssh_to_use_an_already_established_connection {
  if [ ! -e ~/.ssh/config ];then
	cat > ~/.ssh/config <<-EOF
	ControlMaster auto
	ControlPath ~/.ssh/control:%h:%p:%r
	EOF
  fi
}

raspi_ip=$( get_raspi_ip ) 

test -z $raspi_ip && echo erro: IP not found for this Mac: $raspi_mac && exit

if [ "$1" == "X" ]; then 
  # connect to X11 on raspberry
  if [ -e ~/.ssh/pi_rsa ];then
    ssh -i ~/.ssh/pi_rsa -o StrictHostKeyChecking=no -X pi@$raspi_ip x2x -north -north -to :0 &
  else
    sshpass -p "$raspi_passwd" ssh -o StrictHostKeyChecking=no -X pi@$raspi_ip x2x -north -north -to :0 &
  fi
  sleep 2 
  # send a command to raspberry changing keyboard layout
  set_ssh_to_use_an_already_established_connection
  ssh -o StrictHostKeyChecking=no -X pi@$raspi_ip DISPLAY=:0 'setxkbmap pt'
  reset
  echo 'X11 raspberry connection ready!'
else 
  # connect to raspberry
  if [ -e ~/.ssh/pi_rsa ];then
    ssh -i ~/.ssh/pi_rsa -o StrictHostKeyChecking=no pi@$raspi_ip
  else
    sshpass -p "$raspi_passwd" ssh -o StrictHostKeyChecking=no pi@$raspi_ip 
  fi
fi
