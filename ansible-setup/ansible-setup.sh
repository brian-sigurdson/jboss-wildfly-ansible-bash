#!/bin/bash

# Author:       Brian Sigurdson sigurdson.brian@gmail.com
# Date:         2018-10-30
# Description:  This script prepares the master and slave nodes to be used with, and managed by, Ansible.
#				It will install all the necessary software on each node and create a user with sudoer
#				privileges to be used by Ansible.				

####################################################################################################################
# globals
PROG_NAME="$0"
PROG_BASE_NAME=$(basename $0)

ANSIBLE_UN="$1"
ANSIBLE_PWD="$2"

PROG_USER_SELECTION="$3"
PROG_USER_PWD="$4"
SLAVE_FILE="$5"
SHOW_EXPECT_SCRIPT_MSG="$6"
LOG_FILES_PATH="$7"
PATH_TO_ANSIBLE_SETUP_FILES_DIR="$8"

PROG_USER=`logname`
HOST_IP=`hostname -i`
HOST_NAME=`hostname`
HOST_NAME_SHORT=`hostname -s`

####################################################################################################################
# Functions
#===================================================================================================================
func_print_script_info(){

	echo ""
	echo "###############################################"
	echo "PROG_BASE_NAME:           $PROG_BASE_NAME"
	echo "PROG_USER:                $PROG_USER"
	echo "USER:                     $USER"
	echo "hostname -f:              `hostname -f`"
	echo "HOST_IP:                  $HOST_IP"
	echo "ANSIBLE_UN:               $ANSIBLE_UN"
	#echo "ANSIBLE_PWD:             $ANSIBLE_PWD"
	echo "PROG_USER_SELECTION:      $PROG_USER_SELECTION"
	#echo "PROG_USER_PWD:           $PROG_USER_PWD"
	echo "SLAVE_FILE:               $SLAVE_FILE"
	echo "SHOW_EXPECT_SCRIPT_MSG:   $SHOW_EXPECT_SCRIPT_MSG"
	echo "LOG_FILES_PATH:           $LOG_FILES_PATH"
	echo "SLAVE_FILE:               $SLAVE_FILE"
	echo "###############################################"
	echo ""
}
#===================================================================================================================
func_update_system(){

	# Update the system

	echo ""
	echo "yum update -y"
	echo ""
	yum update -y
}
#===================================================================================================================
func_install_other_software(){

	# open-jdk, ant, ansible (use ansible's repo if desired)

	for val in java ant maven python; do
		echo ""
		echo "yum install -y " $val
		echo ""
		yum install -y $val
	done
}
#===================================================================================================================
func_install_ansible(){

	# install ansible

	echo ""
	echo "yum install -y ansible"
	echo ""
	yum install -y ansible
}
#===================================================================================================================
func_create_ansible_user(){

	# Create a user to run Ansible playbooks

	echo ""
	echo "useradd --shell /bin/bash --home /home/$ANSIBLE_UN --comment 'User to run Ansible Playbooks' $ANSIBLE_UN"
	useradd --shell /bin/bash --home "/home/$ANSIBLE_UN" --comment "User to run Ansible Playbooks" "$ANSIBLE_UN"

	echo ""
	echo "$ANSIBLE_UN:$ANSIBLE_PWD | chpasswd"
	echo "$ANSIBLE_UN:$ANSIBLE_PWD" | chpasswd
}
#===================================================================================================================
func_set_ansible_sudoer_privileges(){

	# In order to run Ansible playbooks unencumbered, the user ansible will need to have the following:
	#    a)  sudoer privileges without password prompt
	#    b)  not be a member of the sudoers group 
	#    This will require that a file be added to /ect/sudoers.d, as per the directions in /etc/sudoers.d/README
	#    Note:	Being a member of sudoers and updating sudoers via visudo caused errors during testing.
	#		The errors disappeared once the user ansible was removed from the sudoers group.

	# the following is from the /etc/sudoers file and is used as a guide for use on user ansible.
	# User privilege specification
	#root    ALL=(ALL:ALL) ALL

	echo ""
	echo "$ANSIBLE_UN ALL=(ALL:ALL) NOPASSWD: ALL > /etc/sudoers.d/$ANSIBLE_UN"
	echo "$ANSIBLE_UN ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/"$ANSIBLE_UN"

	echo ""
	echo "chmod 0440 /etc/sudoers.d/$ANSIBLE_UN"
	chmod 0440 /etc/sudoers.d/"$ANSIBLE_UN"

	# Note:	Below are the contents of the current (2017-09-19) /etc/sudoers.d/README file.

	# As of Debian version 1.7.2p1-1, the default /etc/sudoers file created on
	# installation of the package now includes the directive:
	# 
	# 	#includedir /etc/sudoers.d
	# 
	# This will cause sudo to read and parse any files in the /etc/sudoers.d 
	# directory that do not end in '~' or contain a '.' character.
	# 
	# Note that there must be at least one file in the sudoers.d directory (this
	# one will do), and all files in this directory should be mode 0440.
	# 
	# Note also, that because sudoers contents can vary widely, no attempt is 
	# made to add this directive to existing sudoers files on upgrade.  Feel free
	# to add the above directive to the end of your /etc/sudoers file to enable 
	# this functionality for existing installations if you wish!
	#
	# Finally, please note that using the visudo command is the recommended way
	# to update sudoers content, since it protects against many failure modes.
	# See the man page for visudo for more information.
}
#===================================================================================================================
func_create_set_ssh_keys_localhost(){

	local SSH_DIR=/home/$ANSIBLE_UN/.ssh
	echo ""
	echo "mkdir -p $SSH_DIR"
	mkdir -p $SSH_DIR

	echo ""
	echo "chmod 700 $SSH_DIR"
	chmod 700 $SSH_DIR
	
	echo ""
	local ID_RSA=$SSH_DIR/id_rsa
	echo "ssh-keygen -v -b 2048 -t rsa -f $ID_RSA -N ''"
	ssh-keygen -v -b 2048 -t rsa -f $ID_RSA -N ''

	# the key will be specific to root@localhost-name, change to ansible@localhost-name
	echo ""
	echo "sed -i s/$USER/$ANSIBLE_UN/g $ID_RSA.pub"
	sed -i "s/$USER/$ANSIBLE_UN/g" "$ID_RSA".pub

	echo ""
	echo "chmod 600 $ID_RSA"
	chmod 600 $ID_RSA

	# copy id_rsa.pub to authorized_keys
	echo ""
	AUTH_KEYS=$SSH_DIR/authorized_keys
	echo "cp $SSH_DIR/id_rsa.pub $AUTH_KEYS"
	cp "$SSH_DIR/id_rsa.pub" "$AUTH_KEYS"

	echo ""
	echo "chmod 640 $AUTH_KEYS"
	chmod 640 $AUTH_KEYS

	# setup known_hosts file to facilitate ssh login localhost
	local KNOWN_HOSTS=$SSH_DIR/known_hosts
	echo ""
	# this sets up ssh passwordless by ip address
	echo "ssh-keyscan $HOST_IP >> $KNOWN_HOSTS"
	ssh-keyscan $HOST_IP >> $KNOWN_HOSTS

	# this sets up ssh passwordless by host name
	echo "ssh-keyscan $HOST_NAME_SHORT >> $KNOWN_HOSTS"
	ssh-keyscan $HOST_NAME_SHORT >> $KNOWN_HOSTS

	# user ansible owns everything in .ssh
	echo ""
	echo "chown -R $ANSIBLE_UN:$ANSIBLE_UN $SSH_DIR"
	chown -R $ANSIBLE_UN:$ANSIBLE_UN $SSH_DIR
}
#===================================================================================================================
func_get_master_rsa_pub(){

	# set the public key for the user on the master node
	echo ""
	echo "cat `pwd`/id_rsa.pub >> /home/$ANSIBLE_UN/.ssh/authorized_keys"
	cat `pwd`/id_rsa.pub >> /home/"$ANSIBLE_UN"/.ssh/authorized_keys

	# and remove the master's public key
	echo ""
	echo "rm -f `pwd`/id_rsa.pub"
	rm -f `pwd`/id_rsa.pub
}
#===================================================================================================================
func_slave_script_delete_yourself(){
	
	# this is to be run on the slave
	echo ""
	echo "rm -f `pwd`/$PROG_BASE_NAME"
	rm -f `pwd`/$PROG_BASE_NAME
}
#===================================================================================================================
func_install_sshpass(){

	# install sshpass to facilitate automated interaction with managed nodes

	echo ""
	echo "yum install -y sshpass"
	echo ""
	yum install -y sshpass
}
#===================================================================================================================
func_remove_sshpass(){

	echo ""
	echo "yum remove -y sshpass"
	echo ""
	yum remove -y sshpass
}
#===================================================================================================================
func_install_expect(){

	# install expect to facilitate logging into the user account of slave nodes and running setup script with sudo

	echo ""
	echo "yum install -y expect"
	echo ""
	yum install -y expect
}
#===================================================================================================================
func_remove_expect(){

	echo ""
	echo "yum remove -y expect"
	echo ""
	yum remove -y expect
}
#===================================================================================================================
func_remove_public_key_file(){
	
	# remove master_id_rsa.pub
	echo ""
	echo "rm -f `pwd`/master_id_rsa.pub"
	rm -f `pwd`/master_id_rsa.pub
}
#===================================================================================================================
func_get_user_passwd(){
	
	# get user password so that the script can:
	cat <<- _EOF_ 
	----------------------------------------------------------------------
	By entering your password, this script can automatically do the
	following for each slave address listed in the $SLAVE_FILE file:

	1) send the setup script to the slave
	2) execute the setup script on the slave
	3) retrieve the slave's setup log file
	4) delete the slave's log file from slave when setup is complete
	----------------------------------------------------------------------
	_EOF_
	
	read -p "Please enter your user password: " 
	PROG_USER_PWD=$REPLY
}
#===================================================================================================================
func_create_copy_user_ssh_dir(){

	# if PROG_USER .ssh already exists, then make a copy so that the slaves can temporariarly be added to 
	# users known_host file, so that scp can copy the installation script to the slave, then restore when 
	# operation complete

	# a copy leaves the .ssh functional to login by user if an error occurs during the program.

	if [ -d /home/$PROG_USER/.ssh ]; then
		# .ssh exits, just make a copy
		cp -r /home/$PROG_USER/.ssh /home/$PROG_USER/.ssh_prior
	else 
		# setup temporary .ssh
		mkdir /home/$PROG_USER/.ssh		
	fi

	echo ""
	echo "chmod 700 /home/$PROG_USER/.ssh		"
	chmod 700 /home/$PROG_USER/.ssh		
	echo ""
	echo "chown -R $PROG_USER.$PROG_USER /home/$PROG_USER/.ssh"
	chown -R $PROG_USER.$PROG_USER /home/$PROG_USER/.ssh
}
#===================================================================================================================
func_delete_copy_user_ssh_dir(){

	# restore user .ssh, if existed, to original state

	rm -rf /home/$PROG_USER/.ssh

	if [ -d /home/$PROG_USER/.ssh_prior ]; then
		mv /home/$PROG_USER/.ssh_prior /home/$PROG_USER/.ssh
	fi
	
	echo ""
	echo "chmod 700 /home/$PROG_USER/.ssh"
	chmod 700 /home/$PROG_USER/.ssh	
	echo ""
	echo "chown -R $PROG_USER.$PROG_USER /home/$PROG_USER/.ssh"
	chown -R $PROG_USER.$PROG_USER /home/$PROG_USER/.ssh
}
#===================================================================================================================
func_send_public_key_to_slave(){

	# use sshpass & scp to copy the public key to the slave
	# using StrictHostKeyChecking=no will automatically add the remote host's key to the user's known_host file
	# but allow $PROG_USER to log into $PROG_USER's account on $IP with only a password
	# .ssh and known_hosts will be removed and the origial .ssh put back, if exited, upon program completion

	echo ""
	echo "Calling func_send_public_key_to_slave()"
	local IP=$1
	local PUB_KEY_FILE=/home/$ANSIBLE_UN/.ssh/id_rsa.pub
	
	echo ""
	echo "sshpass -p PROG_USER_PWD scp -o StrictHostKeyChecking=no $PUB_KEY_FILE $PROG_USER@$IP:~"
	sshpass -p "$PROG_USER_PWD" scp -o StrictHostKeyChecking=no $PUB_KEY_FILE "$PROG_USER@$IP:~"
}
#===================================================================================================================
func_send_script_to_slave(){

	# use sshpass & scp to copy the installation script to the slave
	# using StrictHostKeyChecking=no will automatically add the remote host's key to the user's known_host file
	# but allow $PROG_USER to log into $PROG_USER's account on $IP with only a password
	# .ssh and known_hosts will be removed and the origial .ssh put back, if exited, upon program completion

	echo ""
	echo "calling func_send_script_to_slave()"
	local IP=$1
	echo ""
	echo "sshpass -p PROG_USER_PWD scp -o StrictHostKeyChecking=no $PATH_TO_ANSIBLE_SETUP_FILES_DIR/$PROG_BASE_NAME $PROG_USER@$IP:~"
	sshpass -p "$PROG_USER_PWD" scp -o StrictHostKeyChecking=no $PATH_TO_ANSIBLE_SETUP_FILES_DIR/$PROG_BASE_NAME "$PROG_USER@$IP:~"
}
#===================================================================================================================
func_retrieve_slave_log_file(){

	# to void having to set the master's public key in the slave's known_host file by using scp to send
	# the slave's log file to the master, just let the master retrieve it, since the master's .ssh directory
	# is going to be replaced with it original .ssh, if it existed, anyway

	echo ""
	echo "Calling func_retrieve_slave_log_file()"
	local IP=$1
	echo ""
	echo "sshpass -p PROG_USER_PWD scp -o StrictHostKeyChecking=no $PROG_USER@$IP:~/$IP.log $LOG_FILES_PATH"
	sshpass -p $PROG_USER_PWD scp -o StrictHostKeyChecking=no $PROG_USER@$IP:~/$IP.log $LOG_FILES_PATH
}
#===================================================================================================================
func_remove_slave_log_file(){

	echo ""
	echo "Calling func_remove_slave_log_file()"
	local IP=$1
	echo ""
	echo "sshpass -p PROG_USER_PWD ssh -o StrictHostKeyChecking=no $PROG_USER@$IP rm -f $IP.log"
	sshpass -p $PROG_USER_PWD ssh -o StrictHostKeyChecking=no $PROG_USER@$IP "rm -f $IP.log"
}

