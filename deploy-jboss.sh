#!/bin/bash

# Purpose
# To manage the deployment of jboss/wildfly to one or more managed (slave) nodes.

#########################################################################################################
# global varibles
#########################################################################################################
PATH_TO_WILDFLY_SETUP_FILES_DIR=`pwd`/wildfly-setup

ANSIBLE_UN="ansible"
ANSIBLE_PWD="ansible"
ANSIBLE_HOME=/home/$ANSIBLE_UN

PATH_TO_ANSIBLE_SETUP_FILES_DIR=`pwd`/ansible-setup
ANSIBLE_SETUP_FILE_NAME=ansible-setup.sh
PATH_TO_ANSIBLE_SETUP_FILE=$PATH_TO_ANSIBLE_SETUP_FILES_DIR/$ANSIBLE_SETUP_FILE_NAME

PATH_TO_SLAVES_FILE_DIR=$PATH_TO_ANSIBLE_SETUP_FILES_DIR
SLAVE_FILE_NAME=slaves.txt
PATH_TO_SLAVES_FILE=$PATH_TO_SLAVES_FILE_DIR/$SLAVE_FILE_NAME

PATH_TO_PASSWORD_FILE_DIR=$PATH_TO_ANSIBLE_SETUP_FILES_DIR
PASSWORD_FILE_NAME=password.txt
PATH_TO_PASSWORD_FILE=$PATH_TO_PASSWORD_FILE_DIR/$PASSWORD_FILE_NAME

#########################################################################################################
# check input data
#########################################################################################################
# check that the user has added the ip addresses to the slaves.txt file
func_test_slaves_ip_address(){
    echo ""
    echo "Have you added the slave ip addresses (one per line) to the following file? " 
    echo ""
    echo "$PATH_TO_SLAVES_FILE"
    echo ""
    read -p "Enter Selection [y/n]: "
    echo ""

    if [ "$REPLY" = 'y' ] || [ "$REPLY" = 'Y' ]; then
        echo "Thank you."
    elif [ "$REPLY" = 'n' ] || [ "$REPLY" = 'N' ]; then
        echo "IP addresses must be added to the following file:"
        echo "$PATH_TO_SLAVES_FILE"
        echo "exit 1"
        echo ""
        exit 1
    else
        echo "Invalid input."
        echo "exit 1"
        echo ""
        exit 1
    fi
}

# check that the user has added their to the password.txt file
func_test_password_file(){
    echo ""
    echo "Have you added your password to the following file?"
    echo ""
    echo "$PATH_TO_PASSWORD_FILE"
    echo ""
    read -p "Enter Selection [y/n]: "
    echo ""

    if [ "$REPLY" = 'y' ] || [ "$REPLY" = 'Y' ]; then
        echo "Thank you."
    elif [ "$REPLY" = 'n' ] || [ "$REPLY" = 'N' ]; then
        echo "Your password must be added to the following file:"
        echo "$PATH_TO_PASSWORD_FILE"    
        echo "exit 1"
        echo ""
        exit 1
    else
        echo "Invalid input."
        echo "exit 1"
        echo ""
        exit 1
    fi    
}

#########################################################################################################
# firewall setup
#########################################################################################################

func_firewall_setup(){
    # make sure we can ssh
    systemctl enable firewalld;
    systemctl start firewalld;
    firewall-cmd --permanent --add-service=ssh/tcp
    firewall-cmd --permanent --add-service=http/tcp
}

#########################################################################################################
# ansible setup
#########################################################################################################
# This script will install the necessary software on this (master) node, and managed (slave) nodes.
# A user called "ansible", with sudoer privileges, will be created on all nodes.

