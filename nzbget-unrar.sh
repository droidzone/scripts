#!/bin/sh 

### NZBGET POST-PROCESSING SCRIPT

# Name of script's configuration file
SCRIPT_CONFIG_FILE="nzbget-unrar.conf"

# Exit codes
POSTPROCESS_PARCHECK_CURRENT=91
POSTPROCESS_PARCHECK_ALL=92
POSTPROCESS_SUCCESS=93
POSTPROCESS_ERROR=94
POSTPROCESS_NONE=95

# Check if the script is called from nzbget
if [ "$NZBPP_DIRECTORY" = "" -o "$NZBOP_CONFIGFILE" = "" ]; then
	echo "*** NZBGet post-process script ***"
	echo "This script is supposed to be called from nzbget (0.7.0 or later)."
	exit $POSTPROCESS_ERROR
fi 

# Check if postprocessing was disabled in postprocessing parameters 
# (for current nzb-file) via web-interface or via command line with 
# "nzbget -E G O PostProcess=no <ID>"
if [ "$NZBPR_PostProcess" = "no" ]; then
	echo "[WARNING] Post-Process: Postprocessing disabled for this nzb-file, exiting"
	exit $POSTPROCESS_NONE
fi

echo "[INFO] Post-Process: Post-process script successfully started"

# Determine the location of configuration file (it must be stored in
# the directory with nzbget.conf or in this script's directory).
ConfigDir="${NZBOP_CONFIGFILE%/*}"
ScriptConfigFile="$ConfigDir/$SCRIPT_CONFIG_FILE"
if [ ! -f "$ScriptConfigFile" ]; then
	ConfigDir="${0%/*}"
	ScriptConfigFile="$ConfigDir/$SCRIPT_CONFIG_FILE"
fi
if [ ! -f "$ScriptConfigFile" ]; then
	echo "[ERROR] Post-Process: Configuration file $ScriptConfigFile not found, exiting"
	exit $POSTPROCESS_ERROR
fi

# Readg configuration file
while read line; do	eval "$line"; done < $ScriptConfigFile

# Check nzbget.conf options
BadConfig=0

if [ "$NZBOP_ALLOWREPROCESS" = "yes" ]; then
	echo "[ERROR] Post-Process: Please disable option \"AllowReProcess\" in nzbget configuration file"
	BadConfig=1
fi 

if [ "$NZBOP_LOADPARS" = "none" ]; then
	echo "[ERROR] Post-Process: Please set option \"LoadPars\" to \"One\" or \"All\" in nzbget configuration file"
	BadConfig=1
fi

if [ "$NZBOP_PARREPAIR" = "no" ]; then
	echo "[ERROR] Post-Process: Please set option \"ParRepair\" to \"Yes\" in nzbget configuration file"
	BadConfig=1
fi

if [ "$BadConfig" -eq 1 ]; then
	echo "[ERROR] Post-Process: Existing because of not compatible nzbget configuration"
	exit $POSTPROCESS_ERROR
fi 

# Check if all collections in nzb-file were downloaded
if [ ! "$NZBPP_NZBCOMPLETED" -eq 1 ]; then
	echo "[INFO] Post-Process: Not the last collection in nzb-file, exiting"
	exit $POSTPROCESS_SUCCESS
fi 

# Check par status
if [ "$NZBPP_PARSTATUS" -eq 1 -o "$NZBPP_PARSTATUS" -eq 3 -o "$NZBPP_PARFAILED" -eq 1 ]; then
	if [ "$NZBPP_PARSTATUS" -eq 3 ]; then
		echo "[WARNING] Post-Process: Par-check successful, but Par-repair disabled, exiting"
	else
		echo "[WARNING] Post-Process: Par-check failed, exiting"
	fi
	exit $POSTPROCESS_ERROR
fi 

# Check if destination directory exists (important for reprocessing of history items)
if [ ! -d "$NZBPP_DIRECTORY" ]; then
	echo "[ERROR] Post-Process: Nothing to post-process: destination directory $NZBPP_DIRECTORY doesn't exist"
	exit $POSTPROCESS_ERROR
fi

cd "$NZBPP_DIRECTORY"

# If not just repaired and file "_brokenlog.txt" exists, the collection is damaged
# exiting with returning code $POSTPROCESS_PARCHECK_ALL to request par-repair
if [ ! "$NZBPP_PARSTATUS" -eq 2 ]; then
	if [ -f "_brokenlog.txt" ]; then
		if (ls *.[pP][aA][rR]2 >/dev/null 2>&1); then
			echo "[INFO] Post-Process: Brokenlog found, requesting par-repair"
			exit $POSTPROCESS_PARCHECK_ALL
		fi
	fi
fi

# All checks done, now processing the files

# Flag indicates that something was unrared
Unrared=0
   
