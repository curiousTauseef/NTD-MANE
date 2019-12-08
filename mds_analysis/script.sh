#!/bin/baash

# Get input
gromMDS() {
f=$1                 # input file
fe="$(echo ${f##*.})"   # file extension

if [[ $# != 1 ]]; then
   echo """
   Usage: gromMDS <pdb-file>
   """
elif [[ $# == 1 && $fe != "pdb" ]]; then
   echo "The input file is not a PDB file! Your file must end with .pdb"

else

# Initialize pbd input & output/intermediate filenames
fb="${f/.pdb/}" # input base
fc="${f/.pdb/_clean.pdb}" # clean file - water removed
fp="${f/.pdb/_processed.gro}" # processed clean file
fn="${f/.pdb/_newbox.gro}" # box file
fs="${f/.pdb/_solv.gro}" # solvated file
fsi="${f/.pdb/_solv_ions.gro}" # solvated file with ions added
Epe="${f/.pdb/_potential.xvg}"; Epet="${Epe/.xvg/.txt}" # poten ener out files
Et="${f/.pdb/_temperature.xvg}"; Ett="${Et/.xvg/.txt}" # temp out files
Epr="${f/.pdb/_pressure.xvg}"; Eprt="${Epr/.xvg/.txt}" # press out files
Ed="${f/.pdb/_density.xvg}"; Edt="${Ed/.xvg/.txt}" # density out files
cpt="$fb.cpt" # checkpoint file

# Functions for generating parameter files
writeIonMdp() {
	echo """
; ions.mdp - used as input into grompp to generate ions.tpr
; Parameters describing what to do, when to stop and what to save
integrator  = steep         ; Algorithm (steep = steepest descent minimization)
emtol       = 1000.0        ; Stop minimization when the maximum force < 1000.0 kJ/mol/nm
emstep      = 0.01          ; Minimization step size
nsteps      = 50000         ; Maximum number of (minimization) steps to perform

; Parameters describing how to find the neighbors of each atom and how to calculate the interactions
nstlist         = 1         ; Frequency to update the neighbor list and long range forces
cutoff-scheme	= Verlet    ; Buffered neighbor searching
ns_type         = grid      ; Method to determine neighbor list (simple, grid)
coulombtype     = cutoff    ; Treatment of long range electrostatic interactions
rcoulomb        = 1.0       ; Short-range electrostatic cut-off
rvdw            = 1.0       ; Short-range Van der Waals cut-off
pbc             = xyz       ; Periodic Boundary Conditions in all 3 dimensions
	"""
}

writeMinimMdp() {
	echo """
; minim.mdp - used as input into grompp to generate em.tpr
; Parameters describing what to do, when to stop and what to save
integrator  = steep         ; Algorithm (steep = steepest descent minimization)
emtol       = 1000.0        ; Stop minimization when the maximum force < 1000.0 kJ/mol/nm
emstep      = 0.01          ; Minimization step size
nsteps      = 50000         ; Maximum number of (minimization) steps to perform

; Parameters describing how to find the neighbors of each atom and how to calculate the interactions
nstlist         = 1         ; Frequency to update the neighbor list and long range forces
cutoff-scheme   = Verlet    ; Buffered neighbor searching
ns_type         = grid      ; Method to determine neighbor list (simple, grid)
coulombtype     = PME       ; Treatment of long range electrostatic interactions
rcoulomb        = 1.0       ; Short-range electrostatic cut-off
rvdw            = 1.0       ; Short-range Van der Waals cut-off
pbc             = xyz       ; Periodic Boundary Conditions in all 3 dimensions
	"""
}

writeNvtMdp() {
echo -e """
title                   = OPLS $fb NVT equilibration
define                  = -DPOSRES  ; position restrain the protein
; Run parameters
integrator              = md        ; leap-frog integrator
nsteps                  = 50000     ; 2 * 50000 = 100 ps
dt                      = 0.002     ; 2 fs
; Output control
nstxout                 = 500       ; save coordinates every 1.0 ps
nstvout                 = 500       ; save velocities every 1.0 ps
nstenergy               = 500       ; save energies every 1.0 ps
nstlog                  = 500       ; update log file every 1.0 ps
; Bond parameters
continuation            = no        ; first dynamics run
constraint_algorithm    = lincs     ; holonomic constraints
constraints             = h-bonds   ; bonds involving H are constrained
lincs_iter              = 1         ; accuracy of LINCS
lincs_order             = 4         ; also related to accuracy
; Nonbonded settings
cutoff-scheme           = Verlet    ; Buffered neighbor searching
ns_type                 = grid      ; search neighboring grid cells
nstlist                 = 10        ; 20 fs, largely irrelevant with Verlet
rcoulomb                = 1.0       ; short-range electrostatic cutoff (in nm)
rvdw                    = 1.0       ; short-range van der Waals cutoff (in nm)
DispCorr                = EnerPres  ; account for cut-off vdW scheme
; Electrostatics
coulombtype             = PME       ; Particle Mesh Ewald for long-range electrostatics
pme_order               = 4         ; cubic interpolation
fourierspacing          = 0.16      ; grid spacing for FFT
; Temperature coupling is on
tcoupl                  = V-rescale             ; modified Berendsen thermostat
tc-grps                 = Protein Non-Protein   ; two coupling groups - more accurate
tau_t                   = 0.1     0.1           ; time constant, in ps
ref_t                   = 300     300           ; reference temperature, one for each group, in K
; Pressure coupling is off
pcoupl                  = no        ; no pressure coupling in NVT
; Periodic boundary conditions
pbc                     = xyz       ; 3-D PBC
; Velocity generation
gen_vel                 = yes       ; assign velocities from Maxwell distribution
gen_temp                = 300       ; temperature for Maxwell distribution
gen_seed                = -1        ; generate a random seed
	"""
}

writeNptMdp() {
	echo -e """
title                   = OPLS $fb NPT equilibration
define                  = -DPOSRES  ; position restrain the protein
; Run parameters
integrator              = md        ; leap-frog integrator
nsteps                  = 50000     ; 2 * 50000 = 100 ps
dt                      = 0.002     ; 2 fs
; Output control
nstxout                 = 500       ; save coordinates every 1.0 ps
nstvout                 = 500       ; save velocities every 1.0 ps
nstenergy               = 500       ; save energies every 1.0 ps
nstlog                  = 500       ; update log file every 1.0 ps
; Bond parameters
continuation            = yes       ; Restarting after NVT
constraint_algorithm    = lincs     ; holonomic constraints
constraints             = h-bonds   ; bonds involving H are constrained
lincs_iter              = 1         ; accuracy of LINCS
lincs_order             = 4         ; also related to accuracy
; Nonbonded settings
cutoff-scheme           = Verlet    ; Buffered neighbor searching
ns_type                 = grid      ; search neighboring grid cells
nstlist                 = 10        ; 20 fs, largely irrelevant with Verlet scheme
rcoulomb                = 1.0       ; short-range electrostatic cutoff (in nm)
rvdw                    = 1.0       ; short-range van der Waals cutoff (in nm)
DispCorr                = EnerPres  ; account for cut-off vdW scheme
; Electrostatics
coulombtype             = PME       ; Particle Mesh Ewald for long-range electrostatics
pme_order               = 4         ; cubic interpolation
fourierspacing          = 0.16      ; grid spacing for FFT
; Temperature coupling is on
tcoupl                  = V-rescale             ; modified Berendsen thermostat
tc-grps                 = Protein Non-Protein   ; two coupling groups - more accurate
tau_t                   = 0.1     0.1           ; time constant, in ps
ref_t                   = 300     300           ; reference temperature, one for each group, in K
; Pressure coupling is on
pcoupl                  = Parrinello-Rahman     ; Pressure coupling on in NPT
pcoupltype              = isotropic             ; uniform scaling of box vectors
tau_p                   = 2.0                   ; time constant, in ps
ref_p                   = 1.0                   ; reference pressure, in bar
compressibility         = 4.5e-5                ; isothermal compressibility of water, bar^-1
refcoord_scaling        = com
; Periodic boundary conditions
pbc                     = xyz       ; 3-D PBC
; Velocity generation
gen_vel                 = no        ; Velocity generation is off
	"""
}

writeMdMdp() {
	echo -e """
title                   = OPLS $fb NPT equilibration
; Run parameters
integrator              = md        ; leap-frog integrator
nsteps                  = 500000    ; 2 * 500000 = 1000 ps (1 ns)
dt                      = 0.002     ; 2 fs
; Output control
nstxout                 = 0         ; suppress bulky .trr file by specifying
nstvout                 = 0         ; 0 for output frequency of nstxout,
nstfout                 = 0         ; nstvout, and nstfout
nstenergy               = 5000      ; save energies every 10.0 ps
nstlog                  = 5000      ; update log file every 10.0 ps
nstxout-compressed      = 5000      ; save compressed coordinates every 10.0 ps
compressed-x-grps       = System    ; save the whole system
; Bond parameters
continuation            = yes       ; Restarting after NPT
constraint_algorithm    = lincs     ; holonomic constraints
constraints             = h-bonds   ; bonds involving H are constrained
lincs_iter              = 1         ; accuracy of LINCS
lincs_order             = 4         ; also related to accuracy
; Neighborsearching
cutoff-scheme           = Verlet    ; Buffered neighbor searching
ns_type                 = grid      ; search neighboring grid cells
nstlist                 = 10        ; 20 fs, largely irrelevant with Verlet scheme
rcoulomb                = 1.0       ; short-range electrostatic cutoff (in nm)
rvdw                    = 1.0       ; short-range van der Waals cutoff (in nm)
; Electrostatics
coulombtype             = PME       ; Particle Mesh Ewald for long-range electrostatics
pme_order               = 4         ; cubic interpolation
fourierspacing          = 0.16      ; grid spacing for FFT
; Temperature coupling is on
tcoupl                  = V-rescale             ; modified Berendsen thermostat
tc-grps                 = Protein Non-Protein   ; two coupling groups - more accurate
tau_t                   = 0.1     0.1           ; time constant, in ps
ref_t                   = 300     300           ; reference temperature, one for each group, in K
; Pressure coupling is on
pcoupl                  = Parrinello-Rahman     ; Pressure coupling on in NPT
pcoupltype              = isotropic             ; uniform scaling of box vectors
tau_p                   = 2.0                   ; time constant, in ps
ref_p                   = 1.0                   ; reference pressure, in bar
compressibility         = 4.5e-5                ; isothermal compressibility of water, bar^-1
; Periodic boundary conditions
pbc                     = xyz       ; 3-D PBC
; Dispersion correction
DispCorr                = EnerPres  ; account for cut-off vdW scheme
; Velocity generation
gen_vel                 = no        ; Velocity generation is off
	"""
}

# Generate Molecular Dynamic Parameter Files
writeIonMdp > ions.mdp # for solvation
writeMinimMdp > minim.mdp # for energy minimization
writeNvtMdp > nvt.mdp # for NVT equilibration
writeNptMdp > npt.mdp # for NPT equilibration
writeMdMdp > md.mdp # for production MD

# # Remove water molecules (crystal)
# grep -v "HOH" $f > $fc

# # Create required files; topology, position restraint, post-processed structure
# gmx pdb2gmx -f $fc -o $fp -water spce
# 
# # Define unit cell & add solvent
# gmx editconf -f $fp -o $fn -c -d 1.0 -bt cubic
# gmx solvate -cp $fn -cs spc216.gro -o $fs -p topol.top
# gmx grompp -f ions.mdp -c $fs -p topol.top -o ions.tpr
# gmx genion -s ions.tpr -o $fsi -p topol.top -pname NA -nname CL -neutral
# 
# # Energy minimization
# gmx grompp -f minim.mdp -c $fsi -p topol.top -o em.tpr
# gmx mdrun -v -deffnm em
# gmx energy -f em.edr -o $Epe
# grep -v -e "#" -e "@" $Epe > $Epet
# 
# # Equilibration Phase 1: NVT (Energy and Temperature)
# gmx grompp -f nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr
# gmx mdrun -v -deffnm nvt
# gmx energy -f nvt.edr -o $Et
# grep -v -e "#" -e "@" $Et > $Ett
# 
# # Equilibration Phase 2: NPT (Pressure and Density)
# gmx grompp -f npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt.tpr
# gmx mdrun -v -deffnm npt
# gmx energy -f npt.edr -o $Epr
# grep -v -e "#" -e "@" $Epr > $Eprt
# gmx energy -f npt.edr -o $Ed
# grep -v -e "#" -e "@" $Ed > $Edt
# 
# # Run Production MD
# #gmx grompp -f md.mdp -c npt.gro -t npt.cpt -p topol.top -o md_0_1.tpr
# #gmx mdrun -v -deffnm md_0_1
# 
# # Generate plots
# Rscript ~/Git/NTD-MANE/mds_analysis/plot.R $Epet $Ett $Eprt $Edt

qsub_gen() {
echo -e """
#!/bin/bash
#PBS -l select=10:ncpus=24:mpiprocs=24
#PBS -l walltime=96:00:00
#PBS -q smp
#PBS -m abe
#PBS -P CBBI1243
#PBS -o /mnt/lustre/groups/CBBI1243/KEVIN/mds/stdout.txt
#PBS -e /mnt/lustre/groups/CBBI1243/KEVIN/mds/stderr.txt
#PBS -N Gromacs_$fb
#PBS -M kevin.esoh@students.jkuat.ac.ke
#PBS -mb

#MODULEPATH=/opt/gridware/bioinformatics/modules:\$MODULEPATH
#source /etc/profile.d/modules.sh

### # module add/load # ###
module add chpc/BIOMODULES
module load gromacs/5.1.4-openmpi_1.10.2-intel16.0.1
module load R/3.6.0-gcc7.2.0

OMP_NUM_THREADS=1

NP=\`cat \${PBS_NODEFILE} | wc -l\`

mdr=\"gmx_mpi mdrun\"
#ARGS=\"-s X -deffnm Y\"

cd /mnt/lustre/groups/CBBI1243/KEVIN/mds/
#mpirun -np \${NP} -machinefile \${PBS_NODEFILE} \${mdr} \${ARGS}

# Remove water molecules (crystal)
grep -v \"HOH\" $f > $fc

# Create required files; topology, position restraint, post-processed structure
gmx pdb2gmx -f $fc -o $fp -water spce

# Define unit cell & add solvent
gmx editconf -f $fp -o $fn -c -d 1.0 -bt cubic
gmx solvate -cp $fn -cs spc216.gro -o $fs -p topol.top
gmx grompp -f ions.mdp -c $fs -p topol.top -o ions.tpr
gmx genion -s ions.tpr -o $fsi -p topol.top -pname NA -nname CL -neutral

# Energy minimization
gmx grompp -f minim.mdp -c $fsi -p topol.top -o em.tpr
time mpirun -np ${NP} -machinefile ${PBS_NODEFILE} ${mdr} -v -deffnm em #gmx mdrun
gmx energy -f em.edr -o $Epe
grep -v -e \"#\" -e \"@\" $Epe > $Epet

# Equilibration Phase 1: NVT (Energy and Temperature)
gmx grompp -f nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr
time mpirun -np ${NP} -machinefile ${PBS_NODEFILE} ${mdr} -v -deffnm nvt #gmx mdrun
gmx energy -f nvt.edr -o $Et
grep -v -e \"#\" -e \"@\" $Et > $Ett

# Equilibration Phase 2: NPT (Pressure and Density)
gmx grompp -f npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt.tpr
time mpirun -np ${NP} -machinefile ${PBS_NODEFILE} ${mdr} -v -deffnm npt #gmx mdrun
gmx energy -f npt.edr -o $Epr
grep -v -e \"#\" -e \"@\" $Epr > $Eprt
gmx energy -f npt.edr -o $Ed
grep -v -e \"#\" -e \"@\" $Ed > $Edt

# Run Production MD
#gmx grompp -f md.mdp -c npt.gro -t npt.cpt -p topol.top -o md_0_1.tpr
#time mpirun -np ${NP} -machinefile ${PBS_NODEFILE} ${mdr} -v -deffnm md_0_1 #gmx mdrun

# Analysis
#gmx trjconv -s md_0_1.tpr -f md_0_1.xtc -o md_0_1_noPBC.xtc -pbc mol -center # enter 1 0 on prompt
#gmx rms -s md_0_1.tpr -f md_0_1_noPBC.xtc -o rmsd.xvg -tu ns # enter 4 4 on prompt
#grep -v -e \"#\" -e \"@\" rmsd.xvg > rmsd.txt

#gmx rms -s em.tpr -f md_0_1_noPBC.xtc -o rmsd_xtal.xvg -tu ns # for crystal structure: 4 4 on prompt
#grep -v -e \"#\" -e \"@\" rmsd_xtal.xvg > rmsd_xtal.txt

#gmx gyrate -s md_0_1.tpr -f md_0_1_noPBC.xtc -o gyrate.xvg # enter 1 on prompt
#grep -v -e \"#\" -e \"@\" gyrate.xvg > gyrate.txt

# Generate plots
Rscript /mnt/lustre/groups/CBBI1243/KEVIN/mds/plot.R $Epet $Ett $Eprt $Edt
"""
}
qsub_gen > $fb.qsub
sleep 1
echo -e "\n Gromacs job created! Please submit with 'qsub $fb.qsub'\n"
fi
}