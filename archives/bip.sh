#!/bin/sh
 
# Define paths and variables
source subject_profile.sh
 
: <<COMMENTBLOCK
 
###############################################################################
AUTHOR:         Dianne Patterson University of Arizona 
DATE CREATED:   April 16, 2009, revised 6/29/12. 
----------------------------  DEPENDENCIES  -----------------------------------
The script is dependent on 'profiles' found in /usr/local/tools/REF/PROFILES.
(e.g., img_profile.sh, subject_profile.sh and project specific profiles). The
profiles define variable names . All project specific profiles source
subject_profile.sh which sources img_profile.sh
===============================================================================
----------------------------  PURPOSE  ----------------------------------------
General purpose probability tracking for constrained tracts using an iterative
parcellation technique. What I do is the track back and forth between the 2
seeds creating a classification mask each time.The classification masks thus 
created get smaller and smaller, thus converging on the optimized mask. This 
calls bip_sub to do a lot of the work. 
Major mods 2/2011
===============================================================================
----------------------------  INPUT  ------------------------------------------
One tract name, e.g., arc5_l. 
It is assumed that the correct infrastructure of lists, images and directories 
already exists, because bip_prep.sh must have already been run.
 
===============================================================================
----------------------------  OUTPUT  -----------------------------------------
A set of iterations (these can take a couple of days depending on the tract),
and a log of endpoint values at each iteration.  The final rois should be the
bip output.
 
###############################################################################
 
COMMENTBLOCK
###############################################################################
#########################  DEFINE FUNCTIONS  ##################################
 
: <<COMMENTBLOCK
 
Function:   BipSub
Purpose:    Do the heavy lifting of running probtrackx
Input:          <tract> <seed> <target> <output suffix for new seed roi>
                E.g.: $0 arc_l arc_l_bip/roi_A_1 arc_l_bip/roi_B_1 A_2
Output:     an iteration
 
COMMENTBLOCK
               
