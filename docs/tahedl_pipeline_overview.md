# Structural Connectome Construction Using MSMT-CSD — Pipeline Overview

Companion code for the paper **"Structural connectome construction using constrained spherical deconvolution in multi-shell diffusion-weighted magnetic resonance imaging"** by Tahedl, M., Tournier, J.-D., and Smith, R.E. (2024).

Provides a complete, reproducible pipeline (via Docker) to build a **structural connectome (SC)** — a brain connectivity matrix — from raw diffusion MRI (DWI) and T1-weighted MRI data.

## Repo Structure

| File | Purpose |
|---|---|
| `Dockerfile` | Builds a Docker image with all neuroimaging tools: **MRtrix3**, **FreeSurfer**, **FSL**, **ANTs**, **ACPCDetect**, and the AAL2 atlas. Also downloads example DICOM data from OSF. |
| `convert_example_dicoms.sh` | **Stage 1** — Converts example DICOM data into MRtrix `.mif` format (`dwi.mif`, `b0_pa.mif`, `T1w.mif`). |
| `run_protocol.sh` | **Stage 2** — The main pipeline (see below). |
| `gen_supplementary.sh` | **Stage 3** — Generates supplementary figures (SNR maps, tract density images, AAL-based connectome, fibre bundle segmentation). |

## Main Pipeline (`run_protocol.sh`) — Step by Step

1. **T1w conversion** — Convert T1w to NIfTI for FreeSurfer
2. **FreeSurfer `recon-all`** — Full cortical surface reconstruction and parcellation
3. **DWI denoising** (`dwidenoise`)
4. **Gibbs ringing removal** (`mrdegibbs`)
5. **Motion and distortion correction** (`dwifslpreproc` with reverse phase-encode b=0)
6. **Bias field correction** (`dwibiascorrect` using ANTs)
7. **Coregistration** — Registers DWI to T1w space using FSL `flirt` (6-DOF rigid)
8. **Brain mask estimation** (`dwi2mask`)
9. **Response function estimation** (`dwi2response dhollander`) — estimates WM/GM/CSF responses for multi-shell multi-tissue CSD
10. **FOD estimation** (`dwi2fod msmt_csd`) — multi-shell multi-tissue constrained spherical deconvolution
11. **FOD normalization** (`mtnormalise`)
12. **ACT tissue segmentation** (`5ttgen hsvs` from FreeSurfer)
13. **Whole-brain tractography** (`tckgen` iFOD2, 10 million streamlines with ACT)
14. **SIFT2 filtering** (`tcksift2`) — optimizes streamline weights to better match the FOD
15. **Parcellation conversion** — Maps FreeSurfer's Desikan-Killiany atlas to MRtrix format
16. **Connectome matrix** (`tck2connectome`) — produces the final symmetric structural connectivity matrix (`dk.csv`)

## Summary

Raw DWI + T1w DICOM → preprocessing → fibre orientation estimation (MSMT-CSD) → tractography → SIFT2 → **structural connectome matrix**.

This is a state-of-the-art pipeline for diffusion MRI connectomics, fully containerized for reproducibility.
