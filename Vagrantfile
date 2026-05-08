# -*- mode: ruby -*-
# vi: set ft=ruby :

opennms_cfg = {
  :vboxname => "onms",
  :hostname => "onsm.local",
  :ip       => "192.168.1.1",
  :mem      => "4096",
  :cpu      => "2",
  :timezone => "America/New_York",
  :repo     => "stable",
  :version  => "-latest", # Use '-latest' or something like '27.0.3-1'
  :rocky    => "9", # Use 8 or 9
  :java     => "17", # Use 17 or 21
  :postgres => "14" # Use "default" to use what's provided with CentOS
}

minion_cfg = {
  :vboxname => "onms-minion",
  :hostname => "minion.local",
  :ip       => "192.168.205.101",
  :mem      => "2048",
  :cpu      => "1",
  :timezone => "America/New_York",
  :repo     => "stable",
  :version  => "-latest-", # Use '-latest' or something like '27.0.3-1'
  :rocky   => "8", # Use 8 or 9
  :java     => "11", # Use 17 or 21
  :location => "wherever",
  :onms_url => "http://#{opennms_cfg[:ip]}:8980/opennms",
  :amq_url  => "failover:tcp://#{opennms_cfg[:ip]}:61616"
}

Vagrant.configure("2") do |config|
  config.vm.box_check_update = false
  if Vagrant.has_plugin?("vagrant-vbguest")
    config.vbguest.auto_update = false
  end

  config.vm.define "opennms" do |o|
    o.vm.box = "bento/rockylinux-#{opennms_cfg[:rocky]}"
    o.vm.hostname = opennms_cfg[:hostname]
    o.vm.provider "virtualbox" do |v|
      v.name = opennms_cfg[:vboxname]
      v.customize [ "modifyvm", :id, "--cpus", opennms_cfg[:cpu] ]
      v.customize [ "modifyvm", :id, "--memory", opennms_cfg[:mem] ]
#      v.default_nic_type = "virtio"
    end
    o.vm.network "private_network", ip: opennms_cfg[:ip]
    o.vm.provision "shell" do |s|
      s.path = "bootstrap-common.sh"
      s.args = [ opennms_cfg[:java], opennms_cfg[:timezone] ]
    end
    o.vm.provision "shell" do |s|
      s.path = "bootstrap-opennms.sh"
      s.args = [ opennms_cfg[:rocky], opennms_cfg[:repo], opennms_cfg[:version], opennms_cfg[:postgres] ]
    end
  end

  config.vm.define "minion" do |m|
    m.vm.box = "bento/rockylinux-#{minion_cfg[:rocky]}"
    m.vm.hostname = minion_cfg[:hostname]
    m.vm.provider "virtualbox" do |v|
      v.name = minion_cfg[:vboxname]
      v.customize [ "modifyvm", :id, "--cpus", minion_cfg[:cpu] ]
      v.customize [ "modifyvm", :id, "--memory", minion_cfg[:mem] ]
#      v.default_nic_type = "virtio"
    end
    m.vm.network "private_network", ip: minion_cfg[:ip]
    m.vm.provision "shell" do |s|
      s.path = "bootstrap-common.sh"
      s.args = [ minion_cfg[:java], minion_cfg[:timezone] ]
    end
    m.vm.provision "shell" do |s|
      s.path = "bootstrap-minion.sh"
      s.args = [ minion_cfg[:centos], minion_cfg[:repo], minion_cfg[:version], minion_cfg[:location], minion_cfg[:onms_url], minion_cfg[:amq_url] ]
    end
  end

end