function BipSub
{
 
#tract=$1
seed=$2
target=$3
out=$4
 
echo "seed is ${seed}"
echo "target is ${target}"
pwd
 
touch ${tract_dir}/targets.txt
echo "${target}" > ${tract_dir}/targets.txt
echo "BipSub thinks bedpost dir is ${BEDPOST}"
probtrackx --network --mode=seedmask -x ${seed}  -l -c 0.2 -S 2000 \
--steplength=0.5 -P 5000 --stop=${inv} --forcedir -f --opd \
-s ${BEDPOST}/merged -m ${BEDPOST}/nodif_brain_mask --dir=${tract_dir} \
--targetmasks=${tract_dir}/targets.txt --os2t
 
echo "size of old seed mask is"
fslstats ${seed} -V
echo "size of new seed mask is"
fslstats ${tract_dir}/seeds* -V
 
mkdir ${tract_dir}/Iteration_${out}
immv ${tract_dir}/fdt_paths ${tract_dir}/Iteration_${out}
mv ${tract_dir}/targets.txt ${tract_dir}/Iteration_${out}
mv ${tract_dir}/*.log ${tract_dir}/Iteration_${out}
mv ${tract_dir}/waytotal ${tract_dir}/Iteration_${out}
cp ${tract_dir}/seeds* ${tract_dir}/Iteration_${out}
immv ${tract_dir}/seeds* ${tract_dir}/roi_${out}
fslmaths ${tract_dir}/roi_${out} -bin ${tract_dir}/roi_${out}
}
  
#==============================================================================
: <<COMMENTBLOCK
 
Function:   DefVars
Purpose:    Define variables we'll need to reference
Input:      tract name, e.g., arc5_l
Output:     Variable names
 
COMMENTBLOCK
               
function DefVars
{
tract=$1
tract_dir=${DTI}/${tract}_bip
 
if [ ! -d ${tract_dir} ]
then
    echo "directory does not exist"
    echo "Please run bip_prep.sh"
    exit 1
fi
 
roi1=`head -n 1 ${tract_dir}/masks.txt`
roi2=`tail -n 1 ${tract_dir}/masks.txt`
inv=${SUBROIS}/${tract}_inv_mask_diff_bin_csf
 
pwd
volA=`fslstats ${SUBROIS}/${roi1} -V` 
volB=`fslstats ${SUBROIS}/${roi2} -V` 
echo "${roi1} is the A series, size ${volA}" >> ${tract_dir}/biplog_${tract}.txt
echo "${roi2} is the B series, size ${volB}" >> ${tract_dir}/biplog_${tract}.txt
 
echo "tract is ${tract}"
}
  
#==============================================================================
 
: <<COMMENTBLOCK
 
Function:   GetVols
Purpose:    Get volumes for comparisons and logs
Input:      Masks
Output:     Variables volA volAA volB volBB
 
COMMENTBLOCK
               
function GetVols
{
    volA=`fslstats ${tract_dir}/roi_A_${i} -V | cut -d " " -f 1`
    #echo "$volA"
    volAA=`fslstats ${tract_dir}/roi_A_${j} -V | cut -d " " -f 1`
    #echo "$volAA"
    volB=`fslstats ${tract_dir}/roi_B_${i} -V | cut -d " " -f 1`
    #echo "$volB"
    volBB=`fslstats ${tract_dir}/roi_B_${j} -V | cut -d " " -f 1`
    #echo "$volAA"
}
 
#==============================================================================
: <<COMMENTBLOCK
 
Function:   HelpMessage
Purpose:    Display help if user enters fewer thn one argument
Input:      None
Output:     Help Message
 
COMMENTBLOCK
               
function HelpMessage
{
    echo "Usage: $0 <tract>"
    echo "Example: $0 cst_l"
    exit 1 
}
         
#==============================================================================
: <<COMMENTBLOCK
 
Function:   Iterate
Purpose:    Run probtrack iteratively until endpoint size stabilizes
Input:      Directory with initial iterations done
Output:     Finished dir and images
 
COMMENTBLOCK
               
function Iterate
{
    echo "I should now have roi_A_1 and roi_B_1 in the directory"
    echo "now begins an iterating pattern."
    i=1
    j=2
     
    echo "run first bip round"
    BipSub ${tract} ${tract_dir}/roi_A_${i} ${tract_dir}/roi_B_${i} A_${j}
     
    echo "run 2nd fip round"
    BipSub ${tract} ${tract_dir}/roi_B_${i} ${tract_dir}/roi_A_${j} B_${j}
     
    GetVols
    echo "increment i and j"
    let i+=1
    echo "i is ${i}"
    let j+=1
    echo "j is ${j}"
     
    while [ $volA !=  $volAA -o  $volB !=  $volBB ] 
    do
     
        echo "run first BipSub round in loop"
        if [ $volA !=  $volAA ]
        then
            BipSub ${tract} ${tract_dir}/roi_A_${i} ${tract_dir}/roi_B_${i} A_${j}
        elif [ $volA =  $volAA ]
        then
            imcp ${tract_dir}/roi_A_${i} ${tract_dir}/roi_A_${j}
        fi
         
        echo "run 2nd BipSub round in loop"
        if [ $volB !=  $volBB ]
        then
            BipSub ${tract} ${tract_dir}/roi_B_${i} ${tract_dir}/roi_A_${j} B_${j}
        elif [ $volB =  $volBB ]
        then
            imcp ${tract_dir}/roi_B_${i} ${tract_dir}/roi_B_${j}
        fi
         
        GetVols       
        Stats
         
        echo "increment i and j"
        let i+=1
        echo "i is ${i}"
        let j+=1
        echo "j is ${j}"
    done
     
}
     
#==============================================================================
: <<COMMENTBLOCK
 
Function:   Stats
Purpose:    Log volumes
Input:      Masks to be measured
Output:     log file entries
 
COMMENTBLOCK
               
function Stats
{
#         echo "roi_A_${i} is ${volA}" 
#         echo "roi_A_${j} is ${volAA}" 
#         echo "roi_B_${i} is ${volB}" 
#         echo "roi_B_${j} is ${volBB}" 
         
        echo "put stats values in log in loop"
        echo "roi_A_${i} is ${volA}" >> ${tract_dir}/biplog_${tract}.txt
        echo "roi_A_${j} is ${volAA}" >> ${tract_dir}/biplog_${tract}.txt
        echo "roi_B_${i} is ${volB}" >> ${tract_dir}/biplog_${tract}.txt
        echo "roi_B_${j} is ${volBB}" >> ${tract_dir}/biplog_${tract}.txt    
}
        
#==============================================================================
: <<COMMENTBLOCK
 
Function:   Main
Purpose:    Run bidirectional iterative parcellation, (if it has not already been started)
Input:      tract, e.g., arc5_l 
Output:     We'll see
 
COMMENTBLOCK
               
function Main
{
    tract=$1
    tract_dir=${DTI}/${tract}_bip
    if [ -e ${tract_dir}/biplog_${tract}.txt ]; then
        echo "whoops, this is done or underway.  quitting."
        exit 1
        else 
            DefVars ${tract}
            BipSub ${tract} ${SUBROIS}/${roi1} ${SUBROIS}/${roi2} A_1
            cp ${tract_dir}/masks.txt ${tract_dir}/Iteration_A_1
            BipSub ${tract} ${SUBROIS}/${roi2} ${tract_dir}/roi_A_1 B_1
            mv ${tract_dir}/masks.txt ${tract_dir}/Iteration_B_1
            Iterate
    fi
}
     
#########################  END FUNCTION DEFINITIONS  ##########################
###############################################################################
 
if [ $# -lt 1 ]
    then
        HelpMessage
        exit 1
fi
   
Main $1
