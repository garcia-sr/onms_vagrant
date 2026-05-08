#!/bin/bash

# Designed for Rocky Linux 8/9 and ARM architecture
# Author: Alejandro Galue
# Updated and maintained: Sergio Garcia <sgarcia@opennms.com>

# Main externally configurable variables with defaults

CENTOS_VERSION=${1-8};
ONMS_REPO_NAME=${2-stable};
ONMS_VERSION=${3--latest-};
PG_VERSION=${4-default};

# Local Variables

ONMS_HOME=/opt/opennms
ONMS_ETC=$ONMS_HOME/etc

# Obtain IP address (requires net-tools package)

IP_ADDR=$(ifconfig eth1 | grep "inet " | awk '{print $2}')

# Install PostgreSQL

if [ "$PG_VERSION" == "default" ]; then
  if ! rpm -qa | grep -q postgresql-server; then
    sudo yum install -y -q postgresql-server
  else
    echo "PostgreSQL is installed!"
  fi
else
  if [ "$CENTOS_VERSION" == "8" ]; then
    sudo dnf -qy module disable postgresql
  else
    sudo yum -y -q install yum-utils
    sudo yum-config-manager --enable pgdg$PG_VERSION
  fi
  sudo yum install -y -q https://download.postgresql.org/pub/repos/yum/reporpms/EL-$CENTOS_VERSION-x86_64/pgdg-redhat-repo-latest.noarch.rpm
  sudo yum install -y -q postgresql$PG_VERSION-server
fi

# Configure PostgreSQL

PG_DATA=/var/lib/pgsql/data
if [ "$PG_VERSION" != "default" ]; then
  PG_DATA=/var/lib/pgsql/$PG_VERSION/data
fi

if [ "$(ls -A $PG_DATA 2>/dev/null)" == "" ]; then
  echo "Configuring PostgreSQL..."
  if [ "$PG_VERSION" == "default" ]; then
    sudo postgresql-setup initdb
    sudo sed -r -i 's/(peer|ident)/trust/g' $PG_DATA/pg_hba.conf
    sudo systemctl enable postgresql
    sudo systemctl start postgresql
  else
    PGSETUP=$(find /usr/pgsql-$PG_VERSION/bin/ -name postgresql*setup)
    sudo $PGSETUP initdb
    sudo sed -r -i 's/(peer|ident)/trust/g' $PG_DATA/pg_hba.conf
    sudo systemctl enable postgresql-$PG_VERSION
    sudo systemctl start postgresql-$PG_VERSION
  fi
else
  echo "PostgreSQL is already configured!"
fi

# Install core OpenNMS dependencies from the stable repository

if ! rpm -qa | grep -q jicmp; then
  echo "Installing OpenNMS dependencies ..."
  sudo yum install -y -q http://yum.opennms.org/repofiles/opennms-repo-stable-rhel$CENTOS_VERSION.noarch.rpm
  sudo rpm --import /etc/yum.repos.d/opennms-repo-stable-rhel$CENTOS_VERSION.gpg
  sudo yum install -y -q jicmp jicmp6 jrrd jrrd2 rrdtool
  if [ "$CENTOS_VERSION" == "8" ]; then
    sudo dnf config-manager --set-enabled powertools
  fi
  sudo yum install -y -q 'perl(LWP)' 'perl(XML::Twig)'
else
  echo "OpenNMS dependencies are already installed!"
fi

# Install branch repository if necessary

if [ "$ONMS_REPO_NAME" != "stable" ]; then
  echo "Installing OpenNMS $ONMS_REPO_NAME repository..."
  sudo yum remove -y -q opennms-repo-stable
  sudo yum install -y -q http://yum.opennms.org/repofiles/opennms-repo-$ONMS_REPO_NAME-rhel$CENTOS_VERSION.noarch.rpm
  sudo rpm --import /etc/yum.repos.d/opennms-repo-$ONMS_REPO_NAME-rhel$CENTOS_VERSION.gpg
fi

# Install OpenNMS packages

if ! rpm -qa | grep -q opennms-core; then
  SUFFIX=""
  if [ "$ONMS_VERSION" == "-latest-" ]; then
    echo "Installing latest opennms from $ONMS_REPO_NAME repository..."
  else
    echo "Installing opennms version $ONMS_VERSION from $ONMS_REPO_NAME repository..."
    SUFFIX="-$ONMS_VERSION"
  fi
  sudo yum install -y -q opennms-core$SUFFIX opennms-webapp-jetty$SUFFIX
  sudo yum install -y -q opennms-webapp-hawtio$SUFFIX
else
  echo "OpenNMS $ONMS_VERSION is already installed!"
fi

# Configure OpenNMS

if [ -d "$ONMS_HOME" ]; then
  if [ ! -f "$ONMS_ETC/configured" ]; then
    sudo $ONMS_HOME/bin/runjava -s
    sudo $ONMS_HOME/bin/install -dis

    # Enable Local ActiveMQ
    sudo sed -r -i '/0.0.0.0:61616/s/[<][!]--//' $ONMS_ETC/opennms-activemq.xml
    sudo sed -r -i '/0.0.0.0:61616/s/--[>]//'    $ONMS_ETC/opennms-activemq.xml

    # Configure RRDtool
    cat <<EOF | sudo tee $ONMS_ETC/opennms.properties.d/rrd.properties
org.opennms.rrd.storeByGroup=true
org.opennms.rrd.storeByForeignSource=true
org.opennms.rrd.strategyClass=org.opennms.netmgt.rrd.rrdtool.MultithreadedJniRrdStrategy
org.opennms.rrd.interfaceJar=/usr/share/java/jrrd2.jar
opennms.library.jrrd2=/usr/lib64/libjrrd2.so
EOF

    # Create opennms.conf
    TOTAL_MEM_IN_MB=$(free -m | awk '/:/ {print $2;exit}')
    MEM_IN_MB=$(expr $TOTAL_MEM_IN_MB / 2)
    if [ "$MEM_IN_MB" -gt "30720" ]; then
      MEM_IN_MB="30720"
    fi
    JMX_PORT=18980
    cat <<EOF | sudo tee $ONMS_ETC/opennms.conf
START_TIMEOUT=0
JAVA_HEAP_SIZE=$MEM_IN_MB
MAXIMUM_FILE_DESCRIPTORS=204800

# To run "opennms -v status"
JMX_URL="service:jmx:rmi:///jndi/rmi://127.0.0.1:18980/jmxrmi"

# GC Settings
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -XX:+UseG1GC -XX:+UseStringDeduplication"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Xlog:gc*,gc+phases=debug:file=/opt/opennms/logs/gc.log:time,pid,tags:filecount=10,filesize=10m"

# Configure Remote JMX (disabled authentication due to use "opennms -v status")
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.port=$JMX_PORT"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.rmi.port=$JMX_PORT"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.local.only=false"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.ssl=false"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.authenticate=false"

# Listen on all interfaces
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dopennms.poller.server.serverHost=0.0.0.0"

# Accept remote RMI connections on this interface
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Djava.rmi.server.hostname=$IP_ADDR"
EOF

    cat <<EOF | sudo tee $ONMS_ETC/jmxremote.access
admin   readwrite
jmx     readonly
EOF

    sudo systemctl enable opennms
    sudo systemctl start opennms
  else
    echo "OpenNMS already configured!"
  fi
else
  echo "Cannot find $ONMS_HOME"
fi

echo "Done!"
