#!/bin/sh
#dwi_dir:   First input, path of directory containing raw dwi set
#P2A:       Second input, path of directory containing reversed phase encode images
#acqparams: Path to acqparams.txt, Acquisition parameters for running TOPUP and EDDY
#index:     Path to index.txt, File containing index relating image volumes to acqparams.txt
#output_dir:Path to directory results will go in
#b0_indices:Text file containing indices of b0 images in raw dwi set (e.g. 0 10 20 30)
#OddSlices: 0=dataset has even number of slices, 1=remove top slice of dataset, 2=remove bottom slice of dataset

dwi_dir=${1}
P2A=${2}
output_dir=${3}
OddSlices=${4}
PARTIC=${5}
sequence=${6}
T1directory=${7}
Study=${8}
preproc=${9}
tracula=${10}
buildvol=${11}
probtracking=${12}
eddy_type=${13}

if [ $preproc -eq "1" ]; then
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
	
	if [ $eddy_type -eq "1" ]; then
		#Create b0_indices file
		echo "0 73 74 75 76 77" > b0_indices

		if [ $sequence -eq "1" ] || [ $sequence -eq "2" ]; then
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
	else
		#Old Eddy Correction
		eddy_correct original_data.nii.gz eddy_corrected_data.nii.gz 0
	fi

	chmod 775 -R $output_dir/$PARTIC/

	#Rotate bvec file to match eddy correction
	#Because with 'eddy' we cannot separate rotations due to motion and/or eddy currents it is recommended that this not be performed unless motion is obvious
	#matlab -nodisplay -nosplash -nojvm -r "addpath(genpath('/usr/local/FSL_ReorientBvecs'));FSL_ReorientBvecs(eddy_corrected_data.nii.gz.eddy_parameters,bvec)"
	#Convert Eddy Corrected Dataset from *.nii.gz to *.nii for MATLAB LPCA algorithm
	dcm2nii -g n -m n eddy_corrected_data.nii.gz
	chmod 775 -R $output_dir/$PARTIC/
	matlab -nodesktop -nosplash -r "c = parcluster; j = c.batch(@Run_LPCA, 1, {'feddy_corrected_data.nii', 'bval'}, 'Pool', 55, 'AdditionalPaths', {'/usr/local/LPCA Denoising Software', '/usr/local/nifti_analyzer'});"
	#matlab -nodesktop -nosplash -r "addpath(genpath('/usr/local/LPCA Denoising Software'));LPCAscript('feddy_corrected_data.nii'); quit;"
	until [ -f ./feddy_corrected_data_denoised.nii ]
	do
	     sleep 5
	done
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
	
	#Check for motion outliers
	echo -en '\n'
	echo -en '\n'
	echo -en '\n'
	echo -en '\n'
	echo "Checking for motion outliers ..."	
	if [ $eddy_type -eq "1" ]; then	
		ec_plot_NEW.sh eddy_corrected_data.nii.gz
	else
		ec_plot.sh eddy_corrected_data.ecclog
	fi

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
	
	echo MOTION_OUTLIERS.txt
	
	until [ `ls -l $output_dir/$PARTIC/bedpostx_"$PARTIC".bedpostX | grep -v ^l | wc -l` -ge "38" ]
	do
	     sleep 200
	done
	
	#Delete Unneccessary files
	rm -f $output_dir/"$PARTIC"/eddy_corrected_data.nii.gz 
	rm -f $output_dir/"$PARTIC"/feddy_corrected_data_denoised.nii 
	rm -f $output_dir/"$PARTIC"/feddy_corrected_data.nii
	rm -rf $output_dir/"$PARTIC"/bedpostx_$PARTIC

elif [ $preproc -eq "0" ]; then
	echo -en '\n'
	echo -en '\n'   
	echo -en '\n'   
	echo -en '\n'
	echo -en '\n'   
	echo "Preprocessing skipped!"
	echo -en '\n'
	echo -en '\n'   
	echo -en '\n'   
	echo -en '\n'
	echo -en '\n'   
fi


##########Tractography############
if [ $sequence -eq "1" ]; then
	tracdir="TRACULA"
