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
T1directory=$7
Study=$8

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
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -e "Finished Converting to Compressed NIFTI"
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -en '\n'

sleep 3

cd $output_dir/$PARTIC

#Create b0_indices file
echo "0 73 74 75 76 77" > b0_indices

if [ $sequence -eq "1" ]; then
	##Create parameters file to feed to TOPUP and EDDY
	printf "0 -1 0 0.08576\n0 -1 0 0.08576\n0 -1 0 0.08576\n0 -1 0 0.08576\n0 -1 0 0.08576\n0 -1 0 0.08576\n0 1 0 0.08576\n0 1 0 0.08576" > parameters.txt 

	#Create index file
	indx=""
	for ((i=1; i<=78; i+=1)); do indx="$indx 1"; done
	echo $indx > index1.txt
fi

if [ $sequence -eq "2" ]; then
	##Create parameters file to feed to TOPUP and EDDY
	printf "0 -1 0 0.08576\n0 -1 0 0.08576\n0 -1 0 0.08576\n0 -1 0 0.08576\n0 -1 0 0.08576\n0 -1 0 0.08576\n0 1 0 0.08576\n0 1 0 0.08576" > parameters.txt 

	#Create index file
	indx=""
	for ((i=1; i<=78; i+=1)); do indx="$indx 1"; done
	echo $indx > index1.txt
fi

if [ $sequence -eq "3" ]; then
	##Create parameters file to feed to TOPUP and EDDY
	printf "0 -1 0 0.08832\n0 -1 0 0.08832\n0 -1 0 0.08832\n0 -1 0 0.08832\n0 -1 0 0.08832\n0 -1 0 0.08832\n0 1 0 0.08832\n0 1 0 0.08832" > parameters.txt 

	#Create index file
	indx=""
	for ((i=1; i<=78; i+=1)); do indx="$indx 1"; done
	echo $indx > index1.txt
fi


if [ $OddSlices -eq "1" ] && [ $sequence -eq "3" ]; then
	fslroi original_data.nii.gz original_data.nii.gz 0 128 0 128 0 74 0 78
	fslroi P2A.nii.gz P2A.nii.gz 0 128 0 128 0 74 0 2
fi
if [ $OddSlices -eq "2" ] && [ $sequence -eq "3" ]; then
	fslroi original_data.nii.gz original_data.nii.gz 0 128 0 128 1 74 0 78
	fslroi P2A.nii.gz P2A.nii.gz 0 128 0 128 1 74 0 2
fi

#Extract and Combine all B0s collected for TOPUP
fslroi original_data.nii.gz b0_A2P_1 0 1
fslroi original_data.nii.gz b0_A2P_2 73 5
fslmerge -t both_b0 b0_A2P_1.nii.gz b0_A2P_2.nii.gz P2A.nii.gz

#Run TOPUP Using Combined B0 File and specified acqparams file
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -e 'Running TOPUP'
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -en '\n'
topup --imain=both_b0 --datain=parameters.txt --config=$FSLDIR/etc/flirtsch/b02b0.cnf --out=topup_results --iout=hifi_b0 --verbose

#Combine all Corrected B0s from TOPUP to one average B0
fslmaths hifi_b0 -Tmean hifi_b0

#Brain Extraction using BET on hifi_b0 image
bet hifi_b0 hifi_b0_brain -f 0.3 -m

chmod 775 -R $output_dir/$PARTIC/

#Run Eddy
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -e 'Running Eddy Current Correction'
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -en '\n'
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
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo 'Done Preprocessing Data'
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -en '\n'

sleep 3
###############################################################################################

##Prep for Tractography and TBSS
#Navigate to Participant's directory
cd $output_dir/$PARTIC

##DTIFIT
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -e 'Running DTIFIT'
dtifit -k eddy_corrected_data_denoised.nii.gz -o "$PARTIC" -m bet_mask.nii.gz -r bvec -b bval

chmod 775 -R $output_dir/$PARTIC/

#DWI Conversion to .nrrd for Slicer
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -e 'Converting to .nrrd for 3DSlicer'
echo -en '\n'   
echo -en '\n'   
echo -en '\n'   
echo -en '\n'   
echo -en '\n'   
/usr/local/DTIPrepPackage/DWIConvert --inputVolume eddy_corrected_data_denoised.nii.gz --conversionMode FSLToNrrd --inputBValues bval --inputBVectors bvec --outputVolume "$PARTIC".nrrd

chmod 775 -R $output_dir/$PARTIC/

#BEDPOSTX 
echo -en '\n'
echo -en '\n'   
echo -en '\n'   
echo -en '\n'
echo -en '\n'         
echo -e 'Running BedPostX'
echo -en '\n'   
echo -en '\n'   
echo -en '\n'   
echo -en '\n'   
if [ ! -d ./"bedpostx_$PARTIC" ]; then
        mkdir ./"bedpostx_$PARTIC"