#===================================================================================================================
func_execute_script_on_slave(){

	local REMOTE_IP=$1
	local PAUSE=30
	local EXPECT_TIMEOUT=120
	# PROG_USER_SELECTION=3 is required to force slave to run proper functions
	PROG_USER_SELECTION=3

	echo ""
	echo "Calling func_execute_script_on_slave()"
	echo ""
	echo "$PATH_TO_ANSIBLE_SETUP_FILES_DIR/expect-script.sh $ANSIBLE_UN $ANSIBLE_PWD $PROG_USER_SELECTION $SLAVE_FILE $REMOTE_IP $PROG_USER PROG_USER_PWD $EXPECT_TIMEOUT $SHOW_EXPECT_SCRIPT_MSG"
	echo ""

	# if this is the first slave, then show the message
	if [[ $SHOW_EXPECT_SCRIPT_MSG == 1 ]]; then

		SHOW_EXPECT_SCRIPT_MSG=0

		cat <<- _EOF_

		===============================================================================================================
		NOTE:  This message will display one time for $PAUSE seconds.
		---------------------------------------------------------------------------------------------------------------
		The script expect-script.sh that is about to run has a timeout setting of $EXPECT_TIMEOUT seconds, in case the 
			slave has a lot of files to yum update.

		In reading about using the Expect scripting language, timeouts as well as incorrect expectations of the 
			remote system's response are frequent sources of error.
			eg.  Your code expect a resonse of "abc", but "abc " is returned instead.

		I'm not sure this is actually the problem, but viewing the logs of slaves that hadn't been updated in awhile, 
			the update script appeared to quit while the slaves were still running yum upgrade.

		I read of similar issues by other users, and frequently the suggestion was that the timeout setting was set
			too low in their script.  The default is 10 seconds.

		If any errors occur, just rerun option 2 again for all or a limited number of slave ip addresses.

		The script can also be rerun manually, as per the instructions at the top of this script $PROG_BASE_NAME
		===============================================================================================================

		_EOF_
		
		# sleep for reader to read
		sleep $PAUSE
	fi

	$PATH_TO_ANSIBLE_SETUP_FILES_DIR/expect-script.sh \
		$ANSIBLE_UN \
		$ANSIBLE_PWD \
		$PROG_USER_SELECTION \
		$SLAVE_FILE \
		$REMOTE_IP \
		$PROG_USER \
		$PROG_USER_PWD \
		$EXPECT_TIMEOUT \
		$SHOW_EXPECT_SCRIPT_MSG
}
#===================================================================================================================
func_ssh-keyscan_ansible(){

	# ssh-keyscan will copy all the public keys from the nodes listed in SLAVE_FILE and add them
	# to the known_hosts for ANSIBLE_UN
	# this will avoid being prompted to accept rsa keys when connecting

	echo ""
	echo "running:  ssh-keyscan -4 -f $SLAVE_FILE >> /home/$ANSIBLE_UN/.ssh/known_hosts"
	ssh-keyscan -4 -f "$SLAVE_FILE" >> "/home/$ANSIBLE_UN/.ssh/known_hosts"

	# note:  as is, only the host name will be added to the known_hosts file, but the ip address would be helpful too
	# run the keyscan command again, but this time collect the keys asociated with the ip addresses

	# get the ip v4 version
	#IPV4=getent hosts | cut -d' ' -f1
	getent hosts | cut -d' ' -f1 > /tmp/ipv4.txt

	echo ""
	echo "running:  ssh-keyscan -4 /tmp/ipv4.txt >> /home/$ANSIBLE_UN/.ssh/known_hosts"
	ssh-keyscan -4 -f /tmp/ipv4.txt >> "/home/$ANSIBLE_UN/.ssh/known_hosts"

}
#===================================================================================================================
func_setup_slaves(){

	# process nodes
	echo ""
	# echo "Processing file: $SLAVE_FILE"
	for NODE in `cat $SLAVE_FILE`; do
		echo ""
		echo "Processing Node: $NODE"
	# I was going to try and run the functions in the background to parallelize the process, but it seems to
	# to be creating issues with the expect script.
	#	func_setup_slaves_detail $NODE &
		func_setup_slaves_detail $NODE 
		echo ""
	done
}
#===================================================================================================================
func_setup_slaves_detail(){

	# process addresses
	func_send_script_to_slave $NODE
	func_send_public_key_to_slave $NODE
	func_execute_script_on_slave $NODE	
	echo ""
	func_retrieve_slave_log_file $NODE
	func_remove_slave_log_file $NODE
	echo ""
	echo "Process complete for node: $NODE"
	echo ""
	
}

