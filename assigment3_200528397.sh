#!/bin/bash
#Sebastian Patino
# Assigment 3

# The names and IP addresses of the target machines
TARGET1_NAME=target1-mgmt
TARGET1_IP=172.16.1.10
TARGET2_NAME=target2-mgmt
TARGET2_IP=172.16.1.11

# Change system name and IP for target1-mgmt
ssh -oStrictHostKeyChecking=no remoteadmin@$TARGET1_IP << 'ENDSSH'
sudo hostname loghost
interface=$(ip route | awk '/default/ {print $5}')
sudo ip addr add 192.168.1.3/24 dev $interface
echo "192.168.1.4 webhost" | sudo tee -a /etc/hosts
sudo apt-get update && sudo apt-get install -y ufw
sudo ufw allow from 172.16.1.0/24 to any port 514 proto udp
sudo sed -i 's/#module(load="imudp")/module(load="imudp")/g' /etc/rsyslog.conf
sudo sed -i 's/#input(type="imudp" port="514")/input(type="imudp" port="514")/g' /etc/rsyslog.conf
sudo systemctl restart rsyslog
ENDSSH

# Change system name and IP for target2-mgmt
ssh -oStrictHostKeyChecking=no remoteadmin@$TARGET2_IP << 'ENDSSH'
sudo hostname webhost
interface=$(ip route | awk '/default/ {print $5}')
sudo ip addr add 192.168.1.4/24 dev $interface
echo "192.168.1.3 loghost" | sudo tee -a /etc/hosts
sudo apt-get update && sudo apt-get install -y ufw apache2
sudo ufw allow 80/tcp
sudo systemctl enable apache2
sudo systemctl start apache2
echo '*.* @loghost' | sudo tee -a /etc/rsyslog.conf
sudo systemctl restart rsyslog
ENDSSH

# Update /etc/hosts file on NMS
echo "192.168.1.3 loghost" | sudo tee -a /etc/hosts
echo "192.168.1.4 webhost" | sudo tee -a /etc/hosts

# Verify setup
if wget -qO- http://webhost &> /dev/null; then
    echo "Apache server on webhost is responding correctly."
else
    echo "Cannot reach Apache server on webhost."
    exit 1
fi

if ssh -oStrictHostKeyChecking=no remoteadmin@loghost grep webhost /var/log/syslog &> /dev/null; then
    echo "Logs from webhost are present on loghost."
else
    echo "Cannot retrieve logs from webhost on loghost."
    exit 1
fi

echo "Configuration update succeeded"
exit 0