# Unrar the files (if any) to the temporary directory, if there are no rar files this will do nothing
if (ls *.rar >/dev/null 2>&1); then

	# Check if unrar exists
	$UnrarCmd >/dev/null 2>&1
	if [ "$?" -eq 127 ]; then
		echo "[ERROR] Post-Process: Unrar not found. Set the path to unrar in script's configuration"
		exit $POSTPROCESS_ERROR
	fi

	# Make a temporary directory to store the unrarred files
	ExtractedDirExists=0
	if [ -d extracted ]; then
		ExtractedDirExists=1
	else
		mkdir extracted
	fi
	
	echo "[INFO] Post-Process: Unraring"
	rarpasswordparam=""
	if [ "$NZBPR_Password" != "" ]; then
		rarpasswordparam="-p$NZBPR_Password"
	fi

	$UnrarCmd x -y -p- "$rarpasswordparam" -o+ "*.rar"  ./extracted/
	if [ "$?" -eq 3 ]; then
		echo "[ERROR] Post-Process: Unrar failed"
		if [ "$ExtractedDirExists" -eq 0 ]; then
			rm -R extracted
		fi
		# for delayed par-check/-repair at least one par-file must be already downloaded
		if (ls *.[pP][aA][rR]2 >/dev/null 2>&1); then
			echo "[INFO] Post-Process: Requesting par-repair"
			exit $POSTPROCESS_PARCHECK_ALL
		fi
		exit $POSTPROCESS_ERROR
	fi
	Unrared=1
   
	# Remove the rar files
	if [ "$DeleteRarFiles" = "yes" ]; then
		echo "[INFO] Post-Process: Deleting rar-files"
		rm *.r[0-9][0-9] >/dev/null 2>&1
		rm *.rar >/dev/null 2>&1
		rm *.s[0-9][0-9] >/dev/null 2>&1
	fi
	
	# Go to the temp directory and try to unrar again.  
	# If there are any rars inside the extracted rars then these will no also be unrarred
	cd extracted
	if (ls *.rar >/dev/null 2>&1); then
		echo "[INFO] Post-Process: Unraring (second pass)"
		$UnrarCmd x -y -p- -o+ "*.rar"

		if [ "$?" -eq 3 ]; then
			echo "[INFO] Post-Process: Unrar (second pass) failed"
			exit $POSTPROCESS_ERROR
		fi

		# Delete the Rar files
		if [ "$DeleteRarFiles" = "yes" ]; then
			echo "[INFO] Post-Process: Deleting rar-files (second pass)"
			rm *.r[0-9][0-9] >/dev/null 2>&1
			rm *.rar >/dev/null 2>&1
			rm *.s[0-9][0-9] >/dev/null 2>&1
		fi
	fi
	
	# Move everything back to the Download folder
	mv * ..
	cd ..
	rmdir extracted
fi

# If download contains only nzb-files move them into nzb-directory
# for further download
# Check if command "wc" exists
wc -l . >/dev/null 2>&1
if [ "$?" -ne 127 ]; then
	AllFilesCount=`ls -1 2>/dev/null | wc -l`
	NZBFilesCount=`ls -1 *.nzb 2>/dev/null | wc -l`
	if [ "$AllFilesCount" -eq "$NZBFilesCount" ]; then
		echo "[INFO] Moving downloaded nzb-files into incoming nzb-directory for further download"
		mv *.nzb $NZBOP_NZBDIR
	fi
fi

# Clean up
echo "[INFO] Post-Process: Cleaning up"
chmod -R a+rw .
rm *.nzb >/dev/null 2>&1
rm *.sfv >/dev/null 2>&1
rm *.1 >/dev/null 2>&1
rm _brokenlog.txt >/dev/null 2>&1
if [ "$Unrared" -eq 1 ]; then
	# Delete par2-file only if there were files for unpacking.
	rm *.[pP][aA][rR]2 >/dev/null 2>&1
fi

if [ "$JoinTS" = "yes" ]; then
	# Join any split .ts files if they are named xxxx.0000.ts xxxx.0001.ts
	# They will be joined together to a file called xxxx.0001.ts
	if (ls *.ts >/dev/null 2>&1); then
	    echo "[INFO] Post-Process: Joining ts-files"
		tsname=`find . -name "*0001.ts" |awk -F/ '{print $NF}'`
		cat *0???.ts > ./$tsname
	fi   
   
	# Remove all the split .ts files
    echo "[INFO] Post-Process: Deleting source ts-files"
	rm *0???.ts >/dev/null 2>&1
fi

if [ "$RenameIMG" = "yes" ]; then
	# Rename img file to iso
	# It will be renamed to .img.iso so you can see that it has been renamed
	if (ls *.img >/dev/null 2>&1); then
	    echo "[INFO] Post-Process: Renaming img-files to iso"
		imgname=`find . -name "*.img" |awk -F/ '{print $NF}'`
		mv $imgname $imgname.iso
	fi   
fi

# Check if destination directory was set in postprocessing parameters
# (for current nzb-file) via web-interface or via command line with 
# "nzbget -E G O DestDir=/new/path <ID>"
if [ "$NZBPR_DestDir" != "" ]; then
	mkdir $NZBPR_DestDir
	mv * $NZBPR_DestDir >/dev/null 2>&1
	cd ..
	rmdir $NZBPP_DIRECTORY
fi

# All OK, requesting cleaning up of download queue
exit $POSTPROCESS_SUCCESS
