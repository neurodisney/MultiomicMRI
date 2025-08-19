#!bin/bash

# flatmountFS.sh takes @animal_warper's output and performs a series of steps
# using freesurfer's powerful cortical mesh tools, including generating spheroid 
# and flatmap representations. Both are important for projection of
# -omic or other 2D data collected and based off the subject brain.

# As stated in flatmountPrep.sh, it is HIGHLY recommended to check @animal_warper output and perform manual
# tweaks to segmentation masks using ITK-SNAP. This has been mentioned by both by both C Klink and R Boshra. 
# It involves loading "main image" which is the brain mask for your subject, and loading the "segmentation" ("SEG") mask. 
# Set opacity levels so both can be seen well, and essentially enjoy some painting time, as there will be voxels that need
# be re-numbered according to what their actual values are. 

# IMPORTANT: There is a change in value categories generated between use of the original segmenting procedure shown by C. Klink, 
# which involved use of the NMT v1.2, and the NMT v2 procedure outlined here and by R. Boshra. NMT_v2 has two threshold values 
# which get categorized as WM, ranging from 3 to 4, rather than just 3 as w/ the original NMT v1.2. 
# In ITK-SNAP, you will notice some parts of the white matter are either a blue OR yellow color (values of 3 OR 4), respectively. 
# In the below lines, I utilize numbering outlined by R. Boshra since we have been using the NMT v2.
# SAVE THE MODIFIED VERSION AS A COPY! You'll see below I named mine "SEG_in_BONNIE_ITK.nii.gz" to specify the ITK-SNAP edit.


SUBJ=BONNIE #Subject name
startpath=$(pwd) # current working directory
Template=NMT_v2.0_sym_05mm # Variable specifying the template name (folder containing the template should also have this name. This is how it is downloaded from AFNI)
NMT_path=${startpath}/${Template} # NMT 0.5mm used in this project to avoid voxel resampling

#travel to directory holding the segmented "in subject" scans
cd ${NMT_path}/single_subject_scans/${SUBJ}/AW/

# On the copied segmentation file, create separate masks for each segmented category
# WM, GM, CSF, etc.
fslmaths SEG_in_${SUBJ}_ITK2.nii.gz -thr 0.9 -uthr 1.1 -bin ${SUBJ}_CSF.nii.gz # <<< note the "2" here. Moving forward this needs to be defined as a variable name. It's only a 2 in this case because I had to go back and do more edits. would be best to not have this issue.
fslmaths SEG_in_${SUBJ}_ITK2.nii.gz -thr 1.9 -uthr 2.1 -bin ${SUBJ}_GM.nii.gz
fslmaths SEG_in_${SUBJ}_ITK2.nii.gz -thr 2.9 -uthr 4.1 -bin ${SUBJ}_WM.nii.gz
fslmaths SEG_in_${SUBJ}_ITK2.nii.gz -thr 0.5 -uthr 4.1 -bin ${SUBJ}_brainmask.nii.gz

# create folder for freesurfer output
mkdir -p fsSurf 
# make subfolders for structure
mkdir -p fsSurf/src
mkdir -p fsSurf/mgz
mkdir -p fsSurf/temp

# copy source files from NMT segmentation to the new freesurfer folders
cp ${SUBJ}.nii.gz fsSurf/src/T1.nii.gz
cp ${SUBJ}_ns.nii.gz fsSurf/src/brain.nii.gz
cp ${SUBJ}_ns.nii.gz fsSurf/src/brainmask.nii.gz # freesurfer brainmask aren't actually masks
cp ${SUBJ}_WM.nii.gz fsSurf/src/wm.nii.gz

