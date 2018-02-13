#!/bin/bash

######################
## Version: V1.0    ##
## Author: Tao Yang ##
## Date: 2018.01    ##
######################

IMAGE_DIRECTORY="."
UBOOT_FILE="u-boot.imx"
KERNEL_FILE="zImage"
DTB_FILE="imx6ul-14x14-gateway.dtb"
ROOTFS_FILE="rootfs"

echo ""
echo "WARNING!!!"
echo "PLEASE CHECK AND CONFIRM!!!"
echo -n "Continue [y/N]?"
read YN

if [ "$YN" == "N" ] || [ "$YN" == "n" ] || [ "$YN" == "" ]; then
	echo "Quitting..."
	exit 1
fi

#detach all the loop devices and umount /mnt/loop* 
losetup -D
umount /mnt/loop*

#check if there's already a image, if yes, backup it, if no, create one.
if test -e ./system.img
then
	echo "system.img exists, backup it."
	cp ./system.img ./system.img.bak
else
	echo "system.img not exist, create it."
	touch system.img
fi

#initialize 1GB file containing all zeros
dd if=/dev/zero of=./system.img bs=1024 count=1048576

#attach the image file to /dev/loop0
losetup /dev/loop0 ./system.img

#dd the uboot file, please modify the offset as you need.
dd if=${IMAGE_DIRECTORY}/${UBOOT_FILE} of=/dev/loop0 bs=512 seek=2 conv=fsync 

SIZE=`fdisk -l /dev/loop0 | grep Disk | awk '{print $5}'`

echo DISK SIZE -- $SIZE Bytes

#make the partitions as you need, size is sector
sfdisk --Linux --unit S /dev/loop0 << EOF
20480,225279,L,*
230000,,,-
EOF

#attach the partions to loop devices, the offset is, for example, 20480*512
losetup -o 10485760 /dev/loop1 /dev/loop0
losetup -o 117760000 /dev/loop2 /dev/loop0

if test -d /mnt/loop1
then
	echo "loop1 exists"
	umount /mnt/loop1
else
	mkdir -p /mnt/loop1
fi

if test -d /mnt/loop2
then
	echo "loop2 exists"
	umount /mnt/loop2
else
	mkdir -p /mnt/loop2
fi

#create specified filesystems as you need
mkfs.vfat -F 32 -n "boot" /dev/loop1
mkfs.ext4 -L "rootfs" /dev/loop2

mount /dev/loop1 /mnt/loop1
mount /dev/loop2 /mnt/loop2

cp ${IMAGE_DIRECTORY}/${KERNEL_FILE} ${IMAGE_DIRECTORY}/${DTB_FILE} /mnt/loop1
cp -r ${IMAGE_DIRECTORY}/${ROOTFS_FILE}/* /mnt/loop2

umount /mnt/loop1
umount /mnt/loop2
losetup -D

echo "Done"
