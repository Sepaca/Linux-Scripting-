#!/bin/bash
#Sebastian Patino 200528397

# Ensure script is run as root if is not run a root,
# remind the user to use it, and prevent future errors,
if [[ $EUID -ne 0 ]]; then
#EUID is user ID if is not equal to 0 , means that is not the root user,
# root user is EUID 0 that has permissions  
   echo "This script must be run as root, add sudo in Front of your Command" 
# if is not run as root, is going to ask to doit and  exit with and error
# so it does not continue with the scrip preventing future error
   exit 1
fi


# Set hostname to the appropiate one only if is not alreary set up,
# if it is set up I will skip

# retrive the current hostname 
currentHostname=$(hostname)
#is he current hostname is not the same run the next commands
if [[ "$currentHostname" != "autosrv" ]]; then
  echo "Setting hostname to :  autosrv "
# setting new host name and send the output to null to hide it for the user
  hostnamectl set-hostname autosrv  > /dev/null
# append the new hostname and the loopback address  in the etc/hosts 
  echo "127.0.1.1 autosrv" >> /etc/hosts
fi



# Check if hostname persists after reboot 
if [[ $(hostnamectl --static) != "autosrv" ]]; then
  echo "Failed to set hostname persistently"
  exit 1
fi


# Install software and configure so it does not give me errors if is not installs#
# Check if openssh-server is installed and install if not
# Install openssh-server if not already installed
if ! dpkg -l | grep -qw openssh-server; then
# dpkg -l list all packages on the system
# grep -qw to search the  package in the list.
  echo "Installing openssh-server..."
# update and intall the package
  apt-get update > /dev/null
  apt-get install -y openssh-server > /dev/null
fi

# Configure openssh-server to allow SSH key authentication and disable password authentication
echo "Configuring openssh-server..."
#using sed to replace the line containing Password...  change the yes 
# for a no and save it after 
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
#restart the service to apply the changes
systemctl restart sshd


# Install apache2 if not already installed
if ! dpkg -l | grep -qw apache2; then
  echo "Installing apache2..."
  apt-get update > /dev/null
  apt-get install -y apache2 > /dev/null
fi

# Configure apache2 to listen on port 80 (HTTP) and port 443 (HTTPS)
echo "Configuring apache2..."
# replace the default 80 to 0.0.0.0:80 
sed -i 's/Listen 80/Listen 0.0.0.0:80/' /etc/apache2/ports.conf
sed -i 's/Listen 443/Listen 0.0.0.0:443/' /etc/apache2/ports.conf
# enable ssl module for apache and restart 
a2enmod ssl > /dev/null
systemctl restart apache2

# Install squid if not already installed
if ! dpkg -l | grep -qw squid; then
  echo "Installing squid..."
  apt-get update > /dev/null
  apt-get install -y squid > /dev/null
fi

# Configure squid to listen on port 312
echo "Configuring squid..."
sed -i 's/http_port 3128/http_port 312/' /etc/squid/squid.conf
systemctl restart squid

# Install ufw if not already installed
if ! dpkg -l | grep -qw ufw; then
  echo "Installing ufw..."
  apt-get update > /dev/null
  apt-get install -y ufw > /dev/null
fi
echo "Software installation and configuration completed."

# Set static Ip and configure the ymal file with the new configuration
  # Check if current IP matches desired IP
  current_ip=$(hostname -I | awk '{print $1}')
if [[ "$current_ip" == "192.168.16.21" ]]; then
    echo "IP is already set to 192.168.16.21"  
else
  interface=$(ip route | awk '/default/ {print $5}')
  # forcing the ip configuration to be apply becuase if the user has 
# a different configuration that could interfire with the new configuration
# configuration will not worked, with more time I will save the original
# configuration with another name to have it save if it need to be restore later
  # Create netplan configuration file
  cat << EOF | sudo tee /etc/netplan/01-netcfg.yaml > /dev/null
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
      addresses: [192.168.16.21/24]
      routes:
        - to: 0.0.0.0/0
          via: 192.168.16.1
      nameservers:
        addresses: [192.168.16.1]
        search: [home.arpa, localdomain]
EOF

  # Apply netplan configuration and echo if the netplan command has an exit status success full
  sudo netplan apply > /dev/null
  fi
if [ $? -eq 0 ]; then
      echo "Network Configuration Successful"
  fi
# Configure UFW rules
ufw allow 22/tcp > /dev/null
ufw allow 80/tcp > /dev/null
ufw allow 443/tcp > /dev/null
ufw allow 3128/tcp > /dev/null
ufw --force enable > /dev/nul 
echo "UFW rules have been set up"

# Create user accounts
# List of users
users=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")

# Public key for 'dennis' variable
sudo_pub_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"

# Create users, set random passwords, and configure SSH keys
# using array to use the list of users in a for in loop.
for user in "${users[@]}"; do
    # Check if user already exists
    if id "$user" >/dev/null 2>&1; then
        echo "User $user already exists"
    else
        # Create user with home directory and bash shell
        sudo useradd -m -s /bin/bash $user

        # Generate SSH keys and ed25519  using the user variable 
# to create it for each user. sudo su to apply the comnand using each individual user 
        sudo su - $user -c "ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa >/dev/null 2>&1"
        sudo su - "$user" -c "ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519 >/dev/null 2>&1"

#copy the key in the authorized key file
        # Add public keys to authorized_keys file
        sudo su - $user -c "cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys"
        cat "/home/$user/.ssh/id_ed25519.pub" >> "/home/$user/.ssh/authorized_keys"
    fi
done

# Grant sudo access to 'dennis' and add provided public key
# suing a bariable where I save the key to make it more readable 
sudo usermod -aG sudo dennis
echo "$sudo_pub_key" | sudo tee -a /home/dennis/.ssh/authorized_keys >/dev/null 2>&1
echo "Sudo access granted to user 'dennis'."

# Verifying changes made 
echo "Verifying changes..."
#check the hostname was apply 
hostnamectl status | grep -q "autosrv" && echo "Hostname set correctly" || echo "Hostname not set correctly"

#netplan ip leases  | grep -q "192.168.16.21" && echo "Static IP set correctly" || echo "Static IP not set correctly"
for user in "${users[@]}"; do
  id -u $user >/dev/null 2>&1 && echo "User $user exists" || echo "User $user does not exist"
done
id -nG "dennis" | grep -qw "sudo" && echo "Dennis has sudo access" || echo "Dennis does not have sudo access"
