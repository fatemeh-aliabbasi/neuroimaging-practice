# Pipeline Comparison: Reference (Tahedl et al.) vs Fatemeh's Implementation

Comparison between the reference pipeline (`SC-construction-using-MSMT-CSD/run_protocol.sh`) and Fatemeh's implementation (`scripts/dwi_pipeline.sh`).

## 1. Error Handling & Input Validation
- **Reference**: Has `set -e` (exit on error) and validates that input files exist before running.
- **Fatemeh**: Neither `set -e` nor any input validation. If a file is missing, the pipeline will fail mid-way with a less informative error.

## 2. Path Strategy
- **Reference**: Uses absolute paths via `$RAWDIR` / `$DERIVDIR` arguments — self-contained and Docker-friendly.
- **Fatemeh**: `cd`s into the subject derivatives directory and uses **relative paths** throughout. Also includes DICOM conversion inline (the reference keeps that in a separate script).

## 3. FreeSurfer Output Handling (Step 4)
- **Reference**: Copies FreeSurfer results into the derivatives folder (`cp -r ${SUBJECTS_DIR}/${SUBJECTID} ${DERIVDIR}/freesurfer`), making everything self-contained.
- **Fatemeh**: Leaves results in the default `$SUBJECTS_DIR`. Later steps (14, 17) reference `${SUBJECTS_DIR}/${SUBJECTID}` directly instead of a local copy.

## 4. Coregistration (Step 9) — The Biggest Difference

Fatemeh added **three extra steps** not in the reference:

| Extra Step | Command | Purpose |
|---|---|---|
| Orientation standardization | `fslreorient2std` on both mean_b0 and T1w_bc | Forces both images to standard (RAS) orientation |
| Voxel grid matching | `mrgrid mean_b0_std.nii.gz regrid -template T1w_bc_std.nii.gz` | Resamples the b0 to match the T1w voxel grid before `flirt` |
| Stride override | `-stride 0` flag on `mrtransform` | Forces output stride to match the input |

She also saves the mean b0 as `.nii.gz` first, then converts to `.nii` — the reference just writes `.nii` directly.

These additions suggest she hit coregistration issues (consistent with commit message `d296750 coregistration fix`).

## 5. File Naming Differences (Step 9)
- **Reference**: `diff2struct_fsl.mat`, `T1w_bc.nii`
- **Fatemeh**: `diff2struct.mat`, `T1w_bc.nii.gz` / `T1w_bc_std.nii.gz`, `mean_b0_match.nii.gz`

## 6. 5ttgen Input (Step 14)
- **Reference**: `5ttgen hsvs ${DERIVDIR}/freesurfer` — uses the copied FreeSurfer directory.
- **Fatemeh**: `5ttgen hsvs ${SUBJECTS_DIR}/${SUBJECTID}` — uses the original FreeSurfer `SUBJECTS_DIR`. This works but ties the pipeline to FreeSurfer's default location.

## 7. labelconvert Path (Step 17)
- **Reference**: `/opt/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt` (Docker path).
- **Fatemeh**: `/usr/local/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt` (local install path). She also computes `MRTRIXDIR` dynamically but then doesn't use it in the actual command — likely a leftover.

## 8. QC Script (`check.sh` vs `gen_supplementary.sh`)
- **Reference**: Fully automated script that generates output files (SNR maps, tract density images, AAL connectome, fibre bundles).
- **Fatemeh**: Mostly commented out, used interactively with `mrview` for visual QC. Missing the S12 AAL atlas connectome generation entirely. Only the fibre bundle segmentation (s13) is active.

## 9. What's Identical

Steps 5-8 (denoising, Gibbs unringing, motion/distortion correction, bias correction), steps 10-13 (mask, response functions, FOD estimation, normalization), and steps 15-16/18 (tractography, SIFT2, connectome matrix) are functionally identical — just different formatting and argument ordering.

## Summary

The pipelines follow the same protocol. The meaningful differences are:
- Fatemeh's extra coregistration preprocessing (orientation + regrid)
- No error handling
- FreeSurfer results not copied locally
- Hardcoded MRtrix3 path
- Incomplete QC script
