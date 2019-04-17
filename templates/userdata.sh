#!/bin/bash
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOI | fdisk /dev/xvdb
  o # create a new DOS disklabel
  n # new partition
  p # primary
  1 # default
    # start sector default
    # end sector default (entire disk)
  w # write config
  q # quit fdisk
EOI

mkfs.ext4 /dev/xvdb1
mkdir -p /opt/tfe
mount /dev/xvdb1 /opt/tfe

sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOI | fdisk /dev/xvdc
  o # create a new DOS disklabel
  n # new partition
  p # primary
  1 # default
    # start sector default
    # end sector default (entire disk)
  w # write config
  q # quit fdisk
EOI

mkfs.ext4 /dev/xvdc1
mkdir -p /var/lib/docker
mount /dev/xvdc1 /var/lib/docker