fi
cp eddy_corrected_data_denoised.nii.gz ./bedpostx_$PARTIC/data.nii.gz
cp bet_mask.nii.gz ./bedpostx_$PARTIC/nodif_brain_mask.nii.gz
cp "bvec" ./bedpostx_$PARTIC/bvecs
cp "bval" ./bedpostx_$PARTIC/bvals
chmod 775 -R $output_dir/$PARTIC/bedpostx_$PARTIC
bedpostx ./bedpostx_$PARTIC -n 3 -c
chmod 775 -R $output_dir/$PARTIC/bedpostx_$PARTIC
chmod 775 -R $output_dir/$PARTIC/bedpostx_"$PARTIC".bedpostX

cd $output_dir/$PARTIC/bedpostx_"$PARTIC".bedpostX

until [ -f ./dyads1.nii.gz ]
do
     sleep 200
done

if [ $sequence -eq "1" ]; then
	#######TRACULA#####Standard Sequence
	###Make all TRACULA folders
	if [ ! -d $Study/TRACULA ]; then
		mkdir $Study/TRACULA/
	fi
	if [ ! -d $Study/TRACULA/diffusion_recons ]; then
		mkdir $Study/TRACULA/diffusion_recons
	fi
	if [ ! -d $Study/TRACULA/tractography_output ]; then
		mkdir $Study/TRACULA/tractography_output
	fi
	mkdir $Study/TRACULA/tractography_output/$PARTIC
	mkdir $Study/TRACULA/tractography_output/$PARTIC/dmri
	mkdir $Study/TRACULA/tractography_output/$PARTIC/dmri.bedpostX
	mkdir $Study/TRACULA/tractography_output/$PARTIC/dlabel
	mkdir $Study/TRACULA/tractography_output/$PARTIC/dlabel/"diff"

	##copy bedpostx files
	cp -a $output_dir/$PARTIC/bedpostx_"$PARTIC".bedpostX/* $Study/TRACULA/tractography_output/$PARTIC/dmri.bedpostX

	##copy dmri base files
	##DWI image
	cp $output_dir/$PARTIC/eddy_corrected_data_denoised.nii.gz $Study/TRACULA/tractography_output/$PARTIC/dmri
	mv $Study/TRACULA/tractography_output/$PARTIC/dmri/eddy_corrected_data_denoised.nii.gz $Study/TRACULA/tractography_output/$PARTIC/dmri/dwi.nii.gz

	##bvec and bval
	cp $output_dir/$PARTIC/bvec $Study/TRACULA/tractography_output/$PARTIC/dmri
	mv $Study/TRACULA/tractography_output/$PARTIC/dmri/bvec $Study/TRACULA/tractography_output/$PARTIC/dmri/bvecs

	cp $output_dir/$PARTIC/bval $Study/TRACULA/tractography_output/$PARTIC/dmri
	mv $Study/TRACULA/tractography_output/$PARTIC/dmri/bval $Study/TRACULA/tractography_output/$PARTIC/dmri/bvals

	##bet mask
	cp $output_dir/$PARTIC/bet_mask.nii.gz $Study/TRACULA/tractography_output/$PARTIC/dmri
	mv $Study/TRACULA/tractography_output/$PARTIC/dmri/bet_mask.nii.gz $Study/TRACULA/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz
	cp $Study/TRACULA/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz $Study/TRACULA/tractography_output/$PARTIC/dlabel/"diff"
	mv $Study/TRACULA/tractography_output/$PARTIC/dlabel/"diff"/nodif_brain_mask.nii.gz $Study/TRACULA/tractography_output/$PARTIC/dlabel/"diff"/lowb_brain_mask.nii.gz
	cp $Study/TRACULA/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz $Study/TRACULA/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz
	mv $Study/TRACULA/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz $Study/TRACULA/tractography_output/$PARTIC/dmri/lowb.nii.gz

	##copy DTIFIT output to dmri
	if [ ! -f $output_dir/$PARTIC/dtifit_* ]; then
		cd $output_dir/$PARTIC/
		for i in `find . -type f -name "$PARTIC*" -not -iname "*.nrrd" -maxdepth 1`; do
			mv -v $i ${i/"$PARTIC"/dtifit};
		done
	fi

	##copy DTIFIT output to dmri
	cp -a $output_dir/$PARTIC/dtifit_* $Study/TRACULA/tractography_output/$PARTIC/dmri

        #Repeat Anatomical?
        NumbAnat=`find $T1directory -iname '*Anatomical*' | wc -l`

        #Repeat Anatomical
        if [ $NumbAnat -eq "2" ]; then
                cp $T1directory/*Anatomical_Repeat.nii $Study/TRACULA/diffusion_recons
                mv $Study/TRACULA/diffusion_recons/*Anatomical_Repeat.nii $Study/TRACULA/diffusion_recons/"$PARTIC"_Anatomical.nii
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'                   
		echo "USED REPEAT ANATOMICAL!"
		echo -en '\n'		
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n';
        elif [ $NumbAnat -eq "1" ]; then
                cp $T1directory/"$PARTIC"_Anatomical.nii $Study/TRACULA/diffusion_recons;
        fi
	
	#Convert Anatomical to .mgz
	if [ ! -d $Study/TRACULA/diffusion_recons/$PARTIC ]; then	
		mkdir $Study/TRACULA/diffusion_recons/$PARTIC
	fi
	if [ ! -d $Study/TRACULA/diffusion_recons/$PARTIC/mri ]; then	
		mkdir $Study/TRACULA/diffusion_recons/$PARTIC/mri
	fi
	if [ ! -d $Study/TRACULA/diffusion_recons/$PARTIC/mri/orig ]; then	
		mkdir $Study/TRACULA/diffusion_recons/$PARTIC/mri/orig
	fi
	mri_convert --in_type nii --out_type mgz --out_orientation RAS $Study/TRACULA/diffusion_recons/"$PARTIC"_Anatomical.nii $Study/TRACULA/diffusion_recons/$PARTIC/mri/orig/001.mgz
	
	##Create Config File
	echo -e '#!/bin/tcsh\nset workingDIR = "'$Study'/TRACULA"\nset SUBJECTS_DIR = $workingDIR/diffusion_recons\n
setenv SUBJECTS_DIR $workingDIR/diffusion_recons\nset dtroot =  $workingDIR/tractography_output\nset subjlist = ( '$PARTIC' )\nset dcmroot = '$Study'/dti_72_preproc\nset dcmlist = ( $dcmroot/'$PARTIC'/dmri/dwi.nii.gz )\nset bvecfile = ( '$Study'/TRACULA/tractography_output/'$PARTIC'/dmri/bvecs )\nset bvalfile = '$Study'/TRACULA/tractography_output/'$PARTIC'/dmri/bvals \nset ncpts = 7 \nsetenv FREESURFER_HOME /usr/local/freesurfer\nsource $FREESURFER_HOME/SetUpFreeSurfer.csh' >> $Study/TRACULA/tractography_output/$PARTIC/trac_config.txt

	#Source FREESURFER_HOME with SUBJECTS_DIR directory
	SUBJECTS_DIR=$Study/TRACULA/diffusion_recons
	export SUBJECTS_DIR
	source $FREESURFER_HOME/SetUpFreeSurfer.sh

	#Cortical Reconstruction for diffusion_recons
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Cortical Reconstruction'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	recon-all -all -subjid $PARTIC -openmp 12

	#Intrasubject Reg
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Intrasubject Registration'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	trac-all -intra -c $Study/TRACULA/tractography_output/$PARTIC/trac_config.txt 
	
	#Intersubject Reg
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Intersubject Registration'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	trac-all -inter -c $Study/TRACULA/tractography_output/$PARTIC/trac_config.txt 
	
	#Masks Prep
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Mask Prep'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	trac-all -masks -c $Study/TRACULA/tractography_output/$PARTIC/trac_config.txt

	#Priors Prep
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Priors'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	trac-all -prior -c $Study/TRACULA/tractography_output/$PARTIC/trac_config.txt

	#Reconstruct Paths
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Path Reconstruction'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	trac-all -path -c $Study/TRACULA/tractography_output/$PARTIC/trac_config.txt
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 

	#Convert output to table format for group analysis
	mkdir $Study/TRACULA/tractography_output/$PARTIC/stats/ 
	mkdir $Study/TRACULA/tractography_output/$PARTIC/stats/export
	mkdir $Study/TRACULA/tractography_output/$PARTIC/stats/tables 
	echo 'rh.atr_PP_avg33_mni_bbr
	fminor_PP_avg33_mni_bbr
	lh.atr_PP_avg33_mni_bbr
	lh.cab_PP_avg33_mni_bbr
	lh.ccg_PP_avg33_mni_bbr
	lh.cst_AS_avg33_mni_bbr
	lh.ilf_AS_avg33_mni_bbr
	lh.slfp_PP_avg33_mni_bbr
	lh.slft_PP_avg33_mni_bbr
	lh.unc_AS_avg33_mni_bbr
	rh.atr_PP_avg33_mni_bbr
	rh.cab_PP_avg33_mni_bbr
	rh.ccg_PP_avg33_mni_bbr
	rh.cst_AS_avg33_mni_bbr
	rh.ilf_AS_avg33_mni_bbr
	rh.slfp_PP_avg33_mni_bbr
	rh.slft_PP_avg33_mni_bbr
	rh.unc_AS_avg33_mni_bbr' > $Study/TRACULA/tractography_output/$PARTIC/stats/TRACULA_tracts.txt
	filename_tract=$Study/TRACULA/tractography_output/$PARTIC/stats/TRACULA_tracts.txt
	filelines_tracts=`cat $filename_tract`
	for tract in $filelines_tracts; do        
		#FA vals
		tractstats2table --inputs $Study/TRACULA/tractography_output/$PARTIC/dpath/$tract/pathstats.overall.txt --overall --only-measures FA_Avg --tablefile $Study/TRACULA/tractography_output/$PARTIC/stats/tables/$tract.FA.table         
		echo FA."$tract" | cut -f1 -d"_"  > $Study/TRACULA/tractography_output/$PARTIC/stats/export/$tract.FA.num
		cat $Study/TRACULA/tractography_output/$PARTIC/stats/tables/$tract.FA.table | grep -Ewo '[0-9]\.[0-9]*' $xargs >> $Study/TRACULA/tractography_output/$PARTIC/stats/export/$tract.FA.num
		#MD vals
		tractstats2table --inputs $Study/TRACULA/tractography_output/$PARTIC/dpath/$tract/pathstats.overall.txt --overall --only-measures MD_Avg --tablefile $Study/TRACULA/tractography_output/$PARTIC/stats/tables/$tract.MD.table         
		echo MD."$tract" | cut -f1 -d"_"  > $Study/TRACULA/tractography_output/$PARTIC/stats/export/$tract.MD.num               
		cat $Study/TRACULA/tractography_output/$PARTIC/stats/tables/$tract.MD.table | grep -Ewo '[0-9]\.[0-9]*' $xargs >> $Study/TRACULA/tractography_output/$PARTIC/stats/export/$tract.MD.num
	done
	paste $Study/TRACULA/tractography_output/$PARTIC/stats/export/* > $Study/TRACULA/tractography_output/$PARTIC/stats/ALLTRACTS_$PARTIC

	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'TRACULA DONE!'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
fi

if [ $sequence -eq "2" ]; then
	#######TRACULA#####MB2 Sequence
	###Make all TRACULA folders
	if [ ! -d $Study/TRACULA_MB2 ]; then
		mkdir $Study/TRACULA_MB2/
	fi
	if [ ! -d $Study/TRACULA_MB2/diffusion_recons ]; then
		mkdir $Study/TRACULA_MB2/diffusion_recons
	fi
	if [ ! -d $Study/TRACULA_MB2/tractography_output ]; then
		mkdir $Study/TRACULA_MB2/tractography_output
	fi
	if [ ! -d $Study/TRACULA/diffusion_recons/$PARTIC ]; then
		cp -a $Study/TRACULA/diffusion_recons/$PARTIC $Study/TRACULA_MB2/diffusion_recons/$PARTIC
		recons='1'
	fi
	mkdir $Study/TRACULA_MB2/tractography_output/$PARTIC
	mkdir $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri
	mkdir $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri.bedpostX
	mkdir $Study/TRACULA_MB2/tractography_output/$PARTIC/dlabel
	mkdir $Study/TRACULA_MB2/tractography_output/$PARTIC/dlabel/"diff"

	##copy bedpostx files
	cp -a $output_dir/$PARTIC/bedpostx_"$PARTIC".bedpostX/* $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri.bedpostX

	##copy dmri base files
	##DWI image
	cp $output_dir/$PARTIC/eddy_corrected_data_denoised.nii.gz $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri
	mv $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri/eddy_corrected_data_denoised.nii.gz $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri/dwi.nii.gz

	##bvec and bval
	cp $output_dir/$PARTIC/bvec $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri
	mv $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri/bvec $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri/bvecs

	cp $output_dir/$PARTIC/bval $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri
	mv $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri/bval $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri/bvals

	##bet mask
	cp $output_dir/$PARTIC/bet_mask.nii.gz $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri
	mv $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri/bet_mask.nii.gz $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz
	cp $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz $Study/TRACULA_MB2/tractography_output/$PARTIC/dlabel/"diff"
	mv $Study/TRACULA_MB2/tractography_output/$PARTIC/dlabel/"diff"/nodif_brain_mask.nii.gz $Study/TRACULA_MB2/tractography_output/$PARTIC/dlabel/"diff"/lowb_brain_mask.nii.gz
	cp $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz
	mv $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri/lowb.nii.gz

	##copy DTIFIT output to dmri
	if [ ! -f $output_dir/$PARTIC/dtifit_* ]; then
		cd $output_dir/$PARTIC/
		for i in `find . -type f -name "$PARTIC*" -not -iname "*.nrrd" -maxdepth 1`; do
			mv -v $i ${i/"$PARTIC"/dtifit};
		done
	fi

 
	cp -a $output_dir/$PARTIC/dtifit_* $Study/TRACULA_MB2/tractography_output/$PARTIC/dmri

	#Repeat Anatomical?
        NumbAnat=`find $T1directory -iname '*Anatomical*' | wc -l`

        #Repeat Anatomical
        if [ $NumbAnat -eq "2" ]; then
                cp $T1directory/*Anatomical_Repeat.nii $Study/TRACULA_MB2/diffusion_recons
                mv $Study/TRACULA_MB2/diffusion_recons/*Anatomical_Repeat.nii $Study/TRACULA_MB2/diffusion_recons/"$PARTIC"_Anatomical.nii
                echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'                   
		echo "USED REPEAT ANATOMICAL!"
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n' 
		echo -en '\n'  
		echo -en '\n';
        elif [ $NumbAnat -eq "1" ]; then
                cp $T1directory/"$PARTIC"_Anatomical.nii $Study/TRACULA_MB2/diffusion_recons;
        fi


	#Convert Anatomical to .mgz
	if [ ! -d $Study/TRACULA_MB2/diffusion_recons/$PARTIC ]; then	
		mkdir $Study/TRACULA_MB2/diffusion_recons/$PARTIC
	fi
	if [ ! -d $Study/TRACULA_MB2/diffusion_recons/$PARTIC/mri ]; then	
		mkdir $Study/TRACULA_MB2/diffusion_recons/$PARTIC/mri
	fi
	if [ ! -d $Study/TRACULA_MB2/diffusion_recons/$PARTIC/mri/orig ]; then	
		mkdir $Study/TRACULA_MB2/diffusion_recons/$PARTIC/mri/orig
	fi
	mri_convert --in_type nii --out_type mgz --out_orientation RAS $Study/TRACULA_MB2/diffusion_recons/"$PARTIC"_Anatomical.nii $Study/TRACULA_MB2/diffusion_recons/$PARTIC/mri/orig/001.mgz

	##Create Config File
	echo -e '#!/bin/tcsh\nset workingDIR = "'$Study'/TRACULA_MB2"\nset SUBJECTS_DIR = $workingDIR/diffusion_recons\n
setenv SUBJECTS_DIR $workingDIR/diffusion_recons\nset dtroot =  $workingDIR/tractography_output\nset subjlist = ( '$PARTIC' )\nset dcmroot = '$Study'/MB2\nset dcmlist = ( $dcmroot/'$PARTIC'/dmri/dwi.nii.gz )\nset bvecfile = ( '$Study'/TRACULA_MB2/tractography_output/'$PARTIC'/dmri/bvecs )\nset bvalfile = '$Study'/TRACULA_MB2/tractography_output/'$PARTIC'/dmri/bvals \nset ncpts = 7 \nsetenv FREESURFER_HOME /usr/local/freesurfer\nsource $FREESURFER_HOME/SetUpFreeSurfer.csh' >> $Study/TRACULA_MB2/tractography_output/$PARTIC/trac_config.txt

	#Source FREESURFER_HOME with SUBJECTS_DIR directory
	SUBJECTS_DIR=$Study/TRACULA/diffusion_recons
	export SUBJECTS_DIR
	source $FREESURFER_HOME/SetUpFreeSurfer.sh	

	#Cortical Reconstruction for diffusion_recons
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Cortical Reconstruction'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	if [ $recons -eq "1" ]; then
		echo "Reconstruction already completed. Using existing . . ."
	else
		recon-all -all -subjid $PARTIC -openmp 12
	fi

	#Intrasubject Reg
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Intrasubject Registration'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	trac-all -intra -c $Study/TRACULA_MB2/tractography_output/$PARTIC/trac_config.txt 
	
	#Intersubject Reg
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Intersubject Registration'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	trac-all -inter -c $Study/TRACULA_MB2/tractography_output/$PARTIC/trac_config.txt 
	
	#Masks Prep
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Mask Prep'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	trac-all -masks -c $Study/TRACULA_MB2/tractography_output/$PARTIC/trac_config.txt

	#Priors Prep
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Priors'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	trac-all -prior -c $Study/TRACULA_MB2/tractography_output/$PARTIC/trac_config.txt

	#Reconstruct Paths
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Path Reconstruction'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	trac-all -path -c $Study/TRACULA_MB2/tractography_output/$PARTIC/trac_config.txt
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	
	#Convert output to table format for group analysis
	mkdir $Study/TRACULA_MB2/tractography_output/$PARTIC/stats/ 
	mkdir $Study/TRACULA_MB2/tractography_output/$PARTIC/stats/export
	mkdir $Study/TRACULA_MB2/tractography_output/$PARTIC/stats/tables 
	echo 'rh.atr_PP_avg33_mni_bbr
	fminor_PP_avg33_mni_bbr
	lh.atr_PP_avg33_mni_bbr
	lh.cab_PP_avg33_mni_bbr
	lh.ccg_PP_avg33_mni_bbr
	lh.cst_AS_avg33_mni_bbr
	lh.ilf_AS_avg33_mni_bbr
	lh.slfp_PP_avg33_mni_bbr
	lh.slft_PP_avg33_mni_bbr
	lh.unc_AS_avg33_mni_bbr
	rh.atr_PP_avg33_mni_bbr
	rh.cab_PP_avg33_mni_bbr
	rh.ccg_PP_avg33_mni_bbr
	rh.cst_AS_avg33_mni_bbr
	rh.ilf_AS_avg33_mni_bbr
	rh.slfp_PP_avg33_mni_bbr
	rh.slft_PP_avg33_mni_bbr
	rh.unc_AS_avg33_mni_bbr' > $Study/TRACULA_MB2/tractography_output/$PARTIC/stats/TRACULA_MB2_tracts.txt
	filename_tract=$Study/TRACULA_MB2/tractography_output/$PARTIC/stats/TRACULA_MB2_tracts.txt
	filelines_tracts=`cat $filename_tract`
	for tract in $filelines_tracts; do        
		#FA vals
		tractstats2table --inputs $Study/TRACULA_MB2/tractography_output/$PARTIC/dpath/$tract/pathstats.overall.txt --overall --only-measures FA_Avg --tablefile $Study/TRACULA_MB2/tractography_output/$PARTIC/stats/tables/$tract.FA.table         
		echo FA."$tract" | cut -f1 -d"_"  > $Study/TRACULA_MB2/tractography_output/$PARTIC/stats/export/$tract.FA.num
		cat $Study/TRACULA_MB2/tractography_output/$PARTIC/stats/tables/$tract.FA.table | grep -Ewo '[0-9]\.[0-9]*' $xargs >> $Study/TRACULA_MB2/tractography_output/$PARTIC/stats/export/$tract.FA.num
		#MD vals
		tractstats2table --inputs $Study/TRACULA_MB2/tractography_output/$PARTIC/dpath/$tract/pathstats.overall.txt --overall --only-measures MD_Avg --tablefile $Study/TRACULA_MB2/tractography_output/$PARTIC/stats/tables/$tract.MD.table         
		echo MD."$tract" | cut -f1 -d"_"  > $Study/TRACULA_MB2/tractography_output/$PARTIC/stats/export/$tract.MD.num               
		cat $Study/TRACULA_MB2/tractography_output/$PARTIC/stats/tables/$tract.MD.table | grep -Ewo '[0-9]\.[0-9]*' $xargs >> $Study/TRACULA_MB2/tractography_output/$PARTIC/stats/export/$tract.MD.num
	done
	paste $Study/TRACULA_MB2/tractography_output/$PARTIC/stats/export/* > $Study/TRACULA_MB2/tractography_output/$PARTIC/stats/ALLTRACTS_$PARTIC
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'TRACULA DONE!'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
fi
if [ $sequence -eq "3" ]; then
	#######TRACULA#####MB2 Sequence
	###Make all TRACULA folders
	if [ ! -d $Study/TRACULA_MB3 ]; then
		mkdir $Study/TRACULA_MB3/
	fi
	if [ ! -d $Study/TRACULA_MB3/diffusion_recons ]; then
		mkdir $Study/TRACULA_MB3/diffusion_recons
	fi
	if [ ! -d $Study/TRACULA_MB3/tractography_output ]; then
		mkdir $Study/TRACULA_MB3/tractography_output
	fi
	if [ -d $Study/TRACULA/diffusion_recons/$PARTIC ]; then
		cp -a $Study/TRACULA/diffusion_recons/$PARTIC $Study/TRACULA_MB3/diffusion_recons/$PARTIC
		recons='1'
	fi
	mkdir $Study/TRACULA_MB3/tractography_output/$PARTIC
	mkdir $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri
	mkdir $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri.bedpostX
	mkdir $Study/TRACULA_MB3/tractography_output/$PARTIC/dlabel
	mkdir $Study/TRACULA_MB3/tractography_output/$PARTIC/dlabel/"diff"

	##copy bedpostx files
	cp -a $output_dir/$PARTIC/bedpostx_"$PARTIC".bedpostX/* $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri.bedpostX

	##copy dmri base files
	##DWI image
	cp $output_dir/$PARTIC/eddy_corrected_data_denoised.nii.gz $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri
	mv $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri/eddy_corrected_data_denoised.nii.gz $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri/dwi.nii.gz

	##bvec and bval
	cp $output_dir/$PARTIC/bvec $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri
	mv $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri/bvec $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri/bvecs

	cp $output_dir/$PARTIC/bval $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri
	mv $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri/bval $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri/bvals

	##bet mask
	cp $output_dir/$PARTIC/bet_mask.nii.gz $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri
	mv $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri/bet_mask.nii.gz $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz
	cp $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz $Study/TRACULA_MB3/tractography_output/$PARTIC/dlabel/"diff"
	mv $Study/TRACULA_MB3/tractography_output/$PARTIC/dlabel/"diff"/nodif_brain_mask.nii.gz $Study/TRACULA_MB3/tractography_output/$PARTIC/dlabel/"diff"/lowb_brain_mask.nii.gz
	cp $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz
	mv $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri/lowb.nii.gz

	##copy DTIFIT output to dmri
	if [ ! -f $output_dir/$PARTIC/dtifit_* ]; then
		cd $output_dir/$PARTIC/
		for i in `find . -type f -name "$PARTIC*" -not -iname "*.nrrd" -maxdepth 1`; do
			mv -v $i ${i/"$PARTIC"/dtifit};
		done
	fi

 
	cp -a $output_dir/$PARTIC/dtifit_* $Study/TRACULA_MB3/tractography_output/$PARTIC/dmri

	#Repeat Anatomical?
        NumbAnat=`find $T1directory -iname '*Anatomical*' | wc -l`

        #Repeat Anatomical
        if [ $NumbAnat -eq "2" ]; then
                cp $T1directory/*Anatomical_Repeat.nii $Study/TRACULA_MB3/diffusion_recons
                mv $Study/TRACULA_MB3/diffusion_recons/*Anatomical_Repeat.nii $Study/TRACULA_MB3/diffusion_recons/"$PARTIC"_Anatomical.nii
                echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'                   
		echo "USED REPEAT ANATOMICAL!"
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n' 
		echo -en '\n'  
		echo -en '\n';
        elif [ $NumbAnat -eq "1" ]; then
                cp $T1directory/"$PARTIC"_Anatomical.nii $Study/TRACULA_MB3/diffusion_recons;
        fi


	#Convert Anatomical to .mgz
	if [ ! -d $Study/TRACULA_MB3/diffusion_recons/$PARTIC ]; then	
		mkdir $Study/TRACULA_MB3/diffusion_recons/$PARTIC
	fi
	if [ ! -d $Study/TRACULA_MB3/diffusion_recons/$PARTIC/mri ]; then	
		mkdir $Study/TRACULA_MB3/diffusion_recons/$PARTIC/mri
	fi
	if [ ! -d $Study/TRACULA_MB3/diffusion_recons/$PARTIC/mri/orig ]; then	
		mkdir $Study/TRACULA_MB3/diffusion_recons/$PARTIC/mri/orig
	fi
	mri_convert --in_type nii --out_type mgz --out_orientation RAS $Study/TRACULA_MB3/diffusion_recons/"$PARTIC"_Anatomical.nii $Study/TRACULA_MB3/diffusion_recons/$PARTIC/mri/orig/001.mgz

	##Create Config File
	echo -e '#!/bin/tcsh\nset workingDIR = "'$Study'/TRACULA_MB3"\nset SUBJECTS_DIR = $workingDIR/diffusion_recons\n
setenv SUBJECTS_DIR $workingDIR/diffusion_recons\nset dtroot =  $workingDIR/tractography_output\nset subjlist = ( '$PARTIC' )\nset dcmroot = '$Study'/MB2\nset dcmlist = ( $dcmroot/'$PARTIC'/dmri/dwi.nii.gz )\nset bvecfile = ( '$Study'/TRACULA_MB3/tractography_output/'$PARTIC'/dmri/bvecs )\nset bvalfile = '$Study'/TRACULA_MB3/tractography_output/'$PARTIC'/dmri/bvals \nset ncpts = 7 \nsetenv FREESURFER_HOME /usr/local/freesurfer\nsource $FREESURFER_HOME/SetUpFreeSurfer.csh' >> $Study/TRACULA_MB3/tractography_output/$PARTIC/trac_config.txt

	#Source FREESURFER_HOME with SUBJECTS_DIR directory
	SUBJECTS_DIR=$Study/TRACULA/diffusion_recons
	export SUBJECTS_DIR
	source $FREESURFER_HOME/SetUpFreeSurfer.sh	

	#Cortical Reconstruction for diffusion_recons
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Cortical Reconstruction'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	if [ $recons -eq "1" ]; then
		echo "Reconstruction already completed. Using existing . . ."
	else
		recon-all -all -subjid $PARTIC -openmp 12
	fi

	#Intrasubject Reg
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Intrasubject Registration'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	trac-all -intra -c $Study/TRACULA_MB3/tractography_output/$PARTIC/trac_config.txt 
	
	#Intersubject Reg
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Intersubject Registration'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	trac-all -inter -c $Study/TRACULA_MB3/tractography_output/$PARTIC/trac_config.txt 
	
	#Masks Prep
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Mask Prep'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	trac-all -masks -c $Study/TRACULA_MB3/tractography_output/$PARTIC/trac_config.txt

	#Priors Prep
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Priors'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	trac-all -prior -c $Study/TRACULA_MB3/tractography_output/$PARTIC/trac_config.txt

	#Reconstruct Paths
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'Running Path Reconstruction'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	trac-all -path -c $Study/TRACULA_MB3/tractography_output/$PARTIC/trac_config.txt
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	
	#Convert output to table format for group analysis
	mkdir $Study/TRACULA_MB3/tractography_output/$PARTIC/stats/ 
	mkdir $Study/TRACULA_MB3/tractography_output/$PARTIC/stats/export
	mkdir $Study/TRACULA_MB3/tractography_output/$PARTIC/stats/tables 
	echo 'rh.atr_PP_avg33_mni_bbr
	fminor_PP_avg33_mni_bbr
	lh.atr_PP_avg33_mni_bbr
	lh.cab_PP_avg33_mni_bbr
	lh.ccg_PP_avg33_mni_bbr
	lh.cst_AS_avg33_mni_bbr
	lh.ilf_AS_avg33_mni_bbr
	lh.slfp_PP_avg33_mni_bbr
	lh.slft_PP_avg33_mni_bbr
	lh.unc_AS_avg33_mni_bbr
	rh.atr_PP_avg33_mni_bbr
	rh.cab_PP_avg33_mni_bbr
	rh.ccg_PP_avg33_mni_bbr
	rh.cst_AS_avg33_mni_bbr
	rh.ilf_AS_avg33_mni_bbr
	rh.slfp_PP_avg33_mni_bbr
	rh.slft_PP_avg33_mni_bbr
	rh.unc_AS_avg33_mni_bbr' > $Study/TRACULA_MB3/tractography_output/$PARTIC/stats/TRACULA_MB3_tracts.txt
	filename_tract=$Study/TRACULA_MB3/tractography_output/$PARTIC/stats/TRACULA_MB3_tracts.txt
	filelines_tracts=`cat $filename_tract`
	for tract in $filelines_tracts; do        
		#FA vals
		tractstats2table --inputs $Study/TRACULA_MB3/tractography_output/$PARTIC/dpath/$tract/pathstats.overall.txt --overall --only-measures FA_Avg --tablefile $Study/TRACULA_MB3/tractography_output/$PARTIC/stats/tables/$tract.FA.table         
		echo FA."$tract" | cut -f1 -d"_"  > $Study/TRACULA_MB3/tractography_output/$PARTIC/stats/export/$tract.FA.num
		cat $Study/TRACULA_MB3/tractography_output/$PARTIC/stats/tables/$tract.FA.table | grep -Ewo '[0-9]\.[0-9]*' $xargs >> $Study/TRACULA_MB3/tractography_output/$PARTIC/stats/export/$tract.FA.num
		#MD vals
		tractstats2table --inputs $Study/TRACULA_MB3/tractography_output/$PARTIC/dpath/$tract/pathstats.overall.txt --overall --only-measures MD_Avg --tablefile $Study/TRACULA_MB3/tractography_output/$PARTIC/stats/tables/$tract.MD.table         
		echo MD."$tract" | cut -f1 -d"_"  > $Study/TRACULA_MB3/tractography_output/$PARTIC/stats/export/$tract.MD.num               
		cat $Study/TRACULA_MB3/tractography_output/$PARTIC/stats/tables/$tract.MD.table | grep -Ewo '[0-9]\.[0-9]*' $xargs >> $Study/TRACULA_MB3/tractography_output/$PARTIC/stats/export/$tract.MD.num
	done
	paste $Study/TRACULA_MB3/tractography_output/$PARTIC/stats/export/* > $Study/TRACULA_MB3/tractography_output/$PARTIC/stats/ALLTRACTS_$PARTIC
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'TRACULA DONE!'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
fi
