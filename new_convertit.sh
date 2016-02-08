#!/bin/sh

##script should be given execute permissions and should be located in the data directory!
#Welcome
echo -en '\n'
echo -e "\e[0;31mWelcome to the new and more robust CONVERTIT. This simple UNIX script will \e[0m"
echo -e "\e[0;31mquickly convert dcm images to nifti, move and rename those nifti images to \e[0m"
echo -e "\e[0;31mtheir respective individual analysis directory, and prepare them for analysis \e[0m"
echo -e "\e[0;31min SPM. This version will populate all images (BOLD and anatomical) for all \e[0m"
echo -e "\e[0;31mtasks for a given participant.\e[0m"
echo -e "\e[0;31mType cntrl+c at any time to stop the script. \e[0m"
echo -en '\n'
echo "Created by Derek Pisner and Matt Allbright"

#Unset values
unset STUDY
unset RAW_data
unset VISIT
unset PARTIC
unset TASKVALUE
unset TASK
unset BOLDVALUE
unset BOLDDONE
unset ANATSTRING
unset ANAT
unset NumbAnat
unset ISBOTH

cd /data/

#Choose Study
echo -en '\n'

#Create study array for possible studies
studydirarray=(*/)
for STUDYDIR in ${studydirarray[*]}
do
	echo printf "%s\n" $STUDYDIR
done

#Checks if folders exist in base directory, then asks for study folder.
if [[ -n ${studydirarray[*]} ]]; then

	echo -en '\n'
	echo -e "\e[0;31mWhat is the name of the study?\e[0m"
	echo "Be aware that each of these is a folder name"
	echo "and that certain folders might not be studies."
	echo -en '\n'
	echo -e "If your study does not exist, type '\e[0;31mnew\e[0m' to"
	echo "create a new study."
	echo -en '\n'

	select STUDY in ${studydirarray[*]}
	do
		#If inputting correct study value
		if [[ $STUDY ]]; then
			break

		#New study creation, occurs if user input 'new'
		elif [[ $REPLY == "new" ]]; then
			unset 
			echo -en '\n'
			echo -e "\e[0;31mType in the name of the new study.\e[0m"
			echo -e "If you are seeing this screen by mistake, type '\e[0;31mback\e[0m'"
			echo "to return to the main menu."
			echo -en '\n'
			while read STUDY; do

				#Study already exists error
				if [[ -d /data/$STUDY ]]; then
					echo "This is already a valid study. Please input"
					echo "a new study or type 'back' to return to the main menu."
					echo -en '\n'

				#NEEDSWORK Sends user back to main menu
				elif [[ $STUDY == "back" ]]; then
					break

				#Makes directory based on user input
				else
					mkdir /data/$STUDY/
					echo "A new directory with name "$STUDY" has been created."
					echo "Restart this script and use your new directory."
					exit
				fi
			done

		#Fails if user input selects nonvalid study
		else
			echo -e "Nonvalid study. \e[0;31mPlease type in a valid study.\e[0m"
		fi
	done

#If no folders exist in base folder, it will prompt for new study creation
else
	echo "There appear to be no valid studies. To create a"
	echo -e "new study, just \e[0;31mtype the name of your study.\e[0m"
	read NEWSTUDY
	STUDY=$NEWSTUDY
fi

#New study folder creation
if [[ -n $NEWSTUDY ]] && [[ ! -d /data/$STUDY/ ]]; then
	mkdir -p $STUDY/RAW_data
	mkdir -p $STUDY/individual_analysis

	echo "Welcome to a new study creation session."
	echo "RAW_data and indiv_analysis have been created"
	echo -e "for you. Create more directories? \e[0;31my/n\e[0m"
	echo -en '\n'
	read NEWSTUDYFOLDER

	#If user chooses yes to create more directoriesm it will initialize a file which tracks all folders
	if [[ $NEWSTUDYFOLDER == "y" ]]; then
		touch $STUDY/folderlist.txt
		echo "RAW_data" >> $STUDY/folderlist.txt
		echo "indiv_analysis" >> $STUDY/folderlist.txt

		#New study folder creation (More directories edition)
		while [[ $DIRCREATEDONE == "n" ]]; do
			ls -d /$STUDY/
			echo -en '\n'
			echo "Type in a directory name to create it."
			read NEWDIRVALUE

			echo $NEWDIRVALUE >> folder.txt

			mkdir $STUDY/"$NEWDIRVALUE"

			echo -en '\n'
			ls -d /$STUDY/
			echo -en '\n'

			#Ending prompt
			echo -e "Does this complete the new directory setup? \e[0;31my/n\e[0m"
			while read DIRCREATEDONE; do
				if [[ $DIRCREATEDONE == "y" ]] || [[ $DIRCREATEDONE == "n" ]]; then
					break
				else
					echo "Please enter y/n."
				fi
			done
			echo -en '\n'
		done

	#If user okays that indiv_analysis and RAW_data are the only folders
	elif [[ $NEWSTUDYFOLDER == "n" ]]; then
		break

	#if user enters wrong value
	else
		echo "Please enter y/n."
	fi
fi

echo -en '\n'

#Choose Participant
echo -en '\n'
cd $STUDY/RAW_data/

#Create participant array for valid participants
particdirarray=`(ls -f | grep -E '[0-9][0-9][0-9]' | grep -v "_2")`
for PARTICDIR in ${particdirarray[*]}
do
	printf "%s\n" $PARTICDIR
