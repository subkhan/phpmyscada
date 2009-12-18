#!/bin/sh
# start with TCL \
	exec tclsh "$0" ${1+"$@"}

proc init { } {
	##################
	#  Global variables..
	#
	#
	##################

	global port1


	##############################
	# Load the library for TCL and MySQL.
	##############################
	load /programs/sps/programs/mysql/sql.so


	##############################
	# Load the plc library for RK512.
	##############################
	source ./plc_lib.tcl

	##############################
	# Put RUNNING in db data.command.
	##############################

	# db_command data "UPDATE command SET last_change = NOW(),current_status = 'RUNNING' , new_status = '' WHERE command = 'START-STOP Application'"

	######################
    	# PLC ports configuration and FB configuration
    	######################

	set port1 [open /dev/ttyS0 r+ ]
	#set port2 [open /dev/ttyS1 r+ ]
	#set fb [open /dev/ttyS2 r ]
	fconfigure $port1 -blocking 0 -mode 9600,e,8,1   -translation { binary binary }  -buffering full
	#fconfigure $port2 -blocking 0 -mode 9600,e,8,1   -translation { binary binary }  -buffering full
	#fconfigure $fb -blocking 0 -mode 9600,e,7,1   -translation { binary binary }  -buffering none
	puts "Serial ports configurated."

	######################
	# Each time the ports are readables, we call the functions event-driven
	######################

	fileevent $port1 readable [list read_data $port1]
	#fileevent $port2 readable [list read_data $port2]
	#fileevent $fb readable [list read_fb $fb]

	puts "File events (PLC) configurated"
	###################
	#
	###################



	

	##########################
	# Init, We start RK512 Driver
	##########################

	send_telegram $port1
#	send_command_to_plc $port1 FETCH DATABLOCK 10 50
#send_command_to_plc $port1 FETCH OUTPUTBYTE 00 100
#lappend data_to_send  33 22
#set data_to_send "34 34"
}
set times 0

proc ask_data { } {
	global port1
	global times
	#puts "Send 13 14 to plc"
	after 500 [list send_data_to_plc $port1 SEND DATABLOCK 111 2 "$times 01 01 01"]
	#puts "ask block 10"

	after 1000 [list send_command_to_plc $port1 FETCH DATABLOCK 111 2 ]
	#send_command_to_plc $port1 FETCH FLAGBYTE 00 50 
	puts "Times asked data: $times"
	incr times
	after 2000 ask_data
}

	init
	
	#ask_data

	vwait forever
