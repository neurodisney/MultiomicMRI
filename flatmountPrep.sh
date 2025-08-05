#!/bin/bash
set -euo pipefail # Exit on error, unset variable, or error in pipeline

# flatmountPrep.sh prepares multiple T1-weighted scans for cortical surface reconstruction 
# and flatmount generation in FreeSurfer. Toolkits from FSL, FreeSurfer, AFNI are all used and should be installed. 
# It is likely necessary  to check @animal_warper's output segmentation file 
# and perform manual adjustments using ITK-SNAP before proceeding to the flatmoutFS scripts.

# Usage: place this script in same directory as the subject's T1-weighted MRI folder, and the folder containing the NIH NMT v2.0 template. 

# Acknowledgements: This is an adaptation of instructions provided by
# Chris Klink, PhD, the Primate Resource Exchange (Prime-RE), and most recent 
# updates posted by Rober Boshra, PhD, for utilization of the NMT v2.
# https://github.com/VisionandCognition/NHP-Freesurfer.git
# https://github.com/boshra/NHP_freesurfer.git

# The prior instructions involve making individual subject directories within the 
# template directory, in this case, the NMT v2.0 sym 05mm. This script will 
# follow this architecture, with outputs ending up in a "single_subjects_scan" folder
# inside the template directory. << you will see reference to this at the bottom of this script.

# Before starting, there should be a folder in the starting directory
# titled with the same name as $SUBJ variable below, and containing a subfolder
# named 'T1s' that has the T1-weighted scans, **in NIFTI format**.
# If scans are still in DICOM, perform conversion in the T1s folder to NIFTI using AFNI's dcm2niix_afni command. 

# IT'S RECOMMENDED TO TAKE A COUPLE MOMENTS AND USE SOMETHING LIKE FSLEYES AT EACH OF 
# STEPS WITHIN THE USER INPUT SECTION BELOW TO SEE WHAT YOUR SCANS LOOK LIKE!

# Set up subject variables and paths; Enter subject name and directory name holding the template
SUBJ=BONNIE # Subject name
startpath=$(pwd) # Current working directory that holds the T1s folder
Template=NMT_v2.0_sym_05mm # Variable specifying the template name (folder containing the template should also have this name. This is how it is downloaded from AFNI)
NMT_path=${startpath}/${Template} # NMT 0.5mm used in this project to avoid voxel resampling
#####################BEGIN#####################
# ***NOTE: Scans should be practically identical, very tough to see any differences between. 
# This script was written with the assumption that all scans are roughly identical to begin with,
# so averaging will just provide better signal. If individual scans are much different, a manual registration
# or alignment process of the individual scans to each other may be necessary before averaging.


cd ${startpath}/${SUBJ}/T1s # change to T1s directory
numScans=$(find . -maxdepth 1 -type f -name "*.nii" | wc -l) # get number of scans
scans=(*.nii) # make list of scans

echo "Number of scans found: $numScans" # Optional: print number of scans found

fslmaths "${scans[0]}" temp_sum # make temp variable to compute on

#loop through additional scans and add
for ((i=1; i<numScans; i++)); do
    fslmaths temp_sum -add "${scans[i]}" temp_sum
done
#

fslmaths temp_sum -div ${numScans} ${SUBJ}_avg.nii.gz # divide by number of scans to get average
rm temp_sum.nii.gz # clean up temp file

######################USER INPUTS & USEFUL PRE-WARPING STEPS########################
# Following averaing, the user will check the image and get 
# coordintes that will roughly constraint the field of view (FOV) to that of the NMT. 
# The coordinates will then be used to crop the image similarly to what is seen in the NMT
# allowing for @animal_warper's processes to most effectively capture the subject brain.

echo "Averaging of T1s complete. Inspect Image to acquire coordinates/dimensions for cropping." # Prompt user to inspect the averaged image
echo "Use FSLeyes to obtain the minimum of each dimension value, and then calculate the length by subtracting the minimum from the max value that encompasses the brain." # Provide instructions for obtaining coordinates
read -p "Ready to continue? Enter cropping coordinates as: Xmin Xlength Ymin Ylength Zmin Zlength > " # Wait for user input
coords=($REPLY) # Read user input into an array
if [ "${#coords[@]}" -ne 6 ]; then
  echo "Error: You must enter exactly 6 coordinates."
  exit 1
fi

# crop image to similar FOV as that of the NMT or other template. Takes 'coords' variable
fslroi ${SUBJ}_avg.nii.gz ${SUBJ}_avg_crop.nii.gz ${coords[0]} ${coords[1]} ${coords[2]} ${coords[3]} ${coords[4]} ${coords[5]}
# Run basic intensity normalization to roughly match voxel intensity values of the NMT
fslmaths ${SUBJ}_avg_crop.nii.gz -inm 355 ${SUBJ}_avg_crop_norm.nii.gz # 355 is the mean intensity of the NMT v2.0 sym 05 template

echo "Image cropping and normalization done. Check FOV now if you'd like. Next step: @animal_warper." # Prompt user that cropping and normalization is complete
# provies an opportunity to check the cropped and normalized image.
read -p "Ready to continue? Press Enter to run @animal_warper. This will take a while." # Wait for user input

######################@ANIMAL_WARPER########################
# Run @animal_warper on cropped/normalized image. In this case, settings coded below 
# involve using the NMT v2.0 sym 05mm template, skull stripping according to the inverse warped NMT
# brain mask, atlas utilization of the CHARM level 5 (which is also within the NMT template direcoty), 
# and segmentation specified using the NMT v2.0 sym 05mm segmentation file. 
# It is important to include this segmentation as the grey/white matter masks will be used in freesurfer.
# first go back to the start path
cd ${startpath}
# make an animal warper output directory
mkdir -p "${NMT_path}/single_subject_scans/${SUBJ}/AW"
# run @animal_warper
@animal_warper \
    -input ${SUBJ}/T1s/${SUBJ}_avg_crop_norm.nii.gz \
    -base "${NMT_path}/${Template}.nii.gz" \
    -outdir "${NMT_path}"/single_subject_scans/${SUBJ}/AW/ \
    -skullstrip "${NMT_path}/${Template}_brainmask.nii.gz" \
    -atlas "${NMT_path}/supplemental_CHARM/CHARM_5_in_${Template}.nii.gz" \
    -seg_followers "${NMT_path}/${Template}_segmentation.nii.gz" \
    -input_abbrev ${SUBJ} \
    -base_abbrev NMT_v2 \
    -atlas_abbrevs CHARM5 \
    -seg_abbrevs SEG \
    -align_centers_meth cm
