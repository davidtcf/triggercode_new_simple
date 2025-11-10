#!/bin/bash
# Author: Chenfei Tang
# This script sets up shifter access and creates a working directory

echo "Configuring the trigger efficiency code..."

# Prompt the user clearly
echo "This script will modify your real ~/.bashrc to add LZ shifter setup."
echo "See https://luxzeplin.gitlab.io/docs/softwaredocs/computing/usdc/shifter.html for detial of LZ shifter"
read -rp "Do you want to continue? (y/n): " USER_CHOICE

if [[ "$USER_CHOICE" != "y" ]]; then
    echo "Aborted by user."
    exit 0
fi

# Modify the user's .bashrc to set up LZ shifter
BASHRC="$HOME/.bashrc"

if [ ! -f "$BASHRC" ]; then
    echo "$BASHRC does not exist. Creating it..."
    touch "$BASHRC"
fi

# Avoid duplicate appends
if ! grep -q "LZ Shifter Setup" "$BASHRC"; then
cat << 'EOF' >> "$BASHRC"

# ==== LZ Shifter Setup ====
c_cyan=$(tput setaf 6)
c_red=$(tput setaf 9)
c_green=$(tput setaf 2)
c_sgr0=$(tput sgr0)

if [[ -z "\${SHIFTER_IMAGEREQUEST}" ]]; then
   export PS1="\[${c_cyan}\][\h]:\[${c_sgr0}\]\[${c_green}\]\u\[${c_sgr0}\]/\[${c_red}\]\W \[${c_sgr0}\]> "
else
   export PS1="\[${c_cyan}\][\h@\${SHIFTER_IMAGEREQUEST}]:\[${c_sgr0}\]\[${c_green}\]\u\[${c_sgr0}\]/\[${c_red}\]\W \[${c_sgr0}\]> "
fi

shifterEL9(){
    /usr/bin/shifter --image=luxzeplin/offline_hosted:rocky9_3 --module=cvmfs "$@"
}
# ==== End LZ Shifter Setup ====

EOF
    echo "Appended LZ Shifter setup to $BASHRC"
else
    echo "LZ Shifter setup already present in $BASHRC; skipping re-append."
fi

# Source the updated bashrc
source "$BASHRC"


# Check if the user is in the correct directory

WORKDIR="$(pwd)/trigger_code_work_directory"
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1
export WORKDIR

echo "Working directory created and entered: $WORKDIR"

echo "Installing ALPACA..."

# ALPACA
git clone git@gitlab.com:luxzeplin/analysis/alpaca/alpaca.git
cd alpaca || exit 1
source setup.sh
build
echo "ALPACA installed and set up successfully."

# Python Kernel Setup
echo "Setting up Python environment..."

cd "$WORKDIR"
git clone git@gitlab.com:luxzeplin/lz-general/lz-nersc-jupyter.git

mkdir -p "$HOME/.local/share/jupyter/kernels"
cd "$HOME/.local/share/jupyter/kernels" || exit 1
ln -sf "$WORKDIR/lz-nersc-jupyter/lz-standard" lz-standard
ln -sf "$WORKDIR/lz-nersc-jupyter/lz-stat" lz_stat

# Modify lzBuild.sh to use correct ALPACA path
cat << EOF > "$WORKDIR/lz-nersc-jupyter/lz-standard/lzBuild.sh"
export LZ_SETUP_DBI=false
source /cvmfs/lz.opensciencegrid.org/LzBuild/release-4.2.0/setup.sh

export PYTHONPATH=\$(python -c "import site, os; print(os.path.join(site.USER_BASE, 'lib', 'python3.11', 'site-packages'))"):\$PYTHONPATH

DMCALC_PYHTONPATH=/cvmfs/lz.opensciencegrid.org/DMCalc/latest/x86_64-centos7-gcc8-opt/python
export PYTHONPATH=\$PYTHONPATH:\${DMCALC_PYHTONPATH}
EOF

# Trigger efficiency repo
cd "$WORKDIR"
git clone https://github.com/davidtcf/triggercode_created_dir.git
cp triggercode_created_dir/VerificationFolder/triggerconf_example.sh triggerconf.sh

# Source the modified build
source "$WORKDIR/lz-nersc-jupyter/lz-standard/lzBuild.sh"

# Install Python packages
pip install --force-reinstall -v uproot==4.3.7
pip install --force-reinstall -v numpy==1.24.4
pip install mpmath
pip install --force-reinstall -v matplotlib==3.7.5
pip install --force-reinstall -v pandas==2.0.3
pip install --force-reinstall -v scipy==1.10.1
pip install --force-reinstall -v tqdm==4.43.0
pip install --force-reinstall -v numba==0.58.1

echo "Setup complete inside: $WORKDIR"

# Launch container
echo "Launching Rocky 9 LZ shifter container for trigger code running....."
shifterEL9 bash
