# Sebastian Patino
# Assignment 3
# Shebang line to define the script interpreter for execution, in this case, Bash.

# The names and IP addresses of the target machines
# Declaring variables to hold target hostnames and IPs.
TARGET1_NAME=target1-mgmt
TARGET1_IP=172.16.1.10
TARGET2_NAME=target2-mgmt
TARGET2_IP=172.16.1.11

# Change system name and IP for target1-mgmt
# Beginning of a block of commands for configuring the first target.
ssh -oStrictHostKeyChecking=no remoteadmin@$TARGET1_IP << 'ENDSSH'
# SSH connection to target1 with disabled host key checking.

sudo hostname loghost
# Setting the hostname to "loghost" on target1.

interface=$(ip route | awk '/default/ {print $5}')
# Using "ip route" to determine the default interface, assigning it to the variable "interface".

sudo ip addr add 192.168.1.3/24 dev $interface
# Adding a new IP address 192.168.1.3/24 to the detected interface.

echo "192.168.1.4 webhost" | sudo tee -a /etc/hosts
# Appending the webhost's IP address to target1's /etc/hosts file.

sudo apt-get update && sudo apt-get install -y ufw
# Updating the package list and installing the Uncomplicated Firewall (ufw) package.

sudo ufw allow from 172.16.1.0/24 to any port 514 proto udp
# Configuring the firewall to allow UDP traffic on port 514 from the specified subnet.

sudo sed -i 's/#module(load="imudp")/module(load="imudp")/g' /etc/rsyslog.conf
# Enabling the UDP input module in the rsyslog configuration.

sudo sed -i 's/#input(type="imudp" port="514")/input(type="imudp" port="514")/g' /etc/rsyslog.conf
# Enabling the UDP input on port 514 in the rsyslog configuration.

sudo systemctl restart rsyslog
# Restarting the rsyslog service to apply changes.
ENDSSH
# End of the SSH session for target1.

# Change system name and IP for target2-mgmt
# Beginning of a block of commands for configuring the second target.
ssh -oStrictHostKeyChecking=no remoteadmin@$TARGET2_IP << 'ENDSSH'
# SSH connection to target2 with disabled host key checking.

sudo hostname webhost
# Setting the hostname to "webhost" on target2.

interface=$(ip route | awk '/default/ {print $5}')
# Using "ip route" to determine the default interface, assigning it to the variable "interface".

sudo ip addr add 192.168.1.4/24 dev $interface
# Adding a new IP address 192.168.1.4/24 to the detected interface.

echo "192.168.1.3 loghost" | sudo tee -a /etc/hosts
# Appending the loghost's IP address to target2's /etc/hosts file.

sudo apt-get update && sudo apt-get install -y ufw apache2
# Updating the package list and installing the Uncomplicated Firewall (ufw) and Apache2 web server packages.

sudo ufw allow 80/tcp
# Configuring the firewall to allow TCP traffic on port 80 (HTTP).

sudo systemctl enable apache2
# Enabling the Apache2 service to start at boot.

sudo systemctl start apache2
# Starting the Apache2 service.

echo '*.* @loghost' | sudo tee -a /etc/rsyslog.conf
# Configuring rsyslog to send all logs to the "loghost".

sudo systemctl restart rsyslog
# Restarting the rsyslog service to apply changes.
ENDSSH
# End of the SSH session for target2.

# Update /etc/hosts file on NMS
# Adding loghost and webhost to the local machine's /etc/hosts file.
echo "192.168.1.3 loghost" | sudo tee -a /etc/hosts
echo "192.168.1.4 webhost" | sudo tee -a /etc/hosts

# Verify setup
# Attempt to retrieve the web page from "webhost" to verify its availability.
if wget -qO- http://webhost &> /dev/null; then
    echo "Apache server on webhost is responding correctly."
else
    echo "Cannot reach Apache server on webhost."
    exit 1
# If unavailable, exit with code 1.
fi

# Attempt to retrieve logs from "webhost" on "loghost" to verify logging.
if ssh -oStrictHostKeyChecking=no remoteadmin@loghost grep webhost /var/log/syslog &> /dev/null; then
    echo "Logs from webhost are present on loghost."
else
    echo "Cannot retrieve logs from webhost on loghost."
    exit 1
# If logs are not found, exit with code 1.
fi

echo "Configuration update succeeded"
# Success message if both verification steps are successful.
exit 0
# Exit with code 0 indicating successful execution.