done

#Determine if array exists
if [[ -n ${particdirarray[*]} ]]; then

	echo -en '\n'
	echo -e "\e[0;31mWhich participant?\e[0m"
	echo "Be aware that participants who are currently"
	echo "not setup on this terminal may not appear."
	echo -e "For new participants, please type '\e[0;31mnew\e[0m'."
	echo -en '\n'
	select PARTIC in ${particdirarray[*]}
	do

		if [[ $PARTIC ]]; then
			break

		#New partic creation
		elif [[ $REPLY == "new" ]]; then
			echo -en '\n'
			echo -e "\e[0;31mType in the name of the new participant.\e[0m"
			read NEWPARTIC
			PARTIC=$NEWPARTIC
			break
		else
			echo -e "Nonvalid participant. \e[0;31mPlease type in a valid participant.\e[0m"
		fi
	done
else
	echo -e "There appear to be no participants. \e[0;31mType in a name of\e[0m"
	echo -e "\e[0;31ma participant to begin processing.\e[0m"
	read PARTIC
fi
	

echo -en '\n'

#Choose Longitudinal or Single Visit
echo -en '\n'
echo -e "Longitudinal (\e[0;31m2\e[0m) or One-Day Visit (\e[0;31m1\e[0m)?"
while read VISITTYPE; do
	if [[ $VISITTYPE == "1" ]] || [[ $VISITTYPE == "2" ]]; then
		break
	else
		echo "Please enter a valid visit type."
	fi
done

if [ $VISITTYPE -eq "1" ]; then
	VISIT=dayofscan

elif [ $VISITTYPE -eq "2" ]; then

	#Choose Visit
	echo -en '\n'
	echo -e "Which visit (either \e[0;31mBaseline\e[0m or \e[0;31mPostTX\e[0m or \e[0;31mBoth\e[0m)?"
	while read VISIT; do
		if [[ $VISIT == "Baseline" ]] || [[ $VISIT == "PostTX" ]] || [ $VISIT == "Both" ]; then
			break
		else
			echo "Please enter a valid visit."
		fi
	done
fi

echo -en '\n'


if [[ $VISIT == "Baseline" ]] || [[ $VISIT == "dayofscan" ]] || [[ $VISIT == "Both" ]] && [[ -d /data/$STUDY/RAW_data/"$PARTIC" ]]; then
	echo "It appears that a RAW_data directory already exists."
	echo "Would you like to download shared data anyway?"
	echo "Some files might be overwritten. y/n"
	read NEWWRITE
elif [[ $VISIT == "Baseline" ]] || [[ $VISIT == "dayofscan" ]] && [[ ! -d /data/$STUDY/RAW_data/"$PARTIC" ]]; then
	NEWWRITE="y"
elif [[ $VISIT == "PostTX" ]] && [[ -d /data/$STUDY/RAW_data/""$PARTIC"_2" ]]; then
	echo "It appears that a participant's RAW_data directory already exists"
	echo "for this visit. Would you like to download shared data anyway?"
	echo "Some files might be overwritten. y/n"
	read NEWWRITE
elif [[ $VISIT == "PostTX" ]] || [[ $VISIT == "Both" ]] && [[ ! -d /data/$STUDY/RAW_data/""$PARTIC"_2" ]]; then
	NEWWRITE="y"
fi

#Baseline or Single Visit
#Test for 'Both' variant
if [[ $VISIT == "Both" ]]; then
	ISBOTH="TRUE"
	VISIT="Baseline"
fi

#Check if participant RAW_directory exists for Baseline or Single Visit. If not, find Participant's raw dicom directory from Hermes mount and copy to the STUDY RAW_data folder. If folder exists under a non "_scan" name, it will search for one without "_scan" appended to the end.

#Baseline/Dayofscan test
if [[ $VISIT == "Baseline" ]] || [[ $VISIT == "dayofscan" ]] && [[ $NEWWRITE == "y" ]]; then

	Num=`echo $PARTIC | grep -Eo '[0-9][0-9][0-9]'`
	if [ -d /Hermes/"$STUDY"_scans ]; then
		echo "This is your first run and might take a very long time."
		OSIRIX=`find /Hermes/"$STUDY"_scans -maxdepth 1 -iname "*$Num*" -print | sort | tail -1 | sed 's/.*\///'`
		cd /Hermes/"$STUDY"_scans/"$OSIRIX"
		target_dir=`ls /Hermes/"$STUDY"_scans/"$OSIRIX"`
		cp -a "$target_dir" /data/$STUDY/RAW_data
		mv /data/$STUDY/RAW_data/"$target_dir" /data/$STUDY/RAW_data/"$PARTIC"
	else
		echo "This is your first run and might take a very long time."
		OSIRIX=`find /Hermes/"$STUDY" -maxdepth 1 -iname "*$Num*" -print | sort | tail -1 | sed 's/.*\///'`
		cd /Hermes/"$STUDY"/"$OSIRIX"
		target_dir=`ls /Hermes/"$STUDY"/"$OSIRIX"`
		cp -a "$target_dir" /data/$STUDY/RAW_data
		mv /data/$STUDY/RAW_data/"$target_dir" /data/$STUDY/RAW_data/"$PARTIC"
	fi

