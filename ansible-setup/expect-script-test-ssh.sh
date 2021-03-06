#!/usr/bin/expect -f

# Author:       Brian Sigurdson sigurdson.brian@gmail.com
# Date:         2018-10-30
# Description:  The purpose of this script is to test for a passwordless login on a remote host.

####################################################################################################################
#====================================================================================
# Comments from autoexpect:
#
# This Expect script was generated by autoexpect on Thu Oct  5 12:05:50 2017
# Expect and autoexpect were both written by Don Libes, NIST.
#
# Note that autoexpect does not guarantee a working script.  It
# necessarily has to guess about certain things.  Two reasons a script
# might fail are:
#
# 1) timing - A surprising number of programs (rn, ksh, zsh, telnet,
# etc.) and devices discard or ignore keystrokes that arrive "too
# quickly" after prompts.  If you find your new script hanging up at
# one spot, try adding a short sleep just before the previous send.
# Setting "force_conservative" to 1 (see below) makes Expect do this
# automatically - pausing briefly before sending each character.  This
# pacifies every program I know of.  The -c flag makes the script do
# this in the first place.  The -C flag allows you to define a
# character to toggle this mode off and on.

set force_conservative 0  ;# set to 1 to force conservative mode even if
			  ;# script was not run conservatively originally
if {$force_conservative} {
	set send_slow {1 .1}
	proc send {ignore arg} {
		sleep .1
		exp_send -s -- $arg
	}
}

#
# 2) differing output - Some programs produce different output each time
# they run.  The "date" command is an obvious example.  Another is
# ftp, if it produces throughput statistics at the end of a file
# transfer.  If this causes a problem, delete these patterns or replace
# them with wildcards.  An alternative is to use the -p flag (for
# "prompt") which makes Expect only look for the last line of output
# (i.e., the prompt).  The -P flag allows you to define a character to
# toggle this mode off and on.
#
# Read the man page for more info.
#
# -Don
#====================================================================================

# Note:  The following code could have been embedded directly in the ansible-setup.sh

set ansible_un			[lindex $argv 0]
set remote_ip 			[lindex $argv 1]

# set timeout -1 # infinite wait, could hang
# The default is 10 seconds, which should be fine for this script.
# The script only needs to do a quick log-in and log-out.
#set timeout $expect_timeout

spawn ssh $ansible_un@$remote_ip
# give the ssh a few seconds to start
sleep 5 

expect {
	timeout {puts "expect-script-test-ssh.sh timed out at:  expect \"$ \" #1"; exit}	
	"$ "
}

send "exit\r"
