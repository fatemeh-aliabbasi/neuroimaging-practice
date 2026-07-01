# =========================================================
# Structural connectome pipeline
# Based on Tahedl et al. (2025) Nature Protocols
# =========================================================

# Prepare input DICOM data
# =========================================================
# STEP 1 — Prepare folders structures
# =========================================================
# Organize raw DICOM files manually as:
#
# subject/
# └── dicoms/
#     ├── DWI_MSMT_102_AP/   # Multi-shell DWI
#     ├── DWI_b0_PA/         # Reverse PE b=0
#     └── T1w/               # T1-weighted scan
#
# =========================================================
# STEP 2 — Convert DICOMs to .mif format and filesystem path to location where DICOM data are stored
# =========================================================
# Subject ID for FreeSurfers
SUBJECTID="sub_03"
# Filesystem path to location where DICOM data are stored
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DICOMDIR="$PROJECT_DIR/subjects/$SUBJECTID/subject/dicoms"
DERIVATIVEDIR="$PROJECT_DIR/derivative"

SUBJDER="$DERIVATIVEDIR/$SUBJECTID"

# Convert DICOMs to MRtrix .mif format
mrconvert ${DICOMDIR}/DWI_MSMT_102_AP/ ${SUBJDER}/dwi.mif
mrconvert ${DICOMDIR}/DWI_b0_PA/ ${SUBJDER}/b0_pa.mif
mrconvert ${DICOMDIR}/T1w/ ${SUBJDER}/T1w.mif

#To make sure that FreeSurfer is installed and configured correctly
echo ${SUBJECTS_DIR}

# =========================================================
# STEP 3 — Convert T1w images into NIfTI format
# =========================================================
mrconvert T1w.mif T1w.nii

# =========================================================
#step 4 — Create the new FreeSurfer subject
# =========================================================
recon-all -s ${SUBJECTID} -i T1w.nii -all -openmp 4

# change directory
cd ${SUBJDER}

#preprocessing
# =========================================================
#step 5 — denoisning
# =========================================================
dwidenoise dwi.mif dwi_den.mif -noise noise.mif

# =========================================================
# step 6 — Gibbs ringing removal
# =========================================================
# Gibb's unringing of the main dMRI data set:
mrdegibbs dwi_den.mif dwi_den_unr.mif
# Gibb's unringing of the reversed phase-encoded b = 0 image:
mrdegibbs b0_pa.mif b0_pa_unr.mif

# =========================================================
# step 7 — Motion and distortion correction
# =========================================================
# A: Produce the image data to be used for susceptibility field estimation
dwiextract dwi_den_unr.mif -bzero - | \
mrconvert - -coord 3 0 - | \
mrcat - b0_pa_unr.mif -axis 3 b0s_paired.mif

# B: Perform image geometric distortion corrections by making use of these data
dwifslpreproc dwi_den_unr.mif \
dwi_den_unr_preproc.mif -pe_dir AP \
-rpe_pair -se_epi b0s_paired.mif \
-eddy_options " --repol"

# =========================================================
#step 8 — Bias field correction
# =========================================================
dwibiascorrect ants dwi_den_unr_preproc.mif \
dwi_den_unr_preproc_bc.mif -bias bias.mif

# =========================================================
#step 9 — Co-register the dMRI data to align with the T1-weighted data
# =========================================================
# Extract b=0 volumes and calculate the mean.
# Export to NIFTI format for compatibility with FSL.
dwiextract dwi_den_unr_preproc_bc.mif - -bzero | \
mrmath - mean mean_b0_preproc.nii.gz -axis 3 # I changed the file extension her to .gz
mrconvert mean_b0_preproc.nii.gz mean_b0_preproc.nii -force # I also create a just .nii
# Correct for bias field in the T1w image:
N4BiasFieldCorrection -d 3 -i T1w.nii -s 2 -o T1w_bc.nii.gz # I changed again the extension in .gz