#Check if participant RAW_directory exists for PostTX. If not, find Participant's raw dicom directory from Hermes mount and copy to the STUDY RAW_data.  If folder exists under a non "_scan" name, it will search for one without "_scan" appended to the end.

#PostTX
#Test for 'Both' variant
if [[ $ISBOTH == "TRUE" ]]; then
	VISIT="PostTX"
fi

#PostTX test
elif [[ $VISIT == "PostTX" ]] && [[ $NEWWRITE == "y" ]]; then

	Num=`echo $PARTIC | grep -Eo '[0-9][0-9][0-9]'`
	if [ -d /Hermes/"$STUDY"_scans ]; then
		echo "This is your first run and might take a very long time."
		OSIRIX=`find /Hermes/"$STUDY"_scans -maxdepth 1 -iname "*$Num*" -print | sort | head -1 | sed 's/.*\///'`
		cd /Hermes/"$STUDY"_scans/"$OSIRIX"
		target_dir=`ls /Hermes/"$STUDY"_scans/"$OSIRIX"`
		cp -a "$target_dir" /data/$STUDY/RAW_data
		mv /data/$STUDY/RAW_data/"$target_dir" /data/$STUDY/RAW_data/"$PARTIC"_2 
	else
		echo "This is your first run and might take a very long time."
		OSIRIX=`find /Hermes/"$STUDY" -maxdepth 1 -iname "*$Num*" -print | sort | head -1 | sed 's/.*\///'`
		cd /Hermes/"$STUDY"/"$OSIRIX"
		target_dir=`ls /Hermes/"$STUDY"/"$OSIRIX"`
		cp -a "$target_dir" /data/$STUDY/RAW_data
		mv /data/$STUDY/RAW_data/"$target_dir" /data/$STUDY/RAW_data/"$PARTIC"_2 
	fi
fi

#Check if participant directory exists. Create Participant's individual analysis directory from template "x."  Prompt user for specifics if "x" directory doesn't exist. This will run on first launch, as no directories have been made.
if [[ ! -d /data/$STUDY/indiv_analysis/"$PARTIC" ]]; then

	unset TEMPLATECORRECT
	cd /data/"$STUDY"/indiv_analysis
	
	if [[ ! -d /data/"$STUDY"/indiv_analysis/x ]]; then
		TEMPLATECORRECT=n
	else
		echo -en '\n'
		echo "A templated directory already exists."
		echo "Below is a list of all the analysis folders."
		echo -en '\n'
		cat /data/"$STUDY"/indiv_analysis/x/tasks.txt
		echo -en '\n'
		echo -e "\e[0;31mIs this correct? y/n \e[0m"
		while read TEMPLATECORRECT; do
			if [[ $TEMPLATECORRECT == "y" ]] || [[ $TEMPLATECORRECT == "n" ]]; then
				break
			else
				echo "Please enter y/n."
			fi
		done
	fi

	#If user answered 'n' to the previous statement, new 'x' directory will be created.
	if [[ $TEMPLATECORRECT == "n" ]]; then
		if [[ -d /data/"$STUDY"/indiv_analysis/x ]]; then
			rm -r x
		fi
		mkdir x
		cd x
		mkdir analysis/
		mkdir -p bold/rest/
		mkdir fieldmaps/

		touch tasks.txt

		#Dayofvisit Setup
		if [ $VISITTYPE -eq "1" ]; then
			mkdir -p 3danat_rest/dayofscan/
			mkdir -p bold/rest/dayofscan/
			mkdir -p fieldmaps/rest/Mag/dayofscan/
			mkdir -p fieldmaps/rest/Phase/dayofscan/

			#Baseline/PostTX Setup
		elif [ $VISITTYPE -eq "2" ]; then
			mkdir -p 3danat_rest/Baseline/
			mkdir -p 3danat_rest/PostTX/
			mkdir -p bold/rest/Baseline/
			mkdir -p bold/rest/PostTX/
			mkdir -p fieldmaps/rest/Mag/Baseline/
			mkdir -p fieldmaps/rest/Mag/PostTX/
			mkdir -p fieldmaps/rest/Phase/Baseline/
			mkdir -p fieldmaps/rest/Phase/PostTX/
		fi

		echo "rest" >> tasks.txt
		echo -en '\n'
		echo -e "Does your setup require only the rest test (ie no anticipation test)? \e[0;31my/n\e[0m"
		echo "This is incredibly uncommon. Type 'n' if you're not sure."
		while read BOLDDONE; do
			if [[ $BOLDDONE == "y" ]] || [[ $BOLDDONE == "n" ]]; then
				break
			else
				echo "Please enter y/n."
			fi
		done

		#BOLD/3danat folder creation and templating
		while [[ $BOLDDONE == "n" ]]; do
			cat tasks.txt
			echo -en '\n'
			echo -e "Welcome to the 3danat/BOLD setup. \e[0;31mType a test name\e[0m to create folder template." 
			echo "The common folder 'rest' has already been created."
			read BOLDVALUE

			echo $BOLDVALUE >> tasks.txt

			mkdir 3danat_"$BOLDVALUE"
			mkdir -p bold/$BOLDVALUE

			#Dayofvisit Setup
			if [ $VISITTYPE -eq "1" ]; then
				mkdir -p 3danat_"$BOLDVALUE"/dayofscan/
				mkdir -p bold/"$BOLDVALUE"/dayofscan/
				mkdir -p fieldmaps/"$BOLDVALUE"/Mag/dayofscan/
				mkdir -p fieldmaps/"$BOLDVALUE"/Phase/dayofscan/

			#Baseline/PostTX Setup
			elif [ $VISITTYPE -eq "2" ]; then
				mkdir -p 3danat_"$BOLDVALUE"/Baseline/
				mkdir -p 3danat_"$BOLDVALUE"/PostTX/
				mkdir -p bold/"$BOLDVALUE"/Baseline/
				mkdir -p bold/"$BOLDVALUE"/PostTX/
				mkdir -p fieldmaps/"$BOLDVALUE"/Mag/Baseline/
				mkdir -p fieldmaps/"$BOLDVALUE"/Mag/PostTX/
				mkdir -p fieldmaps/"$BOLDVALUE"/Phase/Baseline/
				mkdir -p fieldmaps/"$BOLDVALUE"/Phase/PostTX/
			fi

			echo -en '\n'
			cat tasks.txt
			echo -en '\n'
			
			echo -e "Does this complete the 3danat BOLD setup? \e[0;31my/n\e[0m"
			while read BOLDDONE; do
				if [[ $BOLDDONE == "y" ]] || [[ $BOLDDONE == "n" ]]; then
					break
				else
					echo "Please enter y/n."
				fi
			done
			echo -en '\n'
		done
		#Removes extraneous 3danat folder created in the previous step
		rm -r 3danat_/
	fi

	#Copy newly designed "x" template. 
	cd /data/$STUDY/indiv_analysis/
	cp -R ./x ./"$PARTIC"
	cd ../
	
