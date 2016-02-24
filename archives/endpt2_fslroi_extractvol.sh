#!/bin/bash
workingdir=$1
PARTIC=$2
tract=$3

fsl_sub -l /dev/null fslroi $workingdir/$PARTIC/dpath/$tract/endpt2_ROI_merged.nii $workingdir/$PARTIC/dpath/$tract/endpt2_ROI_merged_sing.nii.gz 0 1
while [ ! -f $workingdir/$PARTIC/dpath/$tract/endpt2_ROI_merged_sing.nii.gz ]; do
    sleep 20;
done
fslmaths $workingdir/$PARTIC/dpath/$tract/endpt2_ROI_merged_sing.nii.gz -bin $workingdir/$PARTIC/dpath/$tract/endpt2_ROI_merged_sing.nii.gz
gzip -d -f $workingdir/$PARTIC/dpath/$tract/endpt2_ROI_merged_sing.nii.gz &
