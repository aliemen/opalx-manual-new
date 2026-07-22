# BeamBeam Static Gaussian 1 V/m Reproducer

This directory contains the files needed to reproduce the BeamBeam static
Gaussian-pair validation shown in the OPALX physics manual.

Assumptions:

- OPALX has been cloned and built.
- The OPALX executable is available at `build_openmp/src/opalx` relative to the
  OPALX repository root, or you replace that path in the command below.
- The Python environment has `numpy`, `pandas`, and `matplotlib`.

From the OPALX repository root:

```bash
REPRO=~/git/physics-manual-opalx/sections/beam-beam/reproducers
IN=sandbox/BeamBeam-static-1V.in

mkdir -p sandbox data/sandbox
cp "$REPRO/BeamBeam-static-1V.in" "$IN"
mpiexec -n 1 build_openmp/src/opalx --info 1 "$IN"
```

The run writes the active BeamBeam field diagnostics to `data/sandbox/`. The
comparison in the manual uses these three files:

```text
data/sandbox/BeamBeam-static-1V-RHO_scalar-beambeam_rho_pre-000003.dat
data/sandbox/BeamBeam-static-1V-PHI_scalar-beambeam_phi-000004.dat
data/sandbox/BeamBeam-static-1V-EF_vector-beambeam_e-000004.dat
```

Run the analytic comparison:

```bash
REPRO=~/git/physics-manual-opalx/sections/beam-beam/reproducers
D=data/sandbox
SCRIPT="$REPRO/beam-beam-manufactured-solution.py"
RHO="$D/BeamBeam-static-1V-RHO_scalar-beambeam_rho_pre-000003.dat"
PHI="$D/BeamBeam-static-1V-PHI_scalar-beambeam_phi-000004.dat"
EF="$D/BeamBeam-static-1V-EF_vector-beambeam_e-000004.dat"

python "$SCRIPT" \
  --compare-rho-dump "$RHO" \
  --compare-phi-dump "$PHI" \
  --compare-e-dump "$EF" \
  --sigma 1e-3
```

The expected summary is approximately:

```text
charge per bunch: -1.112650e-14 C
center1 z: 7.49479585743e-03 m
center2 z: 1.73879263892e-02 m
rho relL2: 5.221859e-02
phi relL2: 3.042248e-03
Ex relL2: 1.503024e-02
Ey relL2: 1.582187e-02
Ez relL2: 2.427369e-02
Ez(nearest grid sample to IP): analytic=1.038298e+00, OPALX=1.072345e+00 V/m
```

Small changes in OPALX stepping, mesh conventions, random-number generation,
or diagnostic formatting can change the exact dump suffixes or the last digits
of the error norms. The physically relevant checks are the few-percent
agreement of the grid field with the analytic Gaussian pair and the near-zero
interpolated field at the mathematical IP.