fi

cd /data/$STUDY/

##Create Run Log
rm -f /data/$STUDY/indiv_analysis/$PARTIC/runlog.txt
touch /data/$STUDY/indiv_analysis/$PARTIC/runlog.txt

if [[ $ISBOTH == "TRUE" ]]; then
	VISIT="Baseline"
fi

##BASELINE/DAYOFSCAN
#Baseline/Day of Scan Check Phase
echo -en '\n'
echo "Baseline/Day of Scan Check Phase"
echo -en '\n'
echo "You entered" $VISIT
echo -en '\n'

if [[ $VISIT == "Baseline" ]] || [[ $VISIT == "dayofscan" ]] || [[ $VISIT == "Both" ]]; then
	echo -e "\e[0;32mBaseline/Day of Scan Check Passed!\e[0m"
	echo -en '\n'

	cd /data/$STUDY
	#Remove all spaces and hyphens with underscores in raw directory names
	cd ./RAW_data/"$PARTIC"/
	for f in *\ *; do mv "$f" "${f// /_}"; done

	cd /data/$STUDY

	#Will there be a repeat Anatomical?
	NumbAnat=`find /data/$STUDY/RAW_data/"$PARTIC"/ -iname 'T1_MPRAGE_1MM*' -print | wc -l`

	#If anatomical directory not found, prompt user for new string and search it.
	if [[ $NumbAnat == "0" ]]; then

		#Find T1 Anat String
		echo -en '\n'
		echo "Anatomical Directory not found."
		echo "Type in part of the name of the Anatomical directory you would like to search for."
		read ANATSTRING
		NumbAnat=`find /data/$STUDY/RAW_data/"$PARTIC"/ -iname "$ANATSTRING"* -print | wc -l`
	else
		ANATSTRING="T1_MPRAGE_1MM"
	fi

	#Anatomical
	#Find the anatomical directory
	ANAT=`find /data/$STUDY/RAW_data/"$PARTIC"/ -iname "$ANATSTRING"* -print | sort -r -V | tail -1 | sed 's/.*\///'`

	echo -en '\n'
	echo "Test event: Anatomical .nii file deletion imminent!"
	echo -en '\n'
	echo -e "\e[0;31m.nii files are fine to delete, but .dcm files are not!\e[0m"
	echo -en '\n'

	#Delete any pre-existing nifti files in directory
	cd /data/$STUDY/RAW_data/"$PARTIC"/"$ANAT"
	find ./ -iname '*.nii' -exec rm -i {} \;
	cd /data/$STUDY/RAW_data/"$PARTIC"/

	#Convert dcm to nifti for a given participant and Anatomical task
	find /data/$STUDY/RAW_data/"$PARTIC"/"$ANAT"/ -iname '*.dcm' -print | dcm2nii $(xargs);

	#Select the converted nifti file and move it to the participant's individual analysis folder for the task (in rest)
	find /data/$STUDY/RAW_data/"$PARTIC"/"$ANAT"/ -not -iname "co*" -not -iname "o*" -iname '*.nii' -print | xargs cp -pt /data/$STUDY/indiv_analysis/"$PARTIC"/3danat_rest/"$VISIT"/

	#Navigate to the nifiti file in the participant's BOLD directory for the task.
	cd /data/$STUDY/indiv_analysis/"$PARTIC"/3danat_rest/"$VISIT"/
	
	#Copy to other anatomical task folders
	while read TASKVALUE
	do
		if [[ $TASKVALUE == "rest" ]]; then
			sleep 1
		else
			echo "Copying rest value to" "$TASKVALUE"
			find ./ -iname '*.nii' -print | xargs cp -pt ../../3danat_"$TASKVALUE"/"$VISIT"/
		fi
	done < /data/$STUDY/indiv_analysis/$PARTIC/tasks.txt

	#Return to $STUDY directory
	cd /data/$STUDY

	#Repeat Anatomical
	if [ $NumbAnat -eq "2" ]; then			

		#Find Repeat Anatomical
		ANAT2=`find /data/$STUDY/RAW_data/"$PARTIC"/ -iname "$ANATSTRING"* -print | sort -r | tail -1 | sed 's/.*\///'`

		#Delete any pre-existing nifti files in directory
		cd /data/$STUDY/RAW_data/"$PARTIC"/"$ANAT2"
		find ./ -iname '*.nii' -exec rm -i {} \;

		#Convert dcm to nifti for a given participant and Anatomical task
		find /data/$STUDY/RAW_data/"$PARTIC"/"$ANAT2"/ -iname '*.dcm' -print | dcm2nii $(xargs);

		#Select the converted nifti file and rename it
		find /data/$STUDY/RAW_data/"$PARTIC"/"$ANAT2"/ -not -iname "co*" -not -iname "o*" -iname '*.nii' -print | mv $(xargs) cd /data/$STUDY/indiv_analysis/"$PARTIC"/3danat_rest/"$VISIT"/""$PARTIC"_Anatomical_Repeat.nii"

		#Task loop for all tasks
		while read TASKVALUE
		do
			echo "Copying repeat anatomical to" "$TASKVALUE"
			find ./ -name ""$PARTIC"_Anatomical_Repeat.nii" -print | xargs cp -pt /data/$STUDY/indiv_analysis/"$PARTIC"/3danat_"$TASKVALUE"/"$VISIT"/
		done < /data/$STUDY/indiv_analysis/$PARTIC/tasks.txt
	else
		echo -en '\n'
		echo "_____________"
		echo -en '\n'
		echo "No Repeat Anatomical" 
		echo "No Repeat Anatomical" >> /data/$STUDY/indiv_analysis/$PARTIC/runlog.txt
		echo -en '\n'
		echo "_____________"
		echo -en '\n'
	fi

	#Return to $STUDY directory
	cd /data/$STUDY

	sleep 5
	
	##BOLD Tasks
	echo -en '\n'
	echo "Begin BOLD Tasks"
	echo -en '\n'
	sleep 2

	#TASK BOLD Baseline
	unset TASKVALUE

	filename="/data/"$STUDY"/indiv_analysis/"$PARTIC"/tasks.txt"
	filelines=`cat $filename`

	#Task loop for all tasks
	for TASKVALUE in $filelines; do

		echo "Starting" "$TASKVALUE" "BOLD"
		TASK=`find /data/"$STUDY"/RAW_data/"$PARTIC"/ -iname "$TASKVALUE"* -print | sed 's/.*\///'`

		#Determine whether $TASK exists
		if [ -n "$TASK" ]; then
	
			#Delete any pre-existing nifti files in RAW data directory
			cd /data/$STUDY/RAW_data/"$PARTIC"/"$TASK"/
			find ./ -iname '*.nii' -exec rm -i {} \;
			cd ../../..

			#Convert dcm to nifti for a given participant and BOLD task
			find /data/$STUDY/RAW_data/"$PARTIC"/"$TASK"/ -iname '*.dcm' -print | ../dcm2nii $(xargs)

			#Navigate to raw data directory for the participant's task
			cd /data/$STUDY/RAW_data/"$PARTIC"/"$TASK"/

			#Select the converted nifti file and move it to the participant's individual analysis folder for the task
			find ./ -iname '*.nii' | xargs cp -t /data/$STUDY/indiv_analysis/"$PARTIC"/bold/"$TASKVALUE"/"$VISIT"

			#Navigate to the nifiti file in the participant's BOLD directory for the task.
			cd /data/$STUDY/indiv_analysis/"$PARTIC"/bold/"$TASKVALUE"/"$VISIT"

			#Rename converted nifti file
			find ./ -iname '*.nii' -print | mv $(xargs) "$TASKVALUE"_Bas_RAW_"$PARTIC".nii

			#Return to $STUDY
			cd /data/$STUDY
		
			#Echo statment
			echo -en '\n'
			echo "_____________"
			echo -en '\n'
			echo "Finished BOLD "$TASKVALUE" "$VISIT""
			echo -en '\n'
			echo "_____________"
			echo -en '\n'

		#If $TASK DNE, write to log and print
		else
			echo -en '\n'
			echo "_____________"
			echo -en '\n'
			echo "NO "$TASKVALUE" "$VISIT" TASK RUN?!"
			echo "NO "$TASKVALUE" "$VISIT" TASK RUN?!" >> /data/$STUDY/indiv_analysis/$PARTIC/runlog.txt
			echo -en '\n'
			echo "_____________"
			echo -en '\n'
	
		fi
	sleep 2
	done 

	unset TASK

	#Fieldmapping Magnitude
	TASK=`find /data/$STUDY/RAW_data/"$PARTIC"/ -name 'field_mapping_*' -print | sort -r -V | tail -1 | sed 's/.*\///'`
	
	#Delete any pre-existing nifti files in RAW data directory
	cd /data/$STUDY/RAW_data/"$PARTIC"/"$TASK"/
	find ./ -iname '*.nii' -exec rm -i {} \;
	cd ../../..

	#Convert dcm to nifti for a given participant and BOLD task
	find /data/$STUDY/RAW_data/"$PARTIC"/"$TASK"/ -iname '*.dcm' -print | ../dcm2nii $(xargs)

	#Navigate to raw data directory for the participant's task
	cd /data/$STUDY/RAW_data/"$PARTIC"/"$TASK"/

	#Rename converted nifti file
	find ./ -iname '*.nii' -print | mv $(xargs) Magnitude_"$PARTIC".nii
	
	#copy converted nifti file to indiv_analysis
	find ./ -name "Magnitude_"$PARTIC".nii" | xargs cp -t /data/$STUDY/indiv_analysis/"$PARTIC"/fieldmaps/rest/Mag/"$VISIT"

	#Task loop for all tasks
	while read TASKVALUE
	do
		echo "Fieldmap" "$TASKVALUE" "Mag Finished"
		find ./ -name "Magnitude_"$PARTIC".nii" | xargs cp -t /data/$STUDY/indiv_analysis/"$PARTIC"/fieldmaps/"$TASKVALUE"/Mag/"$VISIT"
	sleep 2
	done < /data/$STUDY/indiv_analysis/$PARTIC/tasks.txt

	#Return to $STUDY
	cd /data/$STUDY

	#Debug Mag
	echo -en '\n'
	echo "_____________"
	echo -en '\n'
	echo "Fieldmapping Mag Finished"
	echo -en '\n'
	echo "_____________"
	echo -en '\n'

	#Fieldmapping Phase
	TASK=`find /data/$STUDY/RAW_data/"$PARTIC"/ -name 'field_mapping_*' -print | sort -V | tail -1 | sed 's/.*\///'`
	
	#Delete any pre-existing nifti files in RAW data directory
	cd /data/$STUDY/RAW_data/"$PARTIC"/"$TASK"/
	find ./ -iname '*.nii' -exec rm -i {} \;
	cd ../../..

	#Convert dcm to nifti for a given participant and BOLD task
	find /data/$STUDY/RAW_data/"$PARTIC"/"$TASK"/ -iname '*.dcm' -print | ../dcm2nii $(xargs)

	#Navigate to raw data directory for the participant's task
	cd /data/$STUDY/RAW_data/"$PARTIC"/"$TASK"/

	#Rename converted nifti file
	find ./ -iname '*.nii' -print | mv $(xargs) Phase_"$PARTIC".nii
	
	#copy converted nifti file to indiv_analysis
	find ./ -name "Phase_"$PARTIC".nii" | xargs cp -t /data/$STUDY/indiv_analysis/"$PARTIC"/fieldmaps/rest/Phase/"$VISIT"

	#Task loop for all tasks
	while read TASKVALUE
	do
		echo "Fieldmap" "$TASKVALUE" "Phase Finished"
		find ./ -name "Phase_"$PARTIC".nii" | xargs cp -t /data/$STUDY/indiv_analysis/"$PARTIC"/fieldmaps/"$TASKVALUE"/Phase/"$VISIT"
	sleep 2
	done < /data/$STUDY/indiv_analysis/$PARTIC/tasks.txt

	cd /data/$STUDY

	#Debug Phase
	echo -en '\n'
	echo "_____________"
	echo -en '\n'
	echo "Fieldmapping Phase Finished"
	echo -en '\n'
	echo "_____________"
	echo -en '\n'
	sleep 2

