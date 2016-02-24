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
acqparams=$3
index=$4
output_dir=$5
b0_indices=$6
OddSlices=$7

cd $output_dir

#Remove preexisting NIFTIs and bval/bvec files
rm -i ${dwi_dir}/*.nii* ${dwi_dir}/*.bvec ${dwi_dir}/*.bval
rm -i ${P2A}/*.nii*

#Convert to NIFTI
#dcm2nii -g n -o '/home/fsl/Desktop/' $dwi_dir;
cd $dwi_dir
find ./ -iname '*.dcm' -print | dcm2nii -g y $(xargs)
cd $P2A
find ./ -iname '*.dcm' -print | dcm2nii -g y $(xargs)

#Navigate to raw data directory for the participant
	cd ${dwi_dir}

	#Rename converted nifti file to "blip_up"
	find ./ -iname '*.nii.gz' -print | mv $(xargs) "original_data.nii.gz"

	#Rename bvecs file to "PARTIC_bvec"
	find ./ -iname '*.bvec' -print | mv $(xargs) "bvec"

	#Rename bval file to "PARTIC_bval"
	find ./ -iname '*.bval' -print | mv $(xargs) "bval"

#Select the converted nifti file and move it to the participant's individual analysis folder for the task
	cp ./"original_data.nii.gz" ${output_dir}
	cp ./bvec ${output_dir}
	cp ./bval ${output_dir}

echo -en '\n'
echo -en '\n'
echo -e "Finished Converting to Compressed NIFTI"
echo -en '\n'
echo -en '\n'

#Extract and Combine all B0s collected for TOPUP
counter=$(expr 0)
for i in `cat $b0_indices`; do
	if [ $counter -eq 0 ]; then
		fslroi original_data.nii.gz A2P_P2A.nii.gz $i 1
	else
		fslroi original_data.nii.gz A2P_b01.nii.gz $i 1
		fslmerge -t A2P_P2A.nii.gz A2P_P2A.nii.gz A2P_b01.nii.gz
	fi
	counter=$(expr $counter + 1)
done

fslmerge -t A2P_P2A.nii.gz A2P_P2A.nii.gz ${P2A}/P2A.nii.gz
rm -i A2P_b01.nii.gz ${P2A}/P2A.nii.gz

if [ $OddSlices = 1 ]; then
	fslroi original_data.nii.gz original_data.nii.gz 0 128 0 128 0 74 0 78
	fslroi A2P_P2A.nii.gz A2P_P2A.nii.gz 0 128 0 128 0 74 0 8
fi
if [ $OddSlices = 2 ]; then
	fslroi original_data.nii.gz original_data.nii.gz 0 128 0 128 1 74 0 78
	fslroi A2P_P2A.nii.gz A2P_P2A.nii.gz 0 128 0 128 0 74 0 8
fi

#Run TOPUP Using Combined B0 File and specified acqparams file
echo -en '\n'
echo -e 'Running TOPUP'
echo -en '\n'
topup --imain=A2P_P2A.nii.gz --datain=$acqparams --config=b02b0.cnf --out=topup_results --iout=hifi_b0

#Combine all Corrected B0s from TOPUP to one average B0
fslmaths hifi_b0 -Tmean hifi_b0

#Brain Extraction using BET on hifi_b0 image
bet hifi_b0 hifi_b0_brain -f 0.3 -g 0 -m

#Run Eddy
echo -en '\n'
echo -e 'Running Eddy Current Correction\n'
echo -en '\n'

eddy --imain=original_data.nii.gz --mask=hifi_b0_brain_mask.nii.gz --acqp=$acqparams --index=$index --bvecs=bvec --bvals=bval --topup=topup_results --out=eddy_corrected_data.nii.gz

#Rotate bvec file to match eddy correction
#Because with 'eddy' we cannot separate rotations due to motion and/or eddy currents it is recommended that this not be performed unless motion is obvious

#Convert Eddy Corrected Dataset from *.nii.gz to *.nii for MATLAB LPCA algorithm
dcm2nii -g n -m n eddy_corrected_data.nii.gz
matlab -nodesktop -nosplash -r "LPCAscript('feddy_corrected_data.nii'); quit;"
dcm2nii -g y -m n feddy_corrected_data_denoised.nii
mv ffeddy_corrected_data_denoised.nii.gz eddy_corrected_denoised_data.nii.gz
rm -i feddy_corrected_data.nii feddy_corrected_data_denoised.nii

echo -e 'Done Preprocessing Data\n'