# here a standardize orientation and match voxel grid (NEW)
fslreorient2std mean_b0_preproc.nii mean_b0_std.nii.gz
fslreorient2std T1w_bc.nii T1w_bc_std.nii.gz
mrgrid mean_b0_std.nii.gz regrid \
  -template T1w_bc_std.nii.gz \
  mean_b0_match.nii.gz -force

# Perform linear registration with 6 degrees of freedom:
flirt -in mean_b0_match.nii.gz \ 
-ref T1w_bc_std.nii.gz -dof 6 -cost normmi \
-omat diff2struct.mat # I have changed file extensions and did some renaming to use the new files
# Convert the resulting linear transformation matrix
# from FSL to MRtrix format:
transformconvert diff2struct.mat \
  mean_b0_match.nii.gz T1w_bc_std.nii.gz \
  flirt_import diff2struct_mrtrix.txt -force #also some renaming here to use the new files
# Apply linear transformation to header of
# diffusion-weighted image:
mrtransform dwi_den_unr_preproc_bc.mif \
  -linear diff2struct_mrtrix.txt \
  -stride 0 \
  dwi_den_unr_preproc_bc_coreg.mif -force


# =========================================================
#step 10 — Brain mask estimation
# =========================================================
dwi2mask dwi_den_unr_preproc_bc_coreg.mif dwi_mask.mif

# =========================================================
#step 11 — FOD etimation for WM, GM, and CSF
# =========================================================
dwi2response dhollander \
dwi_den_unr_preproc_bc_coreg.mif \
wm.txt gm.txt csf.txt -voxels voxels.mif

# =========================================================
#step 12 — Estimation of ODFs
# =========================================================
dwi2fod msmt_csd \
dwi_den_unr_preproc_bc_coreg.mif -mask dwi_mask.mif \
wm.txt wmfod.mif gm.txt gm.mif csf.txt csf.mif

# =========================================================
#step 13 — Bias field correction and intensity normalization
# =========================================================
mtnormalise wmfod.mif wmfod_norm.mif \
gm.mif gm_norm.mif csf.mif csf_norm.mif \
-mask dwi_mask.mif \
-check_factors check_factors.txt \
-check_norm check_norm.mif \
-check_mask check_mask.mif

#Creating a whole-brain tractogram
# =========================================================
#step 14 — Creation of a tissue segmentation image for ACT
# =========================================================
# Input to the command is the FreeSurfer subject directory.
# If FreeSurfer has been set up correctly, environment variable
# SUBJECTS_DIR is set during FreeSurfer configuration.
# Environment variable SUBJECTID was set in step 2.
5ttgen hsvs ${SUBJECTS_DIR}/${SUBJECTID} 5tt.mif

# =========================================================
#step 15 — Generation of streamlines
# =========================================================
tckgen -algorithm ifod2 \
-act 5tt.mif -backtrack -seed_dynamic wmfod_norm.mif \
-select 10m wmfod_norm.mif tracks_10m.tck

# Global optimization of the tractograms
# =========================================================
#step 16 — Filtering Tractograms with SIFT2
# =========================================================
tcksift2 -act 5tt.mif \
tracks_10m.tck wmfod_norm.mif \
sift2_weights.txt -out_mu sift2_mu.txt


# Generating the structural connectivity matrix
# =========================================================
#step 17 — Conversion of the parcellation image in preparation for connectome construction
# Identify MRtrix installation folder:
MRTRIXDIR=$(dirname $(dirname $(which labelconvert)))
# Run label conversion using FreeSurfer lookup table and
# associated conversion table in MRtrix installation folder:
labelconvert ${SUBJECTS_DIR}/${SUBJECTID}/mri/aparc+aseg.mgz \
${FREESURFER_HOME}/FreeSurferColorLUT.txt \
/usr/local/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt \
DK_parcels.mif

# =========================================================
#step 18 — Matrix generation 
# =========================================================
tck2connectome -tck_weights_in sift2_weights.txt \
-symmetric -zero_diagonal \
-out_assignments dk_assignments.txt \
tracks_10m.tck DK_parcels.mif dk.csv