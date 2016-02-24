#! /bin/sh

/mnt/data1/MATLAB/R2014a/bin/matlab -nodesktop -nosplash -r "c = parcluster; j = c.batch(@Run_LPCA, 1, {'feddy_corrected_data.nii', 'bval'}, 'Pool', 23, 'AdditionalPaths', {'/usr/local/LPCA Denoising Software', '/usr/local/nifti_analyzer'}), exit"
