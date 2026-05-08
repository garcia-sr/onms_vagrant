Simple OpenNMS/Minion Environment using Vagrant
====

This lab starts two VMs, one with OpenNMS and PostgreSQL, and another with Minion.

Both VMs are based on CentOS 8 and use OpenJDK 11, but this can be changed.

For simplicity, it is using ActiveMQ as the broker solution for Sink and RPC communication.

## Requirements

* VirtualBox
* Vagrant
* Have a network in Virtualbox using 192.168.205.0/24. If you want to use another one, make sure to update the IP Addresses in the `Vagrantfile` file.

## Start

```bash
vagrant up
```

## Access OpenNMS

```bash
vagrant ssh opennms
```

## Access Minion

```bash
vagrant ssh minion
```

## Stop VMs

```bash
vagrant halt
```

## Terminate Lab

```bash
vagrant destroy -f
```

The above will remove the VMs from your system.