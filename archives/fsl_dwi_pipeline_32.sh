#!/bin/sh
#dwi_dir:   First input, path of directory containing raw dwi set
#P2A:       Second input, path of directory containing reversed phase encode images
#acqparams: Path to acqparams.txt, Acquisition parameters for running TOPUP and EDDY
#index:     Path to index.txt, File containing index relating image volumes to acqparams.txt
#output_dir:Path to directory results will go in
#b0_indices:Text file containing indices of b0 images in raw dwi set (e.g. 0 10 20 30)
#OddSlices: 0=dataset has even number of slices, 1=remove top slice of dataset, 2=remove bottom slice of dataset

dwi_dir=$1
P2A=$2
output_dir=$3
OddSlices=$4
PARTIC=$5
sequence=$6

#Convert to NIFTI
dcm2nii -g y $dwi_dir
dcm2nii -g y $P2A

#Navigate to A2P raw data directory for the participant
cd $dwi_dir

#Rename converted nifti file
mv ./*.nii.gz "original_data.nii.gz"
mv ./*.bvec "bvec"
mv ./*.bval "bval"

#Select the converted nifti file and move it to the participant's individual analysis folder for the task
cp "original_data.nii.gz" $output_dir/"$PARTIC"
cp bvec $output_dir/"$PARTIC"
cp bval $output_dir/"$PARTIC"

#Navigate to P2A raw data directory for the participant
cd $P2A
mv ./*.nii.gz "P2A.nii.gz"
cp "P2A.nii.gz" $output_dir/"$PARTIC"

echo -en '\n'
echo -e "Finished Converting to Compressed NIFTI"
echo -en '\n'

cd $output_dir/$PARTIC

#Create b0_indices file
echo "0 31 32 33 34 35" > b0_indices

##Create parameters file to feed to TOPUP and EDDY
printf "0 -1 0 0.08576\n0 -1 0 0.08576\n0 -1 0 0.08576\n0 -1 0 0.08576\n0 -1 0 0.08576\n0 -1 0 0.08576\n0 1 0 0.08576\n0 1 0 0.08576" > parameters.txt 

#Create index file
indx=""
for ((i=1; i<=36; i+=1)); do indx="$indx 1"; done
echo $indx > index1.txt

#Extract and Combine all B0s collected for TOPUP
fslroi original_data.nii.gz b0_A2P_1 0 1
fslroi original_data.nii.gz b0_A2P_2 31 5
fslmerge -t both_b0 b0_A2P_1.nii.gz b0_A2P_2.nii.gz P2A.nii.gz

#Run TOPUP Using Combined B0 File and specified acqparams file
echo -en '\n'
echo -e 'Running TOPUP'
topup --imain=both_b0 --datain=parameters.txt --config=$FSLDIR/etc/flirtsch/b02b0.cnf --out=topup_results --iout=hifi_b0 --verbose

#Combine all Corrected B0s from TOPUP to one average B0
fslmaths hifi_b0 -Tmean hifi_b0

#Brain Extraction using BET on hifi_b0 image
bet hifi_b0 hifi_b0_brain -f 0.3 -m

chmod 775 -R $output_dir/$PARTIC/

#Run Eddy
echo -en '\n'
echo -e 'Running Eddy Current Correction'
fsl_sub -q long.q eddy --imain=original_data.nii.gz --mask=hifi_b0_brain_mask.nii.gz --acqp=parameters.txt --index=index1.txt --bvecs=bvec --bvals=bval --topup=topup_results --out=eddy_corrected_data.nii.gz

##Wait until eddy_corrected_data.nii.gz exists before continuing script
until [ -f ./eddy_corrected_data.nii.gz ]
do
     sleep 5
done

sleep 500

chmod 775 -R $output_dir/$PARTIC/

#Rotate bvec file to match eddy correction
#Because with 'eddy' we cannot separate rotations due to motion and/or eddy currents it is recommended that this not be performed unless motion is obvious

#Convert Eddy Corrected Dataset from *.nii.gz to *.nii for MATLAB LPCA algorithm
dcm2nii -g n -m n eddy_corrected_data.nii.gz
chmod 775 -R $output_dir/$PARTIC/
matlab -nodesktop -nosplash -r "addpath(genpath('/usr/local/LPCA Denoising Software')); addpath(genpath('/usr/local/nifti_analyzer')); Run_LPCA('feddy_corrected_data.nii', 'bval'); clear; quit;"
dcm2nii -g y -m n feddy_corrected_data_denoised.nii
chmod 775 -R $output_dir/$PARTIC/
mv ffeddy_corrected_data_denoised.nii.gz eddy_corrected_data_denoised.nii.gz

bet eddy_corrected_data_denoised.nii.gz bet.nii.gz -m -f 0.3

echo -en '\n'
echo 'Done Preprocessing Data\n'

###############################################################################################

##Prep for Tractography and TBSS
#Navigate to Participant's directory
        cd $output_dir/$PARTIC

##DTIFIT
        echo -en '\n'
        echo -e 'Running DTIFIT'
        dtifit -k eddy_corrected_data_denoised.nii.gz -o "$PARTIC" -m bet_mask.nii.gz -r bvec -b bval