elif [ $sequence -eq "2" ]; then
	tracdir="TRACULA_MB2"
elif [ $sequence -eq "3" ]; then
	tracdir="TRACULA_MB3"
fi

if [ $tracula -eq "1" ]; then
	#######TRACULA#####Standard Sequence
	###Make all TRACULA folders
	if [ ! -d $Study/$tracdir ]; then
		mkdir $Study/$tracdir/
	fi
	if [ ! -d $Study/$tracdir/diffusion_recons ]; then
		mkdir $Study/$tracdir/diffusion_recons
	fi
	if [ ! -d $Study/$tracdir/tractography_output ]; then
		mkdir $Study/$tracdir/tractography_output
	fi
	if [ ! -d $Study/$tracdir/tractography_output/$PARTIC ]; then
		mkdir $Study/$tracdir/tractography_output/$PARTIC
	fi
	if [ ! -d $Study/$tracdir/tractography_output/$PARTIC/dmri ]; then
		mkdir $Study/$tracdir/tractography_output/$PARTIC/dmri
	fi
	if [ ! -d $Study/$tracdir/tractography_output/$PARTIC/dmri.bedpostX ]; then
		mkdir $Study/$tracdir/tractography_output/$PARTIC/dmri.bedpostX
	fi
	if [ ! -d $Study/$tracdir/tractography_output/$PARTIC/dlabel ]; then
		mkdir $Study/$tracdir/tractography_output/$PARTIC/dlabel
	fi
	if [ ! -d $Study/$tracdir/tractography_output/$PARTIC/dlabel/"diff" ]; then
		mkdir $Study/$tracdir/tractography_output/$PARTIC/dlabel/"diff"
	fi

	##copy bedpostx files
	cp -a $output_dir/$PARTIC/bedpostx_"$PARTIC".bedpostX/* $Study/$tracdir/tractography_output/$PARTIC/dmri.bedpostX

	##copy dmri base files
	##DWI image
	cp $output_dir/$PARTIC/eddy_corrected_data_denoised.nii.gz $Study/$tracdir/tractography_output/$PARTIC/dmri
	mv $Study/$tracdir/tractography_output/$PARTIC/dmri/eddy_corrected_data_denoised.nii.gz $Study/$tracdir/tractography_output/$PARTIC/dmri/dwi.nii.gz

	##bvec and bval
	cp $output_dir/$PARTIC/bvec $Study/$tracdir/tractography_output/$PARTIC/dmri
	mv $Study/$tracdir/tractography_output/$PARTIC/dmri/bvec $Study/$tracdir/tractography_output/$PARTIC/dmri/bvecs

	cp $output_dir/$PARTIC/bval $Study/$tracdir/tractography_output/$PARTIC/dmri
	mv $Study/$tracdir/tractography_output/$PARTIC/dmri/bval $Study/$tracdir/tractography_output/$PARTIC/dmri/bvals

	##bet mask
	cp $output_dir/$PARTIC/bet_mask.nii.gz $Study/$tracdir/tractography_output/$PARTIC/dmri
	mv $Study/$tracdir/tractography_output/$PARTIC/dmri/bet_mask.nii.gz $Study/$tracdir/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz
	cp $Study/$tracdir/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz $Study/$tracdir/tractography_output/$PARTIC/dlabel/"diff"
	mv $Study/$tracdir/tractography_output/$PARTIC/dlabel/"diff"/nodif_brain_mask.nii.gz $Study/$tracdir/tractography_output/$PARTIC/dlabel/"diff"/lowb_brain_mask.nii.gz
	cp $Study/$tracdir/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz $Study/$tracdir/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz
	mv $Study/$tracdir/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz $Study/$tracdir/tractography_output/$PARTIC/dmri/lowb.nii.gz

	##copy DTIFIT output to dmri
	if [ ! -f $output_dir/$PARTIC/dtifit_* ]; then
		cd $output_dir/$PARTIC/
		for i in `find . -type f -name "$PARTIC*" -not -iname "*.nrrd" -maxdepth 1`; do
			mv -v $i ${i/"$PARTIC"/dtifit};
		done
	fi

	##copy DTIFIT output to dmri
	cp -a $output_dir/$PARTIC/dtifit_* $Study/$tracdir/tractography_output/$PARTIC/dmri

	#Repeat Anatomical?
	NumbAnat=`find $T1directory -iname '*Anatomical*' | wc -l`

	#Repeat Anatomical
	if [ $NumbAnat -eq "2" ]; then
	        cp $T1directory/*Anatomical_Repeat.nii $Study/$tracdir/diffusion_recons
	        mv $Study/$tracdir/diffusion_recons/*Anatomical_Repeat.nii $Study/$tracdir/diffusion_recons/"$PARTIC"_Anatomical.nii
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
	        cp $T1directory/"$PARTIC"_Anatomical.nii $Study/$tracdir/diffusion_recons;
	fi

	#Convert Anatomical to .mgz
	if [ ! -d $Study/$tracdir/diffusion_recons/$PARTIC ]; then	
		mkdir $Study/$tracdir/diffusion_recons/$PARTIC
	fi
	if [ ! -d $Study/$tracdir/diffusion_recons/$PARTIC/mri ]; then	
		mkdir $Study/$tracdir/diffusion_recons/$PARTIC/mri
	fi
	if [ ! -d $Study/$tracdir/diffusion_recons/$PARTIC/mri/orig ]; then	
		mkdir $Study/$tracdir/diffusion_recons/$PARTIC/mri/orig
	fi
	mri_convert --in_type nii --out_type mgz --out_orientation RAS $Study/$tracdir/diffusion_recons/"$PARTIC"_Anatomical.nii $Study/$tracdir/diffusion_recons/$PARTIC/mri/orig/001.mgz

	##Create Config File
	#Delete Config File if already existing
	if [ -f "$Study/$tracdir/tractography_output/$PARTIC/trac_config.txt" ]; then
		rm -f "$Study/$tracdir/tractography_output/$PARTIC/trac_config.txt"
	fi
	echo -e '#!/bin/tcsh\nset workingDIR = "'$Study'/'$tracdir'"\nset SUBJECTS_DIR = $workingDIR/diffusion_recons\n
setenv SUBJECTS_DIR $workingDIR/diffusion_recons\nset dtroot =  $workingDIR/tractography_output\nset subjlist = ( '$PARTIC' )\nset dcmroot = '$Study'/dti_72_preproc\nset dcmlist = ( $dcmroot/'$PARTIC'/dmri/dwi.nii.gz )\nset bvecfile = ( '$Study'/'$tracdir'/tractography_output/'$PARTIC'/dmri/bvecs )\nset bvalfile = '$Study'/'$tracdir'/tractography_output/'$PARTIC'/dmri/bvals \nset ncpts = 7 \nsetenv FREESURFER_HOME /usr/local/freesurfer\nsource $FREESURFER_HOME/SetUpFreeSurfer.csh' >> "$Study/$tracdir/tractography_output/$PARTIC/trac_config.txt"

	#Source FREESURFER_HOME with SUBJECTS_DIR directory
	SUBJECTS_DIR="$Study/$tracdir/diffusion_recons"
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
	if grep -q "finished without error" "$Study/$tracdir/diffusion_recons/$PARTIC/scripts/recon-all.log"; then
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n' 
		echo "RECONSTRUCTION already completed. Skipping..."
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n'   
		echo -en '\n' 
	else 
		recon-all -all -s "$PARTIC"
	fi		
	
	#QA for FREESURFER recon
	export SUBJECTS_DIR=$Study/$tracdir/diffusion_recons
	export QA_TOOLS=$FREESURFER_HOME/Freesurfer_QA_scripts

	$QA_TOOLS/recon_checker -s "$PARTIC" -snaps-only

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
	trac-all -intra -c $Study/$tracdir/tractography_output/$PARTIC/trac_config.txt 

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
	trac-all -inter -c $Study/$tracdir/tractography_output/$PARTIC/trac_config.txt 

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
	trac-all -masks -c $Study/$tracdir/tractography_output/$PARTIC/trac_config.txt

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
	trac-all -prior -c $Study/$tracdir/tractography_output/$PARTIC/trac_config.txt

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
	trac-all -path -c $Study/$tracdir/tractography_output/$PARTIC/trac_config.txt
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 

	#Convert output to table format for group analysis
	mkdir $Study/$tracdir/tractography_output/$PARTIC/stats/ 
	mkdir $Study/$tracdir/tractography_output/$PARTIC/stats/export
	mkdir $Study/$tracdir/tractography_output/$PARTIC/stats/tables 
	echo 'fmajor_PP_avg33_mni_bbr
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
	rh.unc_AS_avg33_mni_bbr' > $Study/$tracdir/tractography_output/$PARTIC/stats/TRACULA_tracts.txt
	filename_tract=$Study/$tracdir/tractography_output/$PARTIC/stats/TRACULA_tracts.txt
	filelines_tracts=`cat $filename_tract`
	for tract in $filelines_tracts; do        
		#FA vals
		tractstats2table --inputs $Study/$tracdir/tractography_output/$PARTIC/dpath/$tract/pathstats.overall.txt --overall --only-measures FA_Avg --tablefile $Study/$tracdir/tractography_output/$PARTIC/stats/tables/$tract.FA.table         
		echo FA."$tract" | cut -f1 -d"_"  > $Study/$tracdir/tractography_output/$PARTIC/stats/export/$tract.FA.num
		cat $Study/$tracdir/tractography_output/$PARTIC/stats/tables/$tract.FA.table | grep -Ewo '[0-9]\.[0-9]*' $xargs >> $Study/$tracdir/tractography_output/$PARTIC/stats/export/$tract.FA.num
		#MD vals
		tractstats2table --inputs $Study/$tracdir/tractography_output/$PARTIC/dpath/$tract/pathstats.overall.txt --overall --only-measures MD_Avg --tablefile $Study/$tracdir/tractography_output/$PARTIC/stats/tables/$tract.MD.table         
		echo MD."$tract" | cut -f1 -d"_"  > $Study/$tracdir/tractography_output/$PARTIC/stats/export/$tract.MD.num               
		cat $Study/$tracdir/tractography_output/$PARTIC/stats/tables/$tract.MD.table | grep -Ewo '[0-9]\.[0-9]*' $xargs >> $Study/$tracdir/tractography_output/$PARTIC/stats/export/$tract.MD.num
		#RD vals
		tractstats2table --inputs $Study/$tracdir/tractography_output/$PARTIC/dpath/$tract/pathstats.overall.txt --overall --only-measures RD_Avg --tablefile $Study/$tracdir/tractography_output/$PARTIC/stats/tables/$tract.RD.table         
		echo RD."$tract" | cut -f1 -d"_"  > $Study/$tracdir/tractography_output/$PARTIC/stats/export/$tract.RD.num               
		cat $Study/$tracdir/tractography_output/$PARTIC/stats/tables/$tract.RD.table | grep -Ewo '[0-9]\.[0-9]*' $xargs >> $Study/$tracdir/tractography_output/$PARTIC/stats/export/$tract.RD.num
		#AD vals
		tractstats2table --inputs $Study/$tracdir/tractography_output/$PARTIC/dpath/$tract/pathstats.overall.txt --overall --only-measures AD_Avg --tablefile $Study/$tracdir/tractography_output/$PARTIC/stats/tables/$tract.AD.table         
		echo AD."$tract" | cut -f1 -d"_"  > $Study/$tracdir/tractography_output/$PARTIC/stats/export/$tract.AD.num               
		cat $Study/$tracdir/tractography_output/$PARTIC/stats/tables/$tract.AD.table | grep -Ewo '[0-9]\.[0-9]*' $xargs >> $Study/$tracdir/tractography_output/$PARTIC/stats/export/$tract.AD.num
	done

	#Calculate global FA
	rm $Study/$tracdir/tractography_output/$PARTIC/stats/export/Global_FA
	echo "Global_FA" > $Study/$tracdir/tractography_output/$PARTIC/stats/export/Global_FA.num
	echo `fslstats $Study/$tracdir/tractography_output/$PARTIC/dmri/dtifit_FA.nii.gz -m` >> $Study/$tracdir/tractography_output/$PARTIC/stats/export/Global_FA.num

	paste $Study/$tracdir/tractography_output/$PARTIC/stats/export/* > $Study/$tracdir/tractography_output/$PARTIC/stats/ALLTRACTS_$PARTIC
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e 'TRACULA DONE!'
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 

elif [ $tracula -eq "0" ]; then
	echo -en '\n'
	echo -en '\n'   
	echo -en '\n'   
	echo -en '\n'
	echo -en '\n'   
	echo "TRACULA skipped!"
	echo -en '\n'
	echo -en '\n'   
	echo -en '\n'   
	echo -en '\n'
	echo -en '\n'   
fi

	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	echo -e "AND DON'T WORRY, we'll get some Gray Matter stats too..."
	echo -en '\n'
	echo -en '\n' 
	echo -en '\n' 
	echo -en '\n' 
	sleep 5

	#Generate GM Volume Table
	asegstats2table -s $Study/$tracdir/diffusion_recons/$PARTIC/ --tablefile $Study/$tracdir/diffusion_recons/$PARTIC/aseg_stats_vals_int.table
	awk 'BEGIN{FS=OFS="\t"}{$1="";sub("\t","")}1' $Study/$tracdir/diffusion_recons/$PARTIC/aseg_stats_vals_int.table > $Study/$tracdir/diffusion_recons/$PARTIC/aseg_stats_vals.table
	pr -tmJ $Study/$tracdir/tractography_output/$PARTIC/stats/ALLTRACTS_$PARTIC $Study/$tracdir/diffusion_recons/$PARTIC/aseg_stats_vals.table > $Study/$tracdir/tractography_output/$PARTIC/stats/ALLTRACTS_AND_GMSTATS_"$PARTIC"


if [ $buildvol -eq "1" ]; then 
	#Build Pial Surface for CONN
	rm $Study/$tracdir/diffusion_recons/$PARTIC/scripts/IsRunning.lh+rh
	recon-all -autorecon-pial -subjid $PARTIC -sd $Study/$tracdir/diffusion_recons
	mkdir $Study/$tracdir/tractography_output/$PARTIC/dlabel/'diff'/surf/
	cp -a $Study/$tracdir/diffusion_recons/$PARTIC/surf/* $Study/$tracdir/tractography_output/$PARTIC/dlabel/'diff'/surf/	
fi

cd $Study/$tracdir/tractography_output

#Create headers for database file
if [ ! -f $Study/$tracdir/tractography_output/database ]; then
	touch $Study/$tracdir/tractography_output/database
	echo "Creating new database file."
	echo -e "Partic\tAD.fmajor\tFA.fmajor\tMD.fmajor\tRD.fmajor\tAD.fminor\tFA.fminor\tMD.fminor\tRD.fminor\tGlobal_FA\tAD.lh.atr\tFA.lh.atr\tMD.lh.atr\tRD.lh.atr\tAD.lh.cab\tFA.lh.cab\tMD.lh.cab\tRD.lh.cab\tAD.lh.ccg\tFA.lh.ccg\tMD.lh.ccg\tRD.lh.ccg\tAD.lh.cst\tFA.lh.cst\tMD.lh.cst\tRD.lh.cst\tAD.lh.ilf\tFA.lh.ilf\tMD.lh.ilf\tRD.lh.ilf\tAD.lh.slfp\tFA.lh.slfp\tMD.lh.slfp\tRD.lh.slfp\tAD.lh.slft\tFA.lh.slft\tMD.lh.slft\tRD.lh.slft\tAD.lh.unc\tFA.lh.unc\tMD.lh.unc\tRD.lh.unc\tAD.rh.atr\tFA.rh.atr\tMD.rh.atr\tRD.rh.atr\tAD.rh.cab\tFA.rh.cab\tMD.rh.cab\tRD.rh.cab\tAD.rh.ccg\tFA.rh.ccg\tMD.rh.ccg\tRD.rh.ccg\tAD.rh.cst\tFA.rh.cst\tMD.rh.cst\tRD.rh.cst\tAD.rh.ilf\tFA.rh.ilf\tMD.rh.ilf\tRD.rh.ilf\tAD.rh.slfp\tFA.rh.slfp\tMD.rh.slfp\tRD.rh.slfp\tAD.rh.slft\tFA.rh.slft\tMD.rh.slft\tRD.rh.slft\tAD.rh.unc\tFA.rh.unc\tMD.rh.unc\tRD.rh.unc\tLeft-Lateral-Ventricle\tLeft-Inf-Lat-Vent\tLeft-Cerebellum-White-Matter\tLeft-Cerebellum-Cortex\tLeft-Thalamus-Proper\tLeft-Caudate\tLeft-Putamen\tLeft-Pallidum	3rd-Ventricle\t4th-Ventricle\tBrain-Stem\tLeft-Hippocampus\tLeft-Amygdala\tCSF\tLeft-Accumbens-area\tLeft-VentralDC\tLeft-vessel\tLeft-choroid-plexus\tRight-Lateral-Ventricle\tRight-Inf-Lat-Vent\tRight-Cerebellum-White-Matter\tRight-Cerebellum-Cortex\tRight-Thalamus-Proper\tRight-Caudate\tRight-Putamen\tRight-Pallidum\tRight-Hippocampus\tRight-Amygdala\tRight-Accumbens-area\tRight-VentralDC\tRight-vessel\tRight-choroid-plexus\t5th-Ventricle\tWM-hypointensities\tLeft-WM-hypointensities\tRight-WM-hypointensities\tnon-WM-hypointensities\tLeft-non-WM-hypointensities\tRight-non-WM-hypointensities\tOptic-Chiasm\tCC_Posterior\tCC_Mid_Posterior\tCC_Central\tCC_Mid_Anterior	CC_Anterior\tBrainSegVol\tBrainSegVolNotVent\tBrainSegVolNotVentSurf\tlhCortexVol\trhCortexVol\tCortexVol\tlhCorticalWhiteMatterVol\trhCorticalWhiteMatterVol\tCorticalWhiteMatterVol\tSubCortGrayVol\tTotalGrayVol\tSupraTentorialVol\tSupraTentorialVolNotVent\tSupraTentorialVolNotVentVox\tMaskVol\tBrainSegVol-to-eTIV\tMaskVol-to-eTIV\tlhSurfaceHoles\trhSurfaceHoles\tSurfaceHoles\tEstimatedTotalIntraCranialVol" >> $Study/$tracdir/tractography_output/database
fi

#Append stats to delimited database file
if [ -e $Study/$tracdir/tractography_output/$PARTIC/stats/ALLTRACTS_AND_GMSTATS_"$PARTIC" ]; then
    echo -en '\n'
    echo "Creating line for "$PARTIC"..."
    sed -n -e 's/^/\t/' -e 's/^/'"$PARTIC"'/' -e '2{p;q}' $Study/$tracdir/tractography_output/$PARTIC/stats/ALLTRACTS_AND_GMSTATS_"$PARTIC" >> $Study/$tracdir/tractography_output/database
    echo -en '\n'
    echo "Line created."
else
    echo -en '\n'
    echo ""$PARTIC" is missing ALLTRACTS data!"
fi

echo -en '\n'
echo "All complete."

echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -en '\n'

if [ $probtracking -eq "1" ]; then 
	for seed_mask in $Study/$tracdir/tractography_output/$PARTIC/ROIS/*.nii.gz; do
		mask_file=`basename "$seed_mask"`
		mask_name=${mask_file%.nii*}
		echo -e "Starting tracking for region: $mask_name..."
		fsl_sub probtrackx --mode=seedmask -x "$seed_mask" -l -c 0.2 -S 2000 --steplength=0.5 -P 5000 --forcedir --opd --pd -s $Study/$tracdir/tractography_output/$PARTIC/dmri.bedpostX/merged -m $Study/$tracdir/tractography_output/$PARTIC/dmri/nodif_brain_mask.nii.gz --omatrix3 --dir=$Study/$tracdir/tractography_output/$PARTIC/probtrackx --out=${mask_name}.nii.gz
	done

	cd $Study/$tracdir/tractography_output/$PARTIC/probtrackx
	fslmerge -t fdt.nii.gz `ls . | sort -h`
fi

cat $output_dir/$PARTIC/MOTION_OUTLIERS.txt