fi

if [[ $ISBOTH == "TRUE" ]]; then
	VISIT="PostTX"
fi

##Post
#Post Check Phase
echo -en '\n'
echo "PostTX Check Phase"
echo -en '\n'
echo "You enterered" $VISIT
echo -en '\n'

if [[ $VISIT == "PostTX" ]] || [[ $VISIT == "Both" ]]; then
	echo -e "\e[0;32mPostTX Check Passed!\e[0m"
	echo -en '\n'

	cd /data/$STUDY
	#Remove all spaces and hyphens with underscores in raw directory names
	cd ./RAW_data/"$PARTIC"_2
	for f in *\ *; do mv "$f" "${f// /_}"; done

	cd /data/$STUDY

	#Will there be a repeat Anatomical?
	NumbAnat=`find /data/$STUDY/RAW_data/""$PARTIC"_2" -iname 'T1_MPRAGE_1MM*' -print | wc -l`

	#If anatomical directory not found, prompt user for new string and search it.
	if [[ $NumbAnat -eq "0" ]]; then

		#Find T1 Anat String
		echo -en '\n'
		echo "Anatomical directory not found."
		echo "Type in part of the name of the Anatomical directory you would like to search for."
		read ANATSTRING
		NumbAnat=`find /data/$STUDY/RAW_data/""$PARTIC"_2" -iname "$ANATSTRING"* -print | wc -l`
	else
		ANATSTRING="T1_MPRAGE_1MM"
	fi

	#Anatomical
	#find the anatomical directory
	ANAT=`find /data/$STUDY/RAW_data/""$PARTIC"_2"/ -iname "$ANATSTRING"* -print | sort -r -V | tail -1 | sed 's/.*\///'`

	echo -en '\n'
	echo "Test event: Anatomical .nii file deletion imminent!"
	echo -en '\n'
	echo -e "\e[0;31m.nii files are fine to delete, but .dcm files are not!\e[0m"
	echo -en '\n'

	#Delete any pre-existing nifti files in directory
	cd /data/$STUDY/RAW_data/""$PARTIC"_2"/"$ANAT"
	find ./ -iname '*.nii' -exec rm -i {} \;
	cd /data/$STUDY/RAW_data/""$PARTIC"_2"/

	#Convert dcm to nifti for a given participant and Anatomical task
	find /data/$STUDY/RAW_data/""$PARTIC"_2"/"$ANAT"/ -iname '*.dcm' -print | dcm2nii $(xargs);

	#Select the converted nifti file and move it to the participant's individual analysis folder for the task (in rest)
	cd /data/$STUDY/indiv_analysis/"$PARTIC"/3danat_rest/"$VISIT"/
	find /data/$STUDY/RAW_data/""$PARTIC"_2"/"$ANAT"/ -not -iname "co*" -not -iname "o*" -iname '*.nii' -print | mv $(xargs) ""$PARTIC"_2_Anatomical.nii"

	#Navigate to the nifiti file in the participant's BOLD directory for the task.
	cd /data/$STUDY/indiv_analysis/"$PARTIC"/3danat_rest/"$VISIT"/
	
	#Copy to other anatomical task folders
	while read TASKVALUE
	do
		if [[ $TASKVALUE == "rest" ]]; then
			sleep 1
		else
			echo "Copying rest value to" "$TASKVALUE"
			find ./ -iname '*.nii' -print | xargs cp -pt ../../3danat_"$TASKVALUE"/"$VISIT"/
		fi
	done < /data/$STUDY/indiv_analysis/$PARTIC/tasks.txt

	#Return to $STUDY directory
	cd /data/$STUDY

	#Repeat Anatomical
	if [ $NumbAnat -eq "2" ]; then

		#Find Repeat Anatomical
		ANAT2=`find /data/$STUDY/RAW_data/""$PARTIC"_2"/ -iname "$ANATSTRING"* -print | sort -r | tail -1 | sed 's/.*\///'`

		#Delete any pre-existing nifti files in directory
		cd /data/$STUDY/RAW_data/""$PARTIC"_2"/"$ANAT2"
		find ./ -iname '*.nii' -exec rm -i {} \;

		#Convert dcm to nifti for a given participant and Anatomical task
		find /data/$STUDY/RAW_data/""$PARTIC"_2"/"$ANAT2"/ -iname '*.dcm' -print | dcm2nii $(xargs);

		#Select the converted nifti file and rename it
		find /data/$STUDY/RAW_data/""$PARTIC"_2"/"$ANAT2"/ -not -iname "co*" -not -iname "o*" -iname '*.nii' -print | mv $(xargs) /data/$STUDY/RAW_data/""$PARTIC"_2"/"$ANAT2"/""$PARTIC"_2_Anatomical_Repeat.nii"

		#Task loop for all tasks
		while read TASKVALUE
		do
			echo "Copying repeat anatomical to" "$TASKVALUE"
			find ./ -name ""$PARTIC"_2_Anatomical_Repeat.nii" -print | xargs cp -pt /data/$STUDY/indiv_analysis/"$PARTIC"/3danat_"$TASKVALUE"/"$VISIT"/
		done < /data/$STUDY/indiv_analysis/$PARTIC/tasks.txt
	else
		echo -en '\n'
		echo "_____________"
		echo -en '\n'
		echo "No Repeat Anatomical"
		echo "No Repeat Anatomical" >> /data/$STUDY/indiv_analysis/$PARTIC/runlog.txt
		echo -en '\n'
		echo "_____________"
		echo -en '\n'
	fi

	#Return to $STUDY directory
	cd /data/$STUDY

	sleep 5

	#BOLD Tasks
	echo -en '\n'
	echo "Begin BOLD Tasks"
	echo -en '\n'
	sleep 2

	#Task loop for all tasks
	filename="/data/"$STUDY"/indiv_analysis/"$PARTIC"/tasks.txt"
	filelines=`cat $filename`

	#Task loop for all tasks
	for TASKVALUE in $filelines; do

		echo "Starting" "$TASKVALUE" "BOLD"
		TASK=`find ./RAW_data/""$PARTIC"_2"/ -iname "$TASKVALUE"* -print | sort -r | tail -1 | sed 's/.*\///'`
		#Determine whether $TASK exists
		if [ -n "$TASK" ]; then
	
			#Delete any pre-existing nifti files in RAW data directory
			cd /data/$STUDY/RAW_data/""$PARTIC"_2"/"$TASK"/
			find ./ -iname '*.nii' -exec rm -i {} \;
			cd ../../..

			#Convert dcm to nifti for a given participant and BOLD task
			find /data/$STUDY/RAW_data/""$PARTIC"_2"/"$TASK"/ -iname '*.dcm' -print | ../dcm2nii $(xargs)

			#Navigate to raw data directory for the participant's task
			cd /data/$STUDY/RAW_data/""$PARTIC"_2"/"$TASK"/

			#Select the converted nifti file and move it to the participant's individual analysis folder for the task
			find ./ -iname '*.nii' | xargs cp -t /data/$STUDY/indiv_analysis/"$PARTIC"/bold/"$TASKVALUE"/"$VISIT"/

			#Navigate to the nifiti file in the participant's BOLD directory for the task.
			cd /data/$STUDY/indiv_analysis/"$PARTIC"/bold/"$TASKVALUE"/"$VISIT"

			#Rename converted nifti file
			find ./ -iname '*.nii' -print | mv $(xargs) "$TASKVALUE"_Bas_RAW_""$PARTIC"_2".nii

			#Return to $STUDY
			cd /data/$STUDY
		
			#Echo statment
			echo -en '\n'
			echo "_____________"
			echo -en '\n'
			echo "Finished BOLD" "$TASKVALUE" "$VISIT"
			echo -en '\n'
			echo "_____________"
			echo -en '\n'

		#If $TASK DNE, write to log and print
		else
			echo -en '\n'
			echo "_____________"
			echo -en '\n'
			echo "NO "$VALUE" "$VISIT" TASK RUN?!"
			echo "NO" "$TASKVALUE" "$VISIT" "TASK RUN?!" >> /data/$STUDY/indiv_analysis/$PARTIC/runlog.txt
			echo -en '\n'
			echo "_____________"
			echo -en '\n'
	
		fi
	sleep 2
	done

	unset TASK

	#Fieldmapping Magnitude
	TASK=`find /data/$STUDY/RAW_data/""$PARTIC"_2"/ -name 'field_mapping_*' -print | sort -r -V | tail -1 | sed 's/.*\///'`
	
	#Delete any pre-existing nifti files in RAW data directory
	cd /data/$STUDY/RAW_data/""$PARTIC"_2"/"$TASK"/
	find ./ -iname '*.nii' -exec rm -i {} \;
	cd ../../..

	#Convert dcm to nifti for a given participant and BOLD task
	find /data/$STUDY/RAW_data/""$PARTIC"_2"/"$TASK"/ -iname '*.dcm' -print | ../dcm2nii $(xargs)

	#Navigate to raw data directory for the participant's task
	cd /data/$STUDY/RAW_data/""$PARTIC"_2"/"$TASK"/

	#Rename converted nifti file
	find ./ -iname '*.nii' -print | mv $(xargs) Magnitude_""$PARTIC"_2".nii
	
	#copy converted nifti file to indiv_analysis
	find ./ -name "Magnitude_""$PARTIC"_2".nii" | xargs cp -t /data/$STUDY/indiv_analysis/"$PARTIC"/fieldmaps/rest/Mag/"$VISIT"

	#For all tasks
	while read TASKVALUE
	do
		echo "Fieldmap" "$TASKVALUE" "Mag Finished"
		find ./ -name "Magnitude_""$PARTIC"_2".nii" | xargs cp -t /data/$STUDY/indiv_analysis/"$PARTIC"/fieldmaps/"$TASKVALUE"/Mag/"$VISIT"
	sleep 2
	done < /data/$STUDY/indiv_analysis/$PARTIC/tasks.txt

	#Return to $STUDY
	cd /data/$STUDY

	#Debug Mag
	echo -en '\n'
	echo "_____________"
	echo -en '\n'
	echo "Fieldmapping Mag Finished"
	echo -en '\n'
	echo "_____________"
	echo -en '\n'

	#Fieldmapping Phase
	TASK=`find /data/$STUDY/RAW_data/""$PARTIC"_2"/ -name 'field_mapping_*' -print | sort -V | tail -1 | sed 's/.*\///'`
	
	#Delete any pre-existing nifti files in RAW data directory
	cd /data/$STUDY/RAW_data/""$PARTIC"_2"/"$TASK"/
	find ./ -iname '*.nii' -exec rm -i {} \;
	cd ../../..

	#Convert dcm to nifti for a given participant and BOLD task
	find /data/$STUDY/RAW_data/""$PARTIC"_2"/"$TASK"/ -iname '*.dcm' -print | ../dcm2nii $(xargs)

	#Navigate to raw data directory for the participant's task
	cd /data/$STUDY/RAW_data/""$PARTIC"_2"/"$TASK"/

	#Rename converted nifti file
	find ./ -iname '*.nii' -print | mv $(xargs) Phase_""$PARTIC"_2".nii
	
	#copy converted nifti file to indiv_analysis
	find ./ -name "Phase_""$PARTIC"_2".nii" | xargs cp -t /data/$STUDY/indiv_analysis/"$PARTIC"/fieldmaps/rest/Phase/"$VISIT"

	#For all tasks
	while read TASKVALUE
	do
		echo "Fieldmap" "$TASKVALUE" "Phase Finished"
		find ./ -name "Phase_""$PARTIC"_2".nii" | xargs cp -t /data/$STUDY/indiv_analysis/"$PARTIC"/fieldmaps/"$TASKVALUE"/Phase/"$VISIT"
	sleep 2
	done < /data/$STUDY/indiv_analysis/$PARTIC/tasks.txt

	cd /data/$STUDY

	#Debug Phase
	echo -en '\n'
	echo "_____________"
	echo -en '\n'
	echo "Fieldmapping Phase Finished"
	echo -en '\n'
	echo "_____________"
	echo -en '\n'

fi

#Summary
echo -en '\n'
if [ /data/$STUDY/indiv_analysis/$PARTIC/runlog.txt="" ]; then
	echo "Nothing broke (or nothing is missing) after attempting to process!"
	echo "Please check just in case."
else
	echo "Here is a list of malfunctioning processes."
	echo "Please make sure their preliminary paths exist."
	cat /data/$STUDY/indiv_analysis/$PARTIC/runlog.txt
fi
echo -en '\n'
