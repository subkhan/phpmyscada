################################################
# Functions to write the MySQL DB with values camming from the PLC's
# There is 2 functions db_manager_acs and db_manager_mis .
# At the final there is commands to do queries if needed.
#
# Version 1.2
# Author: Tono Riesco 7-11-2002#
################################################

#DEBUG #!/bin/sh
#DEBUG # start with TCLSH \
	exec tclsh "$0" ${1+"$@"}



 	##############################
 	# Load the library for TCL and MySQL and config.
	##############################
	load /programs/sps/programs/mysql/sql.so
	source "config.inc.tcl"
	source "general_lib.tcl"
              		
	


	##########################################
	# Function: db_write
	# Return:
	# Input:  data comming from the PLC 
	# Description:  Put values from the PLC in DB MySQL.
	# The data is put in the different tables
	##########################################
	
proc db_write {data table} {
	global db_user; global db_passwd
	set conn [sql connect localhost $db_user $db_passwd]

	sql selectdb $conn data_plc

	# We change value from Hexa (ff fa) to decimal to put in the DB MySQL
        #scan $address %2x table_number
	
	set byte 0
	foreach index_value $data {
		# Write Database with values
		sql exec $conn " UPDATE $table SET `data` = '$index_value', `timestamp` = NOW() WHERE `byte` = '$byte' LIMIT 1"
		incr byte
	}
	sql disconnect $conn
	#puts $byte	
}

	##########################################
	# Function: db_command
	# Return:
	# Input: The Db to use and the SQL command
	# Description:  We do something in MySQL DB.
	##########################################
	

proc db_command {db command} {
	global db_user; global db_passwd
	set conn [sql connect localhost $db_user $db_passwd]
	sql selectdb $conn $db
	sql exec $conn "$command"
	set answer [sql fetchrow $conn]
	sql endquery $conn
	sql disconnect $conn
	return $answer
}
	##########################################
	# Function: db_query
	# Return: answer
	# Input: The Db to use and the SQL command
	# Description:  We do simples queries in MySQL DB.
	##########################################
	

proc db_query {db query} {
	global db_user; global db_passwd
	set conn [sql connect localhost $db_user $db_passwd]
	sql selectdb $conn $db
	sql query $conn $query
	set answer [sql fetchrow $conn]
	sql endquery $conn
	sql disconnect $conn
	return $answer
}

