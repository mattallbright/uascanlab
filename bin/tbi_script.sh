#!/bin/sh

#########################System Requirements######################
##fsl_dwi_pipeline.sh should be in /usr/local/bin

##DTIPrep package with DWI convert should be installed as: /usr/local/DTIPrepPackage/DWIConvert

##dcm2nii should be installed

##FSL should be installed

##LPCA Denoising software should be installed in /usr/local/ and the LPCA Denoising Software directory should contain both the MainDWIDenoising.m script and the LPCA_script for running from the matlab command line. 

##Matlab should be installed with a symlink from the terminal and its paths should be set to the LPCA Denoising Software directory in /usr/local

##Participant raw data folders (containing each dwi sequence folder with the raw dicoms) should all be in the ##RAW_data directory specified below (e.g. raw dicoms contained within /data/TBIMODEL/RAW_data/TM100/DTI_72_DIRS_A-##P_0006)

########################USER SPECIFIED###########################
##Specify locations of directories
Study=/data/TBIMODEL
RAW_data=$Study/RAW_data
OddSlices=1 #Removes top slice when slice number is odd
#OddSlices=2 #Removes bottom slice when slice number is odd

##User default configurable portions of script to run (1 is on, 0 is off)##
#ALL PREPROCESSING THROUGH BEDPOSTX
preproc=0

#Old eddy correction (0) or new Eddy with TOPUP (1)?
eddy_type=1

#FREESURFER RECONSTRUCTION AND TRACULA
tracula=1

#BUILD ROI VOLUMES FROM FREESURFER LABELS
buildvol=0

## for each seed mask, use probtrackx to create a fiber distribution
probtracking=0

#################################################################
##If the above Requirements have been satisfied, the script should function without further modification from here##

#Confirm all necessary output directories exist. If not, create them.
cd $Study
if [ ! -d ./dti_72_preproc ]; then
	mkdir ./dti_72_preproc
fi

if [ ! -d ./MB2 ]; then
	mkdir ./MB2
fi

if [ ! -d ./MB3 ]; then
	mkdir ./MB3
fi

#Choose Participant
echo -en '\n'
ls $RAW_data
echo -en '\n'
echo "Which participant?"; read PARTIC

cd $RAW_data/$PARTIC

#Remove all spaces and hyphens with underscores in raw directory names
for f in *\ *; do mv "$f" "${f// /_}"; done
for f in *\-*; do mv "$f" "${f//-/_}"; done

#Choose sequence type
echo -en '\n'
echo "Which sequence? (1=standard, 2=MB2, 3=MB3)"; read sequence

if [ $sequence -eq "3" ]; then
	output_dir=$Study/MB3
	dwi_dir_name=`find ./ -iname "DTI_72_SliceAcc_3_fleet_*" -not -iname "*ADC*" -not -iname "*COLFA*" -not -iname "*FA*" -not -iname "*TENSOR*" -not -iname "*TRACEW*" -print | sed 's/.*\///'`
	dwi_dir=$RAW_data/$PARTIC/$dwi_dir_name
	P2A_name=`find $RAW_data/$PARTIC -iname "*DTI_72_SLICEACC_3_P*" -print | sed 's/.*\///'`
	P2A=$RAW_data/$PARTIC/$P2A_name
fi

if [ $sequence -eq "2" ]; then
	output_dir=$Study/MB2
	dwi_dir_name=`find ./ -iname "*DTI_72_SliceAcc_2_fleet*" -not -iname "*ADC*" -not -iname "*ColFA*" -not -iname "*FA*" -not -iname "*TENSOR*" -not -iname "*TRACEW*" -print | sed 's/.*\///'`
	dwi_dir=$RAW_data/$PARTIC/$dwi_dir_name
	P2A_name=`find ./ -iname "*DTI_72_SLICEACC_2_FLEET_P*" -print | sed 's/.*\///'`
	P2A=$RAW_data/$PARTIC/$P2A_name
fi

if [ $sequence -eq "1" ]; then
	output_dir=$Study/dti_72_preproc
	dwi_dir_name=`find ./ -iname "DTI_72_DIRs_A*" -not -iname "*ADC*" -not -iname "*ColFA*" -not -iname "*FA*" -not -iname "*TENSOR*" -not -iname "*TRACEW*" -print | sed 's/.*\///'`
	dwi_dir=$RAW_data/$PARTIC/$dwi_dir_name
	P2A_name=`find ./ -iname "*Bzero_verify_P*" -print | sed 's/.*\///'`
	P2A=$RAW_data/$PARTIC/$P2A_name
fi

#Browse for raw data folders if hard-coded find command fails
if [ -z "$dwi_dir_name" ]; then
	dwi_dir=`zenity --file-selection --directory --filename=$RAW_data/$PARTIC --title="Please Specify the Directory Containing the Raw DWI DICOMs to Process"`
fi

if [ -z "$P2A_name" ]; then
	P2A=`zenity --file-selection --directory --filename=$RAW_data/$PARTIC --title="Please Specify the Directory Containing the P->A B0 DICOMs"`
fi

#Select T1 MPRAGE Directory
T1directory=$Study/indiv_analysis/$PARTIC/3danat
if [ -z "$T1directory" ]; then
        T1directory=`zenity --file-selection --directory --filename=$Study --title="Select Directory where T1 MPRAGE .nii file exists"`
fi


cd $output_dir
if [ ! -d $output_dir/"$PARTIC" ]; then
	mkdir $output_dir/"$PARTIC"
fi

if [ -d $output_dir/"$PARTIC" ] && [ $preproc = "1" ]; then
	#Delete any pre-existing files in raw directory
	find $dwi_dir -iname '*.nii.gz' -exec rm -i {} \;
	find $dwi_dir -iname '*.bvec' -exec rm -i {} \;
	find $dwi_dir -iname '*.bval' -exec rm -i {} \;
	find $P2A -iname '*.nii.gz' -exec rm -i {} \;
	
	#Delete any pre-existing files in preprocessing directory
	rm -i $output_dir/"$PARTIC"/*
fi

#Run through all processing steps in pipeline using the above specified files
fsl_dwi_pipeline.sh $dwi_dir $P2A $output_dir $OddSlices $PARTIC $sequence $T1directory $Study $preproc $tracula $buildvol $probtracking $eddy_type
