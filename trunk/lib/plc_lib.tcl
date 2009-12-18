#Revision 1.2  2005/12/19 09:08:24  mbuisann
#Application tcl/tk de controle d'acces Zora. ( Partie Poste de controle Linux )
#
#Version modifiee Octobre 2005.
#
#Revision 1.3  2001/05/17 11:40:10  triescoh
#Eliminated the errors communicating with PLC... for now...
#
#Revision 1.2  2001/05/17 11:36:38  triescoh
#Enter the log message
#
# Laurent Martin, ASSYSTEM 20-04-2008
# Adding of plc watchdogs (ACS & MIS). Reading of turnstile move status (user entry/exit) on plc.

	
	
	##########################################
	# Function: read_plc
	# Return: values read
	# Input: port to be read, name of PLC
	# Description: Is executed each time that the port is readable
	##########################################

proc read_plc {port plc} {

	set bcc 0
	set byte_received [read_byte $port ]
	if { $byte_received == "02" } {
		#DEBUG puts "Received STX "
		puts -nonewline $port [binary format H2 "10"]
		flush $port
		#DEBUG puts "Sent DLE "
		#if { [ info exist data ] } { unset data }

		while { 1 } {
						
			set data1 [read_byte $port ]
			
			
			if { $data1 == "10" } {
				if { [ read_byte $port ] == "03" } {
					set bcc [read_byte $port]
					break
				}

			}
			lappend data $data1
		}
		#DEBUG puts $data
		#DEBUG puts "BCC Received: $bcc"
		#DEBUG puts "BCC Calculate: [calculate_bcc $data]"
		puts -nonewline $port [binary format H2 "10"]
		flush $port
		#DEBUG puts "Sent DLE, end of communication \n--------------------------"
		data_handle $port $data $plc
		
	} else {
		#log "ERROR: We have received data from $plc. The first byte is not STX but $byte_received."

	}

}	

	##########################################
	# Function: data_handle
	# Return:
	# Input: port from where come the data, the data and the PLC name
	# Description: This function handle the data that come from the PLC's and do modifications to be uniform
	##########################################

proc data_handle {port data plc} {
	global users_database
	global values_acs
	global last_values_acs
	global last_values_mis
	global acs_values_waited
	global mis_values_waited
	#DEBUG puts "DATA RECEIVED form $plc : $data "

	if {[lrange $data 0 3] != "00 00 00 00"} {
		##########################
		# The plc has sent data without request, we answer with 00 00 00 00 OK
		##########################
		write_data $port  "00 00 00 00"
				
	} else {
		##########################
		# The data is an answer to our request: the PLC send 00 00 00 00 and the data,
		# we fill with 00 to have the same length of packets...
		##########################

		set data [linsert $data 0 00 00 00 00 00 00]
		#DEBUG puts "Data: $data\n"
		##########################
		# After T, we ask for new values....
		##########################
#		set memory 4d ; set datablock 44 ; set fetch 45; set send 41;
#		after 5000 [list write_data $port "00 00 $fetch $datablock 0a 00 00 34 ff 1f"]


	}

	if { [ llength $data ] > 100 } {

		switch $plc {
			"ACS" {
				#DEBUG puts "DATA RECEIVED form ACS : $data "
				set acs_values_waited 0	
				set values_acs $data

				#########################
				# Treat the values coming from the PLC about turnstile move.
				# This function (turnstile_manager) is in BA.tcl described
				#########################
				
				turnstile_manager [lrange $data 116 119]

				#########################
				# Write the values comming from the PLC to the Database
				# This function (db_manager_acs) is in db_manager.tcl described
				#########################
   	
				db_manager_acs $data

				if {$last_values_acs != $values_acs } {
					acs_manager $data
   	         				
					#########################
					# If the key has been taken or leaved put or leave the user from the database
					# users_database  and show new database
					#########################

					key_manager [lrange $data 42 47]
					set last_values_acs $values_acs
				}
			                                   		
			}
			"MIS" {
				set mis_values_waited 0
				set values_mis $data	
				
				#########################
				# Write the values comming from the PLC to the Database
				# This function (db_manager_mis) is in db_manager.tcl described
				#########################

				db_manager_mis $data
                if {$last_values_mis != $values_mis } {
    			
					mis_manager $data
					set last_values_mis $values_mis			
				}
			}
		}
	}
}
	
	##########################################
	# Function: read_byte
	# Return: data read
	# Input:  port to be read
	# Description: Is used to read 1 byte from the port. Is a general function
	##########################################

proc read_byte { port } {
	set i 0
	
	while { $i < 20 } {
		
		if { [binary scan [read $port 1] H2 byte_ascii ] } { break }
		after 50
		incr i
	}	
	if {[info exist byte_ascii]} {
	
		return $byte_ascii
	} else {
		return "00"
	}
	
}


	##########################################
	# Function: write_data
	# Return:
	# Input: port to be written, data to be written
	# Description: Is general, write data in the PLC according to the protocol
	##########################################

proc write_data { port data } {
	
	puts -nonewline $port [binary format H2 "02"]
	flush $port
	
	#DEBUG puts "Sent STX "
	set byte_received [read_byte $port ]
	# We check for a collision STX -> <- STX if there is, we read waiting for a 10 DLE. Because we have HIGH priority.
	if {$byte_received == "02"} {
		set byte_received [read_byte $port ]
	}

	if { $byte_received == "10" } {
		#DEBUG puts "Received DLE "

		lappend data "10" "03"  [calculate_bcc $data]
		foreach byte $data {
		#DEBUG puts "byte inside write_data: $byte"
			puts -nonewline $port [binary format H2 $byte]
			
		}
		flush $port
		#DEBUG puts "Written: $data "
		set byte_received [read_byte $port ]
		if { $byte_received  != "10" } {
			#DEBUG puts "Received $byte_received  "
			#log "ERROR: In write_data, after write the data, we have not received DLE (10) We have received $byte_received "
		}	
	} else {
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
	# Function: ask_values_to_plc
	# Return:
	# Input:
	# Description: Sends the telegrams to ask new values is activated each 5 seconds
	##########################################

proc ask_values_to_plc {} {
	global port1
	global port2
	global acs_values_waited
	global mis_values_waited
	
	if { $acs_values_waited == 1 } {
		# Cas ou aucune donnee attendue n'a ete recue sur le port 1 pendant 30s
		# => affichage des animtations d'acces en bleu pour signaler une deconnexion
		# de l'automate ACS
		acs_manager { 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 \
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 \
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 }
	}

	if { $mis_values_waited == 1 } {
		# Cas ou aucune donnee attendue n'a ete recue sur le port 2 pendant 30s
		# => affichage des etats machine en bleu pour signaler une deconnexion
		# de l'automate MIS
		mis_manager { 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 \
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 \
03 03 03 03 03 }
	}

	# Signalement que des donnees sont attendues. Ces etats sont remis a zero des qu'une 
	# donnee est recue sur le port en question (utilise pour le signe de vie des automates).
	set acs_values_waited 1;
	set mis_values_waited 1;

	##########################
	# We ask values to the plc ACS and MIS ...
	##########################
	set memory 4d ; set datablock 44 ; set fetch 45; set send 41;
	write_data $port1 "00 00 $fetch $datablock 0a 00 00 37 ff 1f"
	write_data $port2 "00 00 $fetch $datablock 0a 00 00 34 ff 1f"	
	
	##########################
	# After T we ask new values
	##########################
	after 30000 ask_values_to_plc
}
