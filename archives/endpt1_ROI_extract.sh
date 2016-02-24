#!/bin/bash
workingdir=$1
PARTIC=$2
tract=$3

fsl_sub -l /dev/null fslmaths $workingdir/$PARTIC/dpath/$tract/point_ROI_merged -kernel 2D -dilD -fmean $workingdir/$PARTIC/dpath/$tract/endpt1_ROI_merged -odt float

while [ ! -f $workingdir/$PARTIC/dpath/$tract/endpt1_ROI_merged.nii.gz ]; do
    sleep 20;
done

endpt1_fslroi_extractvol.sh $workingdir $PARTIC $tract
