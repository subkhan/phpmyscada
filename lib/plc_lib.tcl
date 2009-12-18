#$Log: plc_lib.tcl,v $
#Revision 1.1.1.1  2002/10/22 20:43:02  riesco
#First import
#
#Revision 1.3  2001/05/17 11:40:10  triescoh
#Eliminated the errors communicating with PLC... for now...
#
#Revision 1.4  2002/10/17 11:36:38  triescoh

#Enter the log message
#
#Load DB lib
source "./db_lib.tcl"
source "config.inc.tcl"
source "general_lib.tcl"

	##########################################
	# Function: read_data
	# Return: values read
	# Input: port to be read, name of PLC
	# Description: Is executed each time that the port is readable
	##########################################
#   global plc_db_asked
#   global plc_db_sent

proc read_data {port} {

   global plc_db_asked
   global plc_db_sent
   set bcc 0
	set byte_received [read_byte $port ]
	#puts "We receive $byte_received by: $port"

	switch $byte_received {
		02 {
			#puts "Received STX "
			write_byte $port 10

			#puts "Sent DLE "

			set first_data [read_byte $port]
			for {set i 0} { $i< 2 } { incr i } {
				lappend first_data  [read_byte $port]

			}
			#puts $first_data
			if {$first_data == "00 00 00"} {
			set data $first_data
			# The command 3th byte it's 00 so...There is an answer to our asking and after the 00 00 00 00 the plc sends the data or there is an acknolege... and it send 00 00 00 00 or it is an error: 00 00 00 errorcode (see SIEMENS documentation)
				while { 1 } {
                       			set data1 [read_byte $port ]
					if { $data1 == "10" } {
       		                         	if { [ read_byte $port ] == "03" } {
 							# Check for 10 03 to finish
							set bcc [read_byte $port]
                        	               		break
                                		}
                        		}
                       			lappend data $data1
				}
				#lappend data 10 03 $bcc

				write_byte $port 10
                	        #DEBUG puts "Sent DLE, end of communication \n------------"

				#puts "Data asked: $data"
				#Write DBASKED with values
        	                db_write $data $plc_db_asked

				
			} else {
				# There is data sent without asking. The first 10 bytes are information about the data.
				set data $first_data
				while { 1 } {
                                set data1 [read_byte $port ]
                                        if { $data1 == "10" } {
                                                if { [ read_byte $port ] == "03" } {
                                                        # Check for 10 03 to finish
                                                        set bcc [read_byte $port]
                                                        break
                                                }
                                        }
                                        lappend data $data1
				}
				#lappend data 10 03 $bcc
				#write_line $output_buffer $data
                                #puts "Data sent by the PLC: $data"
				#Write DB10 with values comming
				db_write $data $plc_db_sent
				write_byte $port 10
                                #DEBUG puts "Sent DLE, end of communication \n------------"
                		# The plc has sent data without request, we answer with 00 00 00 00 OK
                		write_data $port  "00 00 00 00"
		#		puts "Sent ACK to the PLC"

			}
			#DEBUG puts "BCC Received: $bcc"
			#DEBUG puts "BCC Calculate: [calculate_bcc $data]"
			#puts -nonewline $port [binary format H2 "10"]
			#flush $port
			#DEBUG puts "Sent DLE, end of communication \n------------"
			# set real_data [data_handle $port $data]
			# DEBUG:
			#puts "\n\nReal Data: $real_data \n"
		}
		10 	{ puts "Received: 0x10" }
		default	{ puts "Received: $byte_received" }
	}	
}

	##########################################
	# Function: data_handle
	# Return:
	# Input: port from where come the data, the data and the PLC name
	# Description: This function handle the data that come from the PLC's and do modifications to be uniform
	##########################################

proc data_handle {port data} {

}



	##########################################
	# Function: read_byte
	# Return: data read
	# Input:  port to be read
	# Description: Is used to read 1 byte from the port. Is a general function
	##########################################

proc read_byte { port } {
	set i 0

	while { $i < 10 } {

		if { [binary scan [read $port 1] H2 byte_ascii ] } { break }
		after 50

		# We wait 1 second (100 * 10 ms)
		incr i
	}
	if {[info exist byte_ascii]} {

		return $byte_ascii
	} else {
	#	return "00"
	}

}

      ##########################################
        # Function: write_byte
        # Return: error
        # Input:  port to write, byte to write
        # Description: Is used to write 1 byte to the port. Is a general function
        ##########################################

proc write_byte { port byte} {

	puts -nonewline $port [binary format H2 $byte]
        flush $port

}

	##########################################
	# Function: write_data
	# Return:
	# Input: port to be written, data to be written
	# Description: Is general, write data in the PLC according to the protocol
	##########################################

proc write_data { port data1 } {

	write_byte $port 02
	#DEBUG puts "Sent STX "

	# If there is some 10 in data1 we have to doble (SIEMENS 3964)
	
	foreach byte $data1 {
		if { $byte == "10" } { set byte "10 10" }
 		lappend data $byte

	}
	set byte_received [read_byte $port ]
	# We check for a collision STX -> <- STX if there is, we read waiting for a 10 DLE. Because we have HIGH priority.
	#if {$byte_received == "02"} {
	#set byte_received [read_byte $port ]
	#}

	if { $byte_received == "10" } {
		#DEBUG puts "Received DLE "

		lappend data "10" "03"  [calculate_bcc $data]
		foreach byte $data {
		#DEBUG puts "byte inside write_data: $byte"
			write_byte $port $byte
		}
	
		#DEBUG puts "Written: $data "
		set byte_received [read_byte $port ]
		if { $byte_received  != "10" } {
			#DEBUG puts "Received $byte_received  "
			#log "ERROR: In write_data, after write the data, we have not received DLE (10) We have received $byte_received "
		}
	} else {
	puts "Error writing data received $byte_received and not 10"
		#log "ERROR: In write_data, after write STX (0x02) to start the communication, we have not received DLE (10) We have received $byte_received "
	}
	
	
}


	##########################################
	# Function: calculate_bcc
	# Return: BCC
	# Input: data
	# Description: Calculates the BCC adding the DLE and ETX. do a XOR with all the values
	##########################################

