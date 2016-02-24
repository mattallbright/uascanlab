#!/bin/sh

cd /data/TBIMODEL/dti_72_preproc/TM103_test

#Run Eddy
echo -en '\n'
echo -e 'Running Eddy Current Correction'
eddy --imain=original_data.nii.gz --mask=hifi_b0_brain_mask.nii.gz --acqp=parameters.txt --index=index1.txt --bvecs=bvec --bvals=bval --topup=topup_results --out=eddy_corrected_data.nii.gz

#Rotate bvec file to match eddy correction
#Because with 'eddy' we cannot separate rotations due to motion and/or eddy currents it is recommended that this not be performed unless motion is obvious

#Convert Eddy Corrected Dataset from *.nii.gz to *.nii for MATLAB LPCA algorithm
dcm2nii -g n -m n eddy_corrected_data.nii.gz
matlab -nodesktop -nosplash -r "addpath(genpath('/usr/local/LPCA Denoising Software')); cd $output_dir/"$PARTIC"; LPCAscript('feddy_corrected_data.nii'); clear; quit;"
dcm2nii -g y -m n feddy_corrected_data_denoised.nii
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

#DWI Conversion to .nrrd for Slicer
        /usr/local/DTIPrepPackage/DWIConvert --inputVolume eddy_corrected_data_denoised.nii.gz --conversionMode FSLToNrrd --inputBValues bval --inputBVectors bvec --outputVolume "$PARTIC".nrrd

#QBall Fitting
        echo -en '\n'
        echo -e 'Running QBOOT'
        if [ ! -d ./"QBALL_$PARTIC" ]; then
                mkdir ./"QBALL_$PARTIC"
        fi
        cd ./"QBALL_$PARTIC"
        qboot -k ../eddy_corrected_data_denoised.nii.gz -m ../bet_mask.nii.gz -r ../"bvec" -b ../"bval" --ld=./QBALL --model=2 --lmax=4 --npeaks=3 --gfa

#BEDPOSTX 
        echo -en '\n'   
        echo -e 'Running BedPostX'
        cd ../
        if [ ! -d ./"bedpostx_$PARTIC" ]; then
                mkdir ./"bedpostx_$PARTIC"
        fi
        cp eddy_corrected_data_denoised.nii.gz ./bedpostx_$PARTIC/data.nii.gz
        cp bet_mask.nii.gz ./bedpostx_$PARTIC/nodif_brain_mask.nii.gz
        cp "bvec" ./bedpostx_$PARTIC/bvecs
        cp "bval" ./bedpostx_$PARTIC/bvals
        bedpostx ./bedpostx_$PARTIC -n 3




