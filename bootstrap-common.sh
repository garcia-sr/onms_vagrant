#!/bin/bash

# Designed for Rocky Linux 8/9 and ARM architecture
# Author: Alejandro Galue
# Updated and maintained: Sergio Garcia <sgarcia@opennms.com>

# Main externally configurable variables with defaults

JAVA_VERSION=${1-11};
TIMEZONE=${2-America/New_York};

# Update base OS

sudo yum update -y -q

# Install basic packages and dependencies

if ! rpm -qa | grep -q epel-release; then
  echo "Installing basic packages..."
  sudo yum install -y -q epel-release
  sudo yum install -y -q haveged net-tools vim-enhanced wget curl git jq unzip wsmancli
else
  echo "Basic packages are already installed!"
fi

# Install Monitoring tools

if ! rpm -qa | grep -q net-snmp; then
  echo "Installing monitoring tools..."
  sudo yum install -y -q net-snmp net-snmp-utils dstat htop sysstat
else
  echo "Monitoring tools are already installed!"
fi

# Seting up timezone

if ! grep --quiet EST /etc/localtime; then
  echo "Setting up TIMEZONE to $TIMEZONE..."
  sudo rm -f /etc/localtime
  sudo ln -s /usr/share/zoneinfo/$TIMEZONE /etc/localtime
else
  echo "Timezone was already configured!"
fi

# Install Java (not strictly necessary, but useful in order to have the latest version)

if [ "$JAVA_VERSION" == "8" ]; then
  if ! rpm -qa | grep -q java-1.8.0-openjdk-devel; then
    echo "Installing OpenJDK $JAVA_VERSION..."
    sudo yum install -y -q java-1.8.0-openjdk-devel java-1.8.0-openjdk-headless
  else
    echo "OpenJDK $JAVA_VERSION is already installed!"
  fi
else
  if ! rpm -qa | grep -q java-11-openjdk-devel; then
    echo "Installing OpenJDK $JAVA_VERSION..."
    sudo yum install -y -q java-11-openjdk-devel java-11-openjdk-headless
  else
    echo "OpenJDK $JAVA_VERSION is already installed!"
  fi
fi

# Enable and start haveged

echo "Starting Haveged..."
sudo systemctl enable haveged
sudo systemctl start haveged

# Configure SNMP

if [ ! -f "/etc/snmp/configured" ]; then
  echo "Configuring Net-SNMP..."
  SNMP_CFG=/etc/snmp/snmpd.conf
  sudo cp $SNMP_CFG $SNMP_CFG.original
  cat <<EOF | sudo tee $SNMP_CFG
com2sec localUser 127.0.0.1/32 public
com2sec localUser 192.168.1.0/24 public
group localGroup v1 localUser
group localGroup v2c localUser
view all included .1 80
access localGroup "" any noauth 0 all none none
syslocation VirtualBox
syscontact Sergio Garcia <sgarcia@opennms.com>
dontLogTCPWrappersConnects yes
disk /
EOF
  sudo chmod 600 /etc/snmp/snmpd.conf
  sudo systemctl enable snmpd
  sudo systemctl start snmpd
  sudo touch /etc/snmp/configured
else
  echo "Net-SNMP already configured!"
fi