proc calculate_bcc {datain} {
	set last 0
	lappend datain "10" "03"; # For BCC calculation
	foreach value_hex $datain {
		scan $value_hex %x value_dec
		set new [expr $last ^ $value_dec]
		set last $new
	}
	return [format %02x $new]
	
}


	##########################################
	# Function: send_command_to_plc
	# Return:
	# Input:command: send or fetch; command_type: type of data to be transfered
	# 'D'=datablock; 'E'=input bytes; 'M'= Flag bytes etc.
	# Description: Sends the telegrams to send/fetch data in the plc
	##########################################
	#
proc send_command_to_plc {port command command_type address number} {
	switch $command {
	SEND 	{ set command 41}
	FETCH	{ set command 45}
	}
	# Definitions by SIEMENS...
	switch $command_type {
		DATABLOCK	{ set command_type 44 }
		INPUTBYTE	{ set command_type 45 }
		FLAGBYTE	{ set command_type 4d }
		COUNTERLOCATION	{ set command_type 5a }
		ABSOLUTEADDRESS	{ set command_type 53 }
		EXTENDEDIO	{ set command_type 51 }
		EXTENDEDDB	{ set command_type 58 }
		OUTPUTBYTE	{ set command_type 41 }
		IOBYTE		{ set command_type 50 }
		TIMERLOCATION	{ set command_type 54 }
		SYSTEMADDRESS	{ set command_type 42 }

	}
	# Siemens works with hexa
	set number [format %02x $number]
	set address [format %02x $address]
	#global port1
	#global port2
	##########################
	# We ask values to the plc ACS and MIS ...
	##########################

	write_data $port "00 00 $command $command_type $address 00 00 $number ff 1f"
	#puts "Sent: write_data $port 00 00 $command $command_type $address 00 00 $number ff 1f"
	#write_data $port2 "00 00 $fetch $datablock 0a 00 00 34 ff 1f"
	##########################
	# After T we ask new values
	##########################

	#after 30000 ask_values_to_plc
}
proc send_data_to_plc {port command command_type address number data} {
        switch $command {
        SEND    { set command 41}
        FETCH   { set command 45}
        }
        # Definitions by SIEMENS...
        switch $command_type {
                DATABLOCK       { set command_type 44 }
                INPUTBYTE       { set command_type 45 }
                FLAGBYTE        { set command_type 4d }
                COUNTERLOCATION { set command_type 5a }
                ABSOLUTEADDRESS { set command_type 53 }
                EXTENDEDIO      { set command_type 51 }
                EXTENDEDDB      { set command_type 58 }
                OUTPUTBYTE      { set command_type 41 }
                IOBYTE          { set command_type 50 }
                TIMERLOCATION   { set command_type 54 }
                SYSTEMADDRESS   { set command_type 42 }

        }
        # Siemens works with hexa
        set number [format %02x $number]
        set address [format %02x $address]
	foreach byte $data {
		set hexa_byte [format %02x $byte]
		lappend data_hexa $hexa_byte 
	}
        #global port1
        #global port2
        ##########################
        # We ask values to the plc ACS and MIS ...
        ##########################
        write_data $port "00 00 $command $command_type $address 00 00 $number ff 1f $data_hexa"
        #puts "Sent:  $data_hexa to address: $address"
        #write_data $port2 "00 00 $fetch $datablock 0a 00 00 34 ff 1f"
        ##########################
}

	##########################################
	# Function: send_telegram
	# Return: 
	# Input: port
	# Description: Send the telegram from the database to the PLC to ask or send data
	##########################################



proc send_telegram { port } {

  	global rentry   
   	
	# Query the DB to ask the first telegram to be sent    
   	set telegram [db_query data_plc "SELECT * FROM TELEGRAM LIMIT 1"]
	if {[ llength $telegram ] > 9 } {
		puts "telegram exists: $telegram"
		
		set Id [lindex $telegram 0]
		if { [lindex $telegram 3] == "45" } {
      		  	# It's a FETCH we don't send data...
      		  	write_data $port [lrange $telegram 1 10]
	      	} elseif {[lindex $telegram 3] == "41"  } {
  		      	# It's a SEND we send data...
			# To eliminate the {}
		        set telegram [join $telegram]

      		   	write_data $port [lrange $telegram 1 end]
			#puts [lrange $telegram 1 end]	
	     	} else {
   		     	#there is a erroneus telegram !!! we do nothing
	     	}
	      	# we erase the telegram sent
	      	db_command data_plc "DELETE FROM TELEGRAM WHERE Id='$Id'"
	   }
	after $rentry [list send_telegram $port]
}
   

   ##########################
   # write_data $port "00 00 $command $command_type $address 00 00 $number ff 1f $data_hexa"
   ##########################


