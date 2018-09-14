# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "geerlingguy/centos7"
  config.ssh.forward_agent = true
  config.ssh.insert_key = false
  config.hostmanager.enabled = true
  config.cache.scope = :box

  # We need one Ceph admin machine to manage the cluster
  config.vm.define "ceph-admin" do |admin|
    admin.vm.hostname = "ceph-admin"
    admin.vm.network :private_network, ip: "172.21.12.10"
    admin.vm.provision "shell", path: "provision-admin.sh"
  end

  # The Ceph client will be our client machine to mount volumes and interact with the cluster
  config.vm.define "ceph-client" do |client|
    client.vm.hostname = "ceph-client"
    client.vm.network :private_network, ip: "172.21.12.11"
    # ceph-deploy will assume remote machines have python2 installed
    config.vm.provision :shell, :inline => "yum update; yum -y install python", :privileged => true
  end

  # We provision three nodes to be Ceph servers
  (1..3).each do |i|
    config.vm.define "ceph-server-#{i}" do |config|
      config.vm.hostname = "ceph-server-#{i}"
      file_to_disk = "osd#{i}.vdi"
      config.vm.provider "virtualbox" do |vb|
        unless File.exist?(file_to_disk)
          vb.customize ['createhd', '--filename', file_to_disk, '--size', 500 * 1024]
        end
        vb.customize ['storageattach', :id, '--storagectl', 'IDE Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', file_to_disk]
      end
      config.vm.network :private_network, ip: "172.21.12.#{i+11}"
      # ceph-deploy will assume remote machines have python2 installed
      config.vm.provision :shell, :inline => "yum update; yum -y install python", :privileged => true
    end
  end
end
