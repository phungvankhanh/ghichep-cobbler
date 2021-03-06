#!/bin/bash
source config.sh

cat << HERE > /var/lib/cobbler/kickstarts/OPS_COM$com_num-test.seed
# Mostly based on the Ubuntu installation guide
# https://help.ubuntu.com/16.04/installation-guide/

# Preseeding only locale sets language, country and locale.
d-i debian-installer/locale string en_US

# Keyboard selection.
# Disable automatic (interactive) keymap detection.
d-i console-setup/ask_detect boolean false
d-i keyboard-configuration/layoutcode string us
d-i keyboard-configuration/variantcode string

# netcfg will choose an interface that has link if possible. This makes it
# skip displaying a list if there is more than one interface.
#set \$myhostname = \$getVar('hostname',\$getVar('name','cobbler')).replace("_","-")
# config network not effective when boot from network
## d-i netcfg/choose_interface select eth0 
## d-i netcfg/get_hostname string \$myhostname

# If non-free firmware is needed for the network or other hardware, you can
# configure the installer to always try to load it, without prompting. Or
# change to false to disable asking.
# d-i hw-detect/load_firmware boolean true

# NTP/Time Setup and timezone setup
d-i time/zone string Asia/Ho_Chi_Minh
d-i clock-setup/utc boolean true
d-i clock-setup/ntp boolean true
d-i clock-setup/ntp-server  string ntp.ubuntu.com

# Setup the installation source
d-i mirror/country string manual
d-i mirror/http/hostname string \$http_server
d-i mirror/http/directory string \$install_source_directory
d-i mirror/http/proxy string

#set \$os_v = \$getVar('os_version','')
#if \$os_v and \$os_v.lower()[0] > 'p'
# Required at least for 12.10+
d-i live-installer/net-image string http://\$http_server/cobbler/links/\$distro_name/install/filesystem.squashfs
#end if

# Suite to install.
# d-i mirror/suite string precise
# d-i mirror/udeb/suite string precise

# Components to use for loading installer components (optional).
#d-i mirror/udeb/components multiselect main, restricted

# Disk Partitioning
# Use LVM, and wipe out anything that already exists
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i partman-auto/method string lvm
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-partitioning/confirm_write_new_label boolean true

# You can choose one of the three predefined partitioning recipes:
# - atomic: all files in one partition
# - home:   separate /home partition
# - multi:  separate /home, /usr, /var, and /tmp partitions
d-i partman-auto/choose_recipe select atomic

# If you just want to change the default filesystem from ext3 to something
# else, you can do that without providing a full recipe.
# d-i partman/default_filesystem string ext4

### Account setup
d-i passwd/root-login boolean true
d-i passwd/make-user boolean true

# Root password, either in clear text
d-i passwd/root-password password $ROOT_PASS
d-i passwd/root-password-again password $ROOT_PASS

# To create a normal user account.
d-i passwd/user-fullname string Ubuntu User
d-i passwd/username string $USER_NAME
d-i passwd/user-password password $USER_PASS
d-i passwd/user-password-again password $USER_PASS
d-i user-setup/allow-password-weak boolean true
d-i user-setup/encrypt-home boolean false

# You can choose to install restricted and universe software, or to install
# software from the backports repository.
# d-i apt-setup/restricted boolean true
# d-i apt-setup/universe boolean true
# d-i apt-setup/backports boolean true

# Uncomment this if you don't want to use a network mirror.
# d-i apt-setup/use_mirror boolean false

# Select which update services to use; define the mirrors to be used.
# Values shown below are the normal defaults.
# d-i apt-setup/services-select multiselect security
# d-i apt-setup/security_host string security.ubuntu.com
# d-i apt-setup/security_path string /ubuntu

\$SNIPPET('preseed_apt_repo_config')

# Enable deb-src lines
# d-i apt-setup/local0/source boolean true

# URL to the public key of the local repository; you must provide a key or
# apt will complain about the unauthenticated repository and so the
# sources.list line will be left commented out
# d-i apt-setup/local0/key string http://local.server/key

# By default the installer requires that repositories be authenticated
# using a known gpg key. This setting can be used to disable that
# authentication. Warning: Insecure, not recommended.
# d-i debian-installer/allow_unauthenticated boolean true

# Individual additional packages to install
# wget is REQUIRED otherwise quite a few things won't work
# later in the build (like late-command scripts)
d-i pkgsel/include string ssh wget

# Use the following option to add additional boot parameters for the
# installed system (if supported by the bootloader installer).
# Note: options passed to the installer will be added automatically.
d-i debian-installer/add-kernel-opts string \$kernel_options
d-i grub-installer/bootdev  string default
d-i debian-installer/quiet boolean false
d-i debian-installer/splash boolean false

# Avoid that last message about the install being complete.
d-i finish-install/reboot_in_progress note

## Figure out if we're kickstarting a system or a profile
#if \$getVar('system_name','') != ''
#set \$what = "system"
#else
#set \$what = "profile"
#end if
#set \$com_no=$com_num

# This first command is run as early as possible, just after preseeding is read.
# d-i preseed/early_command string [command]
d-i preseed/early_command string wget -O- \\
   http://\$http_server/cblr/svc/op/script/\$what/\$name/?script=preseed_early_default | \\
   /bin/sh -s
d-i preseed/late_command string \\
mkdir -p /target/root/scripts; \\
cd /target/root/scripts; \\
wget http://\$http_server/cblr/svc/op/script/\$what/\$name/?script=COM_script -O late_command.sh; \\
chmod 755 *; \\
/target/bin/sh late_command.sh; \\
echo "COM_NUM=\$com_no" > /target/root/OPS-setup/COM/com_num.sh



# This command is run immediately before the partitioner starts. It may be
# useful to apply dynamic partitioner preseeding that depends on the state
# of the disks (which may not be visible when preseed/early_command runs).
# d-i partman/early_command \\
#       string debconf-set partman-auto/disk "\\\$(list-devices disk | head -n1)"

# This command is run just before the install finishes, but when there is
# still a usable /target directory. You can chroot to /target and use it
# directly, or use the apt-install and in-target commands to easily install
# packages and run commands in the target system.
# d-i preseed/late_command string [command]
HERE

cobbler profile add --name=OPS-Compute$com_num --distro=US160403-x86_64 --kickstart=/var/lib/cobbler/kickstarts/OPS_COM$com_num-test.seed