# variable needed for the ansible setup scripts
func_ansible_setup(){
    echo "`date`" > /tmp/1-ansible-setup-begin.txt

    PATH_TO_LOG_FILES_DIR=$PATH_TO_ANSIBLE_SETUP_FILES_DIR/output
    MASTER_LOG_FILE_NAME=master-log.txt
    PATH_TO_MASTER_LOG_FILE=$PATH_TO_LOG_FILES_DIR/$MASTER_LOG_FILE_NAME

    # parameters to ansible setup script
    #1
    # echo "ansible un = "$ANSIBLE_UN
    #2
    # echo "ansible pwd = "$ANSIBLE_PWD
    #3
    # 1=setup master
    PROG_USER_SELECTION=1 
    # echo "user selection = " $PROG_USER_SELECTION
    #4
    PROG_USER_PWD=`grep -v -e '^$' $PATH_TO_PASSWORD_FILE`
    # echo "user pwd = " $PROG_USER_PWD
    #5
    # echo "slave_file = " $PATH_TO_SLAVES_FILE
    #6
    SHOW_EXPECT_SCRIPT_MSG=0
    # echo "show expect script msg = " $SHOW_EXPECT_SCRIPT_MSG
    #7
    LOG_FILES_PATH=$PATH_TO_LOG_FILES_DIR
    # echo "log files path = " $LOG_FILES_PATH
    #8
    # echo "PATH_TO_ANSIBLE_SETUP_FILES_DIR = " $PATH_TO_ANSIBLE_SETUP_FILES_DIR    

    # start ansible setup script with parameters
    $PATH_TO_ANSIBLE_SETUP_FILE \
        $ANSIBLE_UN \
        $ANSIBLE_PWD \
        $PROG_USER_SELECTION \
        $PROG_USER_PWD \
        $PATH_TO_SLAVES_FILE \
        $SHOW_EXPECT_SCRIPT_MSG \
        $LOG_FILES_PATH \
        $PATH_TO_ANSIBLE_SETUP_FILES_DIR | tee -a /tmp/ansible-setup1.log    

    # copy needed files and directories to ansible's home dir and set ownership
    ANSIBLE_LOCAL_HOSTS_DIR=$ANSIBLE_HOME/local_hosts
    ANSIBLE_LOCAL_HOSTS_FILE=$ANSIBLE_LOCAL_HOSTS_DIR/hosts

    cp -r $PATH_TO_ANSIBLE_SETUP_FILES_DIR/jboss_wildfly_playbooks/ $ANSIBLE_HOME/jboss_wildfly_playbooks/
    cp -r $PATH_TO_ANSIBLE_SETUP_FILES_DIR/local_config/ $ANSIBLE_HOME/local_config/
    cp -r $PATH_TO_ANSIBLE_SETUP_FILES_DIR/local_hosts/ $ANSIBLE_LOCAL_HOSTS_DIR
    cp -r $PATH_TO_ANSIBLE_SETUP_FILES_DIR/local_includes/ $ANSIBLE_HOME/local_includes    

    ln -s $ANSIBLE_HOME/local_config/ansible.cfg $ANSIBLE_HOME/ansible.cfg
    
    # set the ansible hosts file, for the software to know what nodes we'll manage
    echo "[master]" > $ANSIBLE_LOCAL_HOSTS_FILE
    echo `hostname -i` >> $ANSIBLE_LOCAL_HOSTS_FILE
    echo "" >> $ANSIBLE_LOCAL_HOSTS_FILE

    # let ansible know which nodes are the slaves
    echo "[slaves]" >> $ANSIBLE_LOCAL_HOSTS_FILE
    echo `cat $PATH_TO_SLAVES_FILE` >> $ANSIBLE_LOCAL_HOSTS_FILE
    echo "" >> $ANSIBLE_LOCAL_HOSTS_FILE

    chown -R $ANSIBLE_UN.$ANSIBLE_UN $ANSIBLE_HOME

    echo "`date`" > /tmp/1-ansible-setup-end.txt
}

#########################################################################################################
func_wildfly_setup(){
    echo "`date`" > /tmp/2-jboss-wildfly-setup-begin.txt

    chmod 755 $PATH_TO_WILDFLY_SETUP_FILES_DIR/wildfly-setup.sh

    # wierd permission errors
    #su - ansible -c "$PATH_TO_WILDFLY_SETUP_FILES_DIR/wildfly-setup.sh  $ANSIBLE_HOME $ANSIBLE_UN"
    
    $PATH_TO_WILDFLY_SETUP_FILES_DIR/wildfly-setup.sh  $ANSIBLE_HOME $ANSIBLE_UN

    echo "`date`" > /tmp/2-jboss-wildfly-setup-end.txt
}
# #########################################################################################################

#########################################################################################################
# execute functions
#########################################################################################################
echo "`date`" > /tmp/0-overall-setup-end.txt

# func_firewall_setup
func_test_slaves_ip_address
func_test_password_file
func_ansible_setup
func_wildfly_setup

echo "`date`" > /tmp/2-overall-setup-end.txt