#===================================================================================================================
func_test_ansible_ssh(){

	# process addresses
	# invoke a script as the user ansible
	# that script then uses an expect script to log into each node in the cluster and verify that
	# 	the user ansible is able to ssh without a password to each node.

	echo ""
	echo "** Testing passwordless ssh for user $ANSIBLE_UN **"
	echo ""

	# change into the directory that contains the ansible scripts
	cd $PATH_TO_ANSIBLE_SETUP_FILES_DIR

	# unusual error message about permissions, this shouldn't be, force 777
	chmod 777 $PATH_TO_ANSIBLE_SETUP_FILES_DIR/expect-script-test-ssh.sh

	# process the master
	su -c "./test-ansible-ssh.sh $ANSIBLE_UN 0 $LOG_FILES_PATH $PATH_TO_ANSIBLE_SETUP_FILES_DIR" $ANSIBLE_UN 

	# process slaves
	su -c "./test-ansible-ssh.sh $ANSIBLE_UN 1 $LOG_FILES_PATH $PATH_TO_ANSIBLE_SETUP_FILES_DIR" $ANSIBLE_UN

	# make sure all of the ssh log files are owned by $PROG_USER
	chown -R $PROG_USER.$PROG_USER $LOG_FILES_PATH
}

#===================================================================================================================
func_menu_selection_1(){

	# functions to run for menu selection 1
	# prepare the master
	func_print_script_info
	func_update_system
	func_install_ansible
	func_install_other_software
	func_create_ansible_user
	func_set_ansible_sudoer_privileges
	func_create_set_ssh_keys_localhost

	# this was previously two functions.
	# merge for now.
#}
#===================================================================================================================
#func_menu_selection_2(){

	# function to run for menu selection 2 
	# preparing the master to setup the slaves

	# 1) print info & get password
	#func_print_script_info
	#func_get_user_passwd

	# 2) prepare master for slave update
	func_install_sshpass
	func_install_expect
	func_create_copy_user_ssh_dir

	# 3) for each slave, copy over script, execute script using expect script, remove script
	func_setup_slaves

	# 4) collect all the host keys from slave nodes
	func_ssh-keyscan_ansible

	# 5) unprepare master for slave update
	func_delete_copy_user_ssh_dir
	# func_remove_sshpass
	func_remove_public_key_file

	# 6) test that the user ansible can ssh into all nodes (master and slaves)
	# I couldn't get around a wierd permission denied error on the expect-script-test-ssh.sh
	# even though the file was 777.  selinux isssue?
	# when i tested manually, i could su - ansible using the password
	# and ansible chould ssh into the localhost and the slave without being prompted for a password, so
	# I'm going to skip it for now.
	# func_test_ansible_ssh

	# expect needed for ssh testing, so remove last
	# func_remove_expect
}
#===================================================================================================================
func_run_on_slaves(){

	# functions to run on the slave
	func_print_script_info
	func_update_system
	func_install_other_software
	func_create_ansible_user
	func_set_ansible_sudoer_privileges
	func_create_set_ssh_keys_localhost
	func_get_master_rsa_pub	
	func_slave_script_delete_yourself
}
####################################################################################################################


case $PROG_USER_SELECTION in

	1) 	func_menu_selection_1
		;;

	#2) 	func_menu_selection_2
	#	;;

	3)	func_run_on_slaves	
		;;
esac

