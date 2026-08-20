#!/bin/bash
# this script is used to check the quality of the images
# to check the visualisation steps in a manual terminal navigate into the qc folder of the subject and define SUBJDER (once per terminal session). for example: cd /Users/au813606/Documents/DWI_Project/qc/sub_07
#SUBJDER="/Users/au813606/Documents/DWI_Project/derivative/sub_07" then you can paste below visualisation commands.
SUBJECTID="sub_07"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SUBJDER="$PROJECT_DIR/derivative/$SUBJECTID"
QCDIR="$PROJECT_DIR/qc/$SUBJECTID"
mkdir -p "$QCDIR"
cd "$SUBJDER"
#s1 SNR assessment
dwiextract -bzero dwi.mif "$QCDIR"/b0s.mif
mrmath "$QCDIR"/b0s.mif -axis 3 mean "$QCDIR"/mean_b0.mif
mrmath "$QCDIR"/b0s.mif -axis 3 std  "$QCDIR"/std_b0.mif
mrcalc "$QCDIR"/mean_b0.mif "$QCDIR"/std_b0.mif -div - | \
mrfilter - median "$QCDIR"/SNR.mif

#visualisation
#mrview SNR.mif -colourmap 2 -intensity_range 0,40 \
 #-noannotations -mode 2

 #s2 Visual inspection of denoising. this file is inside the derivative because it has been made in the actual pipeline
 #mrview "$SUBJDER"/noise.mif

 #s3 Visual inspection of bias field correction
mrcalc bias.mif -log "$QCDIR"/bias_log.mif
#visualisation
#mrview "$SUBJDER"/dwi_den_unr_preproc.mif \
  #-overlay.load bias_log.mif \
  #-overlay.colourmap 3 -colourbar 1 \
  #-overlay.opacity 0.6 -overlay.intensity -0.3,0.3


 #s4 Visual inspection of dMRI-T1w co-registration
 #mrview "$SUBJDER"/T1w.mif -colourmap 2 \
  #-overlay.load "$SUBJDER"/dwi_den_unr_preproc_bc.mif \
  #-overlay.colourmap 1 -overlay.opacity 0.6
 
# After co-registration
mrview "$SUBJDER"/T1w.mif -colourmap 2 \
  -overlay.load "$SUBJDER"/dwi_den_unr_preproc_bc_coreg.mif \
  -overlay.colourmap 1 -overlay.opacity 0.6

 #s5 Visual inspection of brain mask estimation
 #mrview "$SUBJDER"/dwi_den_unr_preproc_bc_coreg.mif \
  #3-roi.load "$SUBJDER"/dwi_mask.mif \
  #-overlay.opacity 0.6

 #s6 Visual inspection of the voxels selected for response function estimation
 #mrview "$SUBJDER"/T1w.mif \
  #-overlay.load "$SUBJDER"/voxels.mif \
  #-mode 2 -overlay.interpolation 0

 #s7 Using shview for visual inspection of response functions
 #viewing the RF for WM, GM, and CSF
#shview "$SUBJDER"/wm.txt
#shview "$SUBJDER"/gm.txt
#shview "$SUBJDER"/csf.txt

 #s8 Visual inspection of multi-tissue decomposition and fibre orientation
mrconvert -coord 3 0 wmfod.mif - | \
mrcat csf.mif gm.mif - "$QCDIR"/mtd.mif -axis 3
#mrview mtd.mif \
  #-odf.load_sh "$SUBJDER"/wmfod.mif

#s9 Visual inspection of the 5TT image
#mrview 5tt.mif
5tt2vis 5tt.mif "$QCDIR"/5tt_vis.mif
#mrview "$SUBJDER"/5tt.mif
#mrview 5tt_vis.mif -mode 2

#s10 Visual inspection of the generated tractogram
#writing 200,000 streamlines into a new file
tckedit tracks_10m.tck -number 200k "$QCDIR"/tracks_200k.tck

#visualisation of 3D view of this subset
#mrview "$SUBJDER"/dwi_den_unr_preproc_bc_coreg.mif \
  #-mode 3 -imagevisible 0 \
  #-tractography.load tracks_200k.tck

 #making sure that ACT is working properly
 # creating endpoints_200k.tck which contains only the start and end points
 tckresample -endpoints \
 "$QCDIR"/tracks_200k.tck \
 "$QCDIR"/endpoints_200k.tck

 #Visualisation of streamline termination
 #mrview "$SUBJDER"/T1w_bc.nii.gz \
  #-tractography.load tracks_200k.tck
 
 #visualisation of streamline endpoints
 #mrview "$SUBJDER"/T1w_bc.nii.gz \
  #-tractography.load endpoints_200k.tck

 #s11  Visual inspection of streamline filtering
tckmap -precise tracks_10m.tck \
 -template mean_b0_preproc.nii "$QCDIR"/tck_density_nofiltering.mif
tckmap -precise -tck_weights_in sift2_weights.txt \
 tracks_10m.tck -template mean_b0_preproc.nii \
 "$QCDIR"/tck_density_filtering.mif

 #visualisation
#mrview tck_density_nofiltering.mif
#mrview tck_density_filtering.mif
#mrview "$SUBJDER"/wmfod_norm.mif 

#s13 Fibre bundle segmentation ( as an example the paper uses node 23 and node 72 which are correspond to left and right precentral gyrus )
connectome2tck \
 tracks_10m.tck dk_assignments.txt \
 "$QCDIR"/transcallosal_m1.tck \
 -nodes 23,72 -exclusive -files single
#mrview "$SUBJDER"/T1w.mif \
  #tractography.load transcallosal_m1.tck