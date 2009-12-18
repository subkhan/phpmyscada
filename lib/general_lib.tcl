proc mailto {name subj text} {
	set f [open "|mail $name" w]
	puts  $f "Subject: $subj\n\n$text"
	close $f
}

 #  read the file one line at a time
 proc read_file { file } {
     set fp [open $file r]
     fconfigure $fp -buffering line
     gets $fp data
     set data_return $data
     while {$data != ""} {
          lappend $data_return $data
          gets $fp data
     }
     close $fp
     return $data
}

proc read_line { file } {
	set fp [open $file r]
	gets $fp data
	close $fp
	return $data
}


proc write_line { file  line } {
        #set data "This is some test data.\n"
        # pick a filename - if you don't include a path,
        #  it will be saved in the current directory
        #set filename $file
        set fp [open $file "w"]
        # send the data to the file -
        #  failure to add '-nonewline' will result in an extra newline
        # at the end of the file
	puts $line
        puts $fp $line
        # close the file, ensuring the data is written out before you continue
        #  with processing.
        close $fp
}
