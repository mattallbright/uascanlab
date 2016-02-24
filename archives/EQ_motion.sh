#!/bin/sh

############
filename='/home/scanlab/Desktop/Derek/EQ_list_motion.txt'
filelines=`cat $filename`

echo "Start"
echo -en '\n'
echo -en '\n'
for PARTIC in $filelines; do
	cd /data2/emot/dti_72_denoised/$PARTIC/	
	if [ ! -f ./Data1_eddy.nii.gz ]; then
		mv ./Data1_eddy_cor.nii.gz ./Data1_eddy.nii.gz
	fi
	ec_plot.sh Data1_eddy.ecclog
done	
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo "Done $PARTIC"
echo -en '\n'
echo -en '\n'
echo -en '\n'

done
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo -en '\n'
echo "Finish"
