#!/bin/bash

# Designed for Rocky Linux 8/9 and ARM architecture
# Author: Alejandro Galue
# Updated and maintained: Sergio Garcia <sgarcia@opennms.com>

# External variables with defaults

ROCKY_VERSION=${1-9};
ONMS_REPO_NAME=${2-stable};
ONMS_VERSION=${3--latest-};
LOCATION=${4-Vagrant};
ONMS_URL=${5-http://opennms:8980/opennms}
AMQ_URL=${6-failover:tcp://opennms:61616};

# Local Variables

MINION_HOME=/opt/minion
MINION_ETC=$MINION_HOME/etc
TRAP_PORT=162
SYSLOG_PORT=514

# Obtain IP address (requires net-tools package)

IP_ADDR=$(ifconfig eth1 | grep "inet " | awk '{print $2}')

# Install core Minion dependencies from the stable repository

if ! rpm -qa | grep -q jicmp; then
  echo "Installing OpenNMS dependencies ..."
  sudo yum install -y -q http://yum.opennms.org/repofiles/opennms-repo-stable-rhel$ROCKY_VERSION.noarch.rpm
  sudo rpm --import /etc/yum.repos.d/opennms-repo-stable-rhel$ROCKY_VERSION.gpg
  sudo yum install -y -q jicmp jicmp6
else
  echo "Minion dependencies are already installed!"
fi

# Install branch repository

if [ "$ONMS_REPO_NAME" != "stable" ]; then
  echo "Installing OpenNMS $ONMS_REPO_NAME repository..."
  sudo yum remove -y -q opennms-repo-stable
  sudo yum install -y -q http://yum.opennms.org/repofiles/opennms-repo-$ONMS_REPO_NAME-rhel$ROCKY_VERSION.noarch.rpm
  sudo rpm --import /etc/yum.repos.d/opennms-repo-$ONMS_REPO_NAME-rhel$ROCKY_VERSION.gpg
fi

# Install Minion packages

if ! rpm -qa | grep -q opennms-minion; then
  SUFFIX=""
  if [ "$ONMS_VERSION" == "-latest-" ]; then
    echo "Installing latest opennms from $ONMS_REPO_NAME repository..."
  else
    echo "Installing opennms version $ONMS_VERSION from $ONMS_REPO_NAME repository..."
    SUFFIX="-$ONMS_VERSION"
  fi
  sudo yum install -y -q opennms-minion$SUFFIX
else
  echo "Minion $ONMS_VERSION is already installed!"
fi

# Configure Minion

if [ ! -f "$MINION_ETC/.git" ]; then
  echo "### Configuring OpenNMS Minion..."

  cat <<EOF | sudo tee $MINION_ETC/featuresBoot.d/hawtio.boot
hawtio-offline
EOF

  MINION_ID=$(hostname)
  cat <<EOF | sudo tee $MINION_ETC/org.opennms.minion.controller.cfg
location=$LOCATION
id=$MINION_ID
http-url=$ONMS_URL
broker-url=$AMQ_URL
EOF

  cat <<EOF | sudo tee org.opennms.netmgt.trapd.cfg
trapd.listen.interface=0.0.0.0
trapd.listen.port=$TRAP_PORT
EOF

  cat <<EOF | sudo tee org.opennms.netmgt.syslog.cfg
syslog.listen.interface=0.0.0.0
syslog.listen.port=$SYSLOG_PORT
EOF

  sudo systemctl enable minion
  sudo systemctl start minion

fi

echo "Done!"
