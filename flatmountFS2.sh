#!bin/bash

SUBJ=BONNIE #Subject name
startpath=$(pwd) # current working directory
Template=NMT_v2.0_sym_05mm # Variable specifying the template name (folder containing the template should also have this name. This is how it is downloaded from AFNI)
NMT_path=${startpath}/${Template} # NMT 0.5mm used in this project to avoid voxel resampling


#travel to directory holding the segmented "in subject" scans
cd ${NMT_path}/single_subject_scans/${SUBJ}/AW/

# Apply any fixes to WM
freeview -v fsSurf/mgz/brain.mgz -v fsSurf/mgz/wm.mgz \
-f fsSurf/temp/lh.smoothwm fsSurf/temp/lh.inflated fsSurf/temp/rh.smoothwm fsSurf/temp/rh.inflated &
# Note that the above may poptentially take some time depending on the level of fixes that need to be made
# Make sure to save the updated WM!
read -p "Ready to continue with collecting landmarks, updating tessellation, and surface generation? Press [Enter] key to continue..."


# Inspect volume, get coordinates for corpus callosum and pons
freeview -v fsSurf/mgz/brain.mgz &

echo "Inspect brain volume in Freeview and get coordinates for the corpus callosum (CC) and pons (PONS) to continue."
read -p "Enter CC coordinates as X Y Z (e.g., 127 104 134): " -a CC # Read user input into an array named CC
read -p "Enter PONS coordinates as X Y Z (e.g., 127 153 126): " -a PONS # Read user input into an array named PONS
read -p "Ready to continue? Press Enter to begin cortical surface generation" # Wait for user input

# redo the tessellation with the freshly fixed WM volume
mri_fill -CV ${CC[0]} ${CC[1]} ${CC[2]} \
    -PV ${PONS[0]} ${PONS[1]} ${PONS[2]} \
    fsSurf/mgz/wm.mgz fsSurf/mgz/filled.mgz

mri_pretess fsSurf/mgz/filled.mgz 255 fsSurf/mgz/brain.mgz fsSurf/mgz/wm_filled-pretess255.mgz
mri_tessellate fsSurf/mgz/wm_filled-pretess255.mgz 255 fsSurf/temp/lh.orig
mri_pretess fsSurf/mgz/filled.mgz 127 fsSurf/mgz/brain.mgz fsSurf/mgz/wm_filled-pretess127.mgz
mri_tessellate fsSurf/mgz/wm_filled-pretess127.mgz 127 fsSurf/temp/rh.orig

# Define hemispheres
HEMI=(lh rh) # Array containing left and right hemispheres

# for both hemispheres
for xh in ${HEMI[@]}; do

    mris_extract_main_component fsSurf/temp/${xh}.orig fsSurf/temp/${xh}.orig
    mris_smooth -nw fsSurf/temp/${xh}.orig fsSurf/temp/${xh}.smoothwm
    mris_inflate fsSurf/temp/${xh}.smoothwm fsSurf/temp/${xh}.inflated
    mris_sphere -q fsSurf/temp/${xh}.inflated fsSurf/temp/${xh}.qsphere

    mris_euler_number fsSurf/temp/${xh}.orig
    mris_remove_intersection fsSurf/temp/${xh}.orig fsSurf/temp/${xh}.orig
    mris_smooth -nw fsSurf/temp/${xh}.orig fsSurf/temp/${xh}.smoothwm
    mris_inflate fsSurf/temp/${xh}.smoothwm fsSurf/temp/${xh}.inflated
    mris_curvature -thresh .999 -n -a 5 -w -distances 10 10 fsSurf/temp/${xh}.inflated
done

# Look at the produced output again and check  if things are now looking clean.
freeview -v fsSurf/mgz/brain.mgz -v fsSurf/mgz/wm.mgz \
-f fsSurf/temp/lh.smoothwm fsSurf/temp/lh.inflated fsSurf/temp/rh.smoothwm fsSurf/temp/rh.inflated &


read -p "Ready to continue with creating the spherical surface? This will take a bit longer. Press [Enter] key to continue..."



# create the sphere (this takes longer so do it only when you're happy with the inflated)
for xh in ${HEMI[@]}; do
    mris_sphere fsSurf/temp/${xh}.inflated fsSurf/temp/${xh}.sphere &
done