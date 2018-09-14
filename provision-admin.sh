#!/bin/sh

echo "Installing ceph-release RPM"
rpm -Uhv http://download.ceph.com/rpm-mimic/el7/noarch/ceph-release-1-1.el7.noarch.rpm
echo "Cleaning Ceph repo cache"
yum -y --enablerepo=Ceph-noarch clean metadata
echo "Running yum update"
yum -y update && echo "Running yum install" && yum -y install python-setuptools ceph-deploy