# make another directory that will be the "src" images but kept in an original state (headers will be changed to fake voxel dimensions).
mkdir fsSurf/src/org
cp fsSurf/src/*.nii.gz fsSurf/src/org/

# change headers for faking the 1mm voxel dimensions
3drefit -xdel 1.0 -ydel 1.0 -zdel 1.0 -keepcen fsSurf/src/T1.nii.gz
3drefit -xdel 1.0 -ydel 1.0 -zdel 1.0 -keepcen fsSurf/src/brain.nii.gz
3drefit -xdel 1.0 -ydel 1.0 -zdel 1.0 -keepcen fsSurf/src/brainmask.nii.gz
3drefit -xdel 1.0 -ydel 1.0 -zdel 1.0 -keepcen fsSurf/src/wm.nii.gz

#convert to .mgz format for freesurfer and place in the mgz folder
mri_convert -c fsSurf/src/T1.nii.gz fsSurf/mgz/T1.mgz
mri_convert -c fsSurf/src/brain.nii.gz fsSurf/mgz/brain.mgz
mri_convert -c fsSurf/src/brain.nii.gz fsSurf/mgz/brainmask.mgz
mri_convert -c fsSurf/src/brainmask.nii.gz fsSurf/mgz/brainmask_binary.mgz
mri_convert -c fsSurf/src/wm.nii.gz fsSurf/mgz/wm.mgz

# create brain.finalsurfs.mgz
mri_mask -T 5 fsSurf/mgz/brain.mgz fsSurf/mgz/brainmask.mgz fsSurf/mgz/brain.finalsurfs.mgz 

# Inspect volume, get coordinates for corpus callosum and pons
freeview -v fsSurf/mgz/brain.mgz &

echo "Inspect brain volume in Freeview and get coordinates for the corpus callosum (CC) and pons (PONS) to continue."
read -p "Enter CC coordinates as X Y Z (e.g., 127 104 134): " -a CC # Read user input into an array named CC
read -p "Enter PONS coordinates as X Y Z (e.g., 127 153 126): " -a PONS # Read user input into an array named PONS
read -p "Ready to continue? Press Enter to begin cortical surface generation" # Wait for user input

#Fill WM
mri_fill -CV ${CC[0]} ${CC[1]} ${CC[2]} \
    -PV ${PONS[0]} ${PONS[1]} ${PONS[2]} \
    fsSurf/mgz/wm.mgz fsSurf/mgz/filled.mgz

# copy original white matter before applying fixes
cp fsSurf/mgz/wm.mgz fsSurf/mgz/wm_nofix.mgz

# Tesselate
# left hemisphere
mri_pretess fsSurf/mgz/filled.mgz 255 fsSurf/mgz/brain.mgz fsSurf/mgz/wm_filled-pretess255.mgz
mri_tessellate fsSurf/mgz/wm_filled-pretess255.mgz 255 fsSurf/temp/lh.orig.nofix
# right hemisphere
mri_pretess fsSurf/mgz/filled.mgz 127 fsSurf/mgz/brain.mgz fsSurf/mgz/wm_filled-pretess127.mgz
mri_tessellate fsSurf/mgz/wm_filled-pretess127.mgz 127 fsSurf/temp/rh.orig.nofix

# Define hemispheres
HEMI=(lh rh) # Array containing left and right hemispheres

# for both hemispheres
for xh in ${HEMI[@]}; do
    # create a version we can edit
    cp fsSurf/temp/${xh}.orig.nofix fsSurf/temp/${xh}.orig

    # post-process tesselation
    mris_extract_main_component fsSurf/temp/${xh}.orig.nofix fsSurf/temp/${xh}.orig.nofix
    mris_smooth -nw fsSurf/temp/${xh}.orig.nofix fsSurf/temp/${xh}.smoothwm.nofix
    mris_inflate fsSurf/temp/${xh}.smoothwm.nofix fsSurf/temp/${xh}.inflated.nofix
    mris_sphere -q fsSurf/temp/${xh}.inflated.nofix fsSurf/temp/${xh}.qsphere.nofix
    cp fsSurf/temp/${xh}.inflated.nofix fsSurf/temp/${xh}.inflated

    # fix topology
    mris_euler_number fsSurf/temp/${xh}.orig
    mris_remove_intersection fsSurf/temp/${xh}.orig fsSurf/temp/${xh}.orig
    mris_smooth -nw fsSurf/temp/${xh}.orig fsSurf/temp/${xh}.smoothwm
    mris_inflate fsSurf/temp/${xh}.smoothwm fsSurf/temp/${xh}.inflated
done