# Multinode Ceph on Vagrant

This workshop walks users through setting up a 3-node [Ceph](http://ceph.com) cluster and mounting a block device, using a CephFS mount, and storing a blob oject.

It follows the following Ceph user guides:

* [Preflight checklist](http://ceph.com/docs/master/start/quick-start-preflight/)
* [Storage cluster quick start](http://ceph.com/docs/master/start/quick-ceph-deploy/)
* [Block device quick start](http://ceph.com/docs/master/start/quick-rbd/)
* [Ceph FS quick start](http://ceph.com/docs/master/start/quick-cephfs/)
* [Install Ceph object gateway](http://ceph.com/docs/master/install/install-ceph-gateway/)
* [Configuring Ceph object gateway](http://ceph.com/docs/master/radosgw/config/)

Note that after many commands, you may see something like:

```
Unhandled exception in thread started by
sys.excepthook is missing
lost sys.stderr
```

I'm not sure what this means, but everything seems to have completed successfully, and the cluster will work.

## Install prerequisites

Install [Vagrant](http://www.vagrantup.com/downloads.html) and a provider such as [VirtualBox](https://www.virtualbox.org/wiki/Downloads).

We'll also need the [vagrant-cachier](https://github.com/fgrehm/vagrant-cachier) and [vagrant-hostmanager](https://github.com/smdahlen/vagrant-hostmanager) plugins:

```console
$ vagrant plugin install vagrant-cachier
$ vagrant plugin install vagrant-hostmanager
```

## Add your Vagrant key to the SSH agent

Since the admin machine will need the Vagrant SSH key to log into the server machines, we need to add it to our local SSH agent:

On Mac:
```console
$ ssh-add -K ~/.vagrant.d/insecure_private_key
```

On \*nix:
```console
$ ssh-add -k ~/.vagrant.d/insecure_private_key
```

## Start the VMs

This instructs Vagrant to start the VMs and install `ceph-deploy` on the admin machine.

```console
$ vagrant up
```

## Create the cluster

We'll create a simple cluster and make sure it's healthy. Then, we'll expand it.

First, we need to get an interactive shell on the admin machine:

```console
$ vagrant ssh ceph-admin
```

The `ceph-deploy` tool will write configuration files and logs to the current directory. So, let's create a directory for the new cluster:

```console
vagrant@ceph-admin:~$ mkdir test-cluster && cd test-cluster
```

Let's prepare the machines:

```console
vagrant@ceph-admin:~/test-cluster$ ceph-deploy new ceph-server-1 ceph-server-2 ceph-server-3
```

Now, we have to change a default setting. For our initial cluster, we are only going to have two [object storage daemons](http://docs.ceph.com/docs/master/architecture/#the-ceph-storage-cluster). We need to tell Ceph to allow us to achieve an `active + clean` state with just two Ceph OSDs. Add the following to `ceph.conf`:
```
osd pool default size = 2
```

Because we're dealing with multiple VMs sharing the same host, we can expect to see more clock skew. We can tell Ceph that we'd like to tolerate slightly more clock skew by adding the following section to `ceph.conf`:
```
mon_clock_drift_allowed = 1
```

After these few changes, the file should look similar to:

```
[global]
fsid = 7acac25d-2bd8-4911-807e-e35377e741bf
mon_initial_members = ceph-server-1, ceph-server-2, ceph-server-3
mon_host = 172.21.12.12,172.21.12.13,172.21.12.14
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx
osd pool default size = 2
mon_clock_drift_allowed = 1
```

## Install Ceph

We're finally ready to install!

Note here that we specify the Ceph release we'd like to install, which is [mimic](http://docs.ceph.com/docs/master/releases/mimic/).

```console
vagrant@ceph-admin:~/test-cluster$ ceph-deploy install --release=mimic ceph-admin ceph-server-1 ceph-server-2 ceph-server-3 ceph-client
```

## Configure monitor, manager, and OSD services

Next, we add a monitor node:

```console
vagrant@ceph-admin:~/test-cluster$ ceph-deploy mon create-initial
```

A manager node:

```console
ceph-deploy mgr create ceph-admin
```

And our two OSDs:

```console
vagrant@ceph-admin:~/test-cluster$ ceph-deploy osd create --data /dev/sdb ceph-server-2
vagrant@ceph-admin:~/test-cluster$ ceph-deploy osd create --data /dev/sdb ceph-server-3
```

## Configuration and status

We can copy our config file and admin key to all the nodes, so each one can use the `ceph` CLI.

```console
vagrant@ceph-admin:~/test-cluster$ ceph-deploy admin ceph-admin ceph-server-1 ceph-server-2 ceph-server-3 ceph-client
```

We also should make sure the keyring is readable:

```console
vagrant@ceph-admin:~/test-cluster$ sudo chmod +r /etc/ceph/ceph.client.admin.keyring
vagrant@ceph-admin:~/test-cluster$ ssh ceph-server-1 sudo chmod +r /etc/ceph/ceph.client.admin.keyring
vagrant@ceph-admin:~/test-cluster$ ssh ceph-server-2 sudo chmod +r /etc/ceph/ceph.client.admin.keyring
vagrant@ceph-admin:~/test-cluster$ ssh ceph-server-3 sudo chmod +r /etc/ceph/ceph.client.admin.keyring
```

Finally, check on the health of the cluster:

```console
vagrant@ceph-admin:~/test-cluster$ ceph health
```

You should see something similar to this once it's healthy:

```console
vagrant@ceph-admin:~/test-cluster$ ceph health
HEALTH_OK
[vagrant@ceph-admin test-cluster]$ ceph -s
  cluster:
    id:     c50c41a9-2c74-4d10-b110-c8cb0f8d4305
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-server-1,ceph-server-2,ceph-server-3
    mgr: ceph-admin(active)
    osd: 2 osds: 2 up, 2 in

  data:
    pools:   0 pools, 0 pgs
    objects: 0  objects, 0 B
    usage:   2.0 GiB used, 998 GiB / 1000 GiB avail
    pgs:
```

Notice that we have two OSDs (`osd: 2 osds: 2 up, 2 in`) and all of the [placement groups](http://docs.ceph.com/docs/master/rados/operations/placement-groups/) (pgs) are reporting as `active+clean`.

Congratulations!

## Expanding the cluster

To more closely model a production cluster, we're going to add one more OSD daemon and a [Ceph Metadata Server](http://docs.ceph.com/docs/master/man/8/ceph-mds/). We'll also add monitors to all hosts instead of just one.

### Add an OSD
```console
[vagrant@ceph-admin test-cluster]$ ceph-deploy osd create --data /dev/sdb ceph-server-1
```

Watch the rebalancing:

```console
vagrant@ceph-admin:~/test-cluster$ ceph -w
```

You should eventually see it return to an `active+clean` state, but this time with 3 OSDs:

```console
[vagrant@ceph-admin test-cluster]$ ceph -w
  cluster:
    id:     c50c41a9-2c74-4d10-b110-c8cb0f8d4305
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-server-1,ceph-server-2,ceph-server-3
    mgr: ceph-admin(active)
    osd: 3 osds: 3 up, 3 in

  data:
    pools:   0 pools, 0 pgs
    objects: 0  objects, 0 B
    usage:   3.0 GiB used, 1.5 TiB / 1.5 TiB avail
    pgs:
```

### Add metadata server

Let's add a metadata server to server1:

```console
vagrant@ceph-admin:~/test-cluster$ ceph-deploy mds create ceph-server-1
```

## Add more monitors

We add monitors to servers 2 and 3.

```console
vagrant@ceph-admin:~/test-cluster$ ceph-deploy mon create ceph-server-2 ceph-server-3
```

Watch the quorum status, and ensure it's happy:

```console
vagrant@ceph-admin:~/test-cluster$ ceph quorum_status --format json-pretty
```

## Install Ceph Object Gateway

TODO

## Play around!

Now that we have everything set up, let's actually use the cluster. We'll use the ceph-client machine for this.

### Create a block device

```console
$ vagrant ssh ceph-client
vagrant@ceph-client:~$ sudo rbd create foo --size 4096 -m ceph-server-1
vagrant@ceph-client:~$ sudo rbd map foo --pool rbd --name client.admin -m ceph-server-1
vagrant@ceph-client:~$ sudo mkfs.ext4 -m0 /dev/rbd/rbd/foo
vagrant@ceph-client:~$ sudo mkdir /mnt/ceph-block-device
vagrant@ceph-client:~$ sudo mount /dev/rbd/rbd/foo /mnt/ceph-block-device
```

### Create a mount with Ceph FS

TODO

### Store a blob object

TODO

## Cleanup

When you're all done, tell Vagrant to destroy the VMs.

```console
$ vagrant destroy -f
```
