#!/bin/bash 
# Author: Marcus Converse, Chenfei Tang
# This script sets up the environment variables needed to run the trigger code and runs the trigger code.

echo "Are you currently in the working directory for the trigger code? (Expected directory: 'trigger_code_working_directory' if you use the Configuration_triggerCode.sh script)"
read -rp "Enter y to continue or n to cancel: " confirm_dir
if [[ "$confirm_dir" != [Yy] ]]; then
    echo "Please navigate to the correct directory and rerun this script."
    exit 1
fi

WORKDIR=$(pwd)
export WORKDIR


echo "Are you in the shifter image 'luxzeplin/offline_hosted:rocky9_3'?"
read -rp "Enter y to confirm or n to cancel: " confirm_shifter
if [[ "$confirm_shifter" != [Yy] ]]; then
    echo "Please run 'shifterEL9 bash' to enter it and try again."
    exit 1
fi

echo "Prerequest confirmed. Proceeding with the script..."

# Prompt the user clearly
echo "This script will set up the environment variables needed to run the trigger code."


# These are environment variables that you set when you install the trigger code for the first time
alpacaDirectory="$WORKDIR/alpaca"
lzBuildPath="$WORKDIR/lz-nersc-jupyter/lz-standard/lzBuild.sh"
triggerefficiencyexternaltriggerPath="$WORKDIR/triggercode_created_dir"
export alpacaDirectory
export lzBuildPath
export triggerefficiencyexternaltriggerPath


# These are environment variables you set before you run the code.
echo "Please set the following environment variables before running the code:"
echo "Refer to the acquisition spreadsheet for details:"
echo "https://docs.google.com/spreadsheets/d/1Rw2oAL-fwXNA_J1xUhHWXos2oZiCRnq5XDg1jFfe4Kg/edit?gid=782033379#gid=782033379"

# Prompt for Acquisition Details
while true; do
    read -rp "Enter Acquisition Details (e.g., 'Test'): " AcqDet
    if [[ -n "$AcqDet" ]]; then
        echo "Acquisition Details set to: $AcqDet"
        break
    else
        echo "Acquisition Details cannot be empty. Please try again."
    fi
done

# Prompt for the path to the poorly formatted run list
while true; do
    echo "Please enter the path to the poorly formatted run list, for the format of run list txt file, see:"
    echo "https://gitlab.com/luxzeplin/users/mconverse/triggerefficiencyexternaltrigger/-/blob/main/VerificationFolder/TestRuns.txt?ref_type=heads"
    echo "Only include the relative path from the working directory, e.g., 'triggerefficiencyexternaltrigger/VerificationFolder/TestRuns.txt'."
    read -rp "Enter the path to the poorly formatted run list (e.g., '/path/to/TestRuns.txt'): " path

    if [[ -f "$path" ]]; then
        echo "File found: $path"
        break
    else
        echo "File does not exist. Please try again."
    fi
done

poorformatrunlist_path="${path}"

while true; do
    read -rp "Is this WIMP Search Data? (True/False): " WIMPSEARCHDATA
    if [[ "$WIMPSEARCHDATA" == "True" || "$WIMPSEARCHDATA" == "False" ]]; then
        echo "WIMP Search Data flag set to: $WIMPSEARCHDATA"
        break
    else
        echo "Invalid input. Please enter 'True' or 'False'."
    fi
done


while true; do
    echo "Please enter proper LZAP version, for the available versions, see:"
    echo "https://luxzeplin.gitlab.io/docs/softwaredocs/analysis/lzap/setuplzap.html"
    read -rp "Enter the LZAP version (e.g., 'LZAP-5.8.0'): " lzapversion
    if [[ -n "$lzapversion" ]]; then
        echo "LZAP version set to: $lzapversion"
        break
    else
        echo "LZAP version cannot be empty. Please try again."
    fi
done


split_n=5
binwidth=10
lowerpulsearealimit=0
upperpulsearealimit=2400
SetNominalThreshold=200 
innerradius0=0 #Center of detector
outerradius0=40 
innerradius1=40
outerradius1=57
innerradius2=57
outerradius2=80 


export poorformatrunlist_path
export split_n
export AcqDet
export WIMPSEARCHDATA
export binwidth
export lowerpulsearealimit
export upperpulsearealimit
export SetNominalThreshold 
#Radius/Inefficiency stuff
#radius cutoffs 0-40,40-57,57-68 are *roughly* equal in area
export innerradius0 #Center of detector
export outerradius0 
export innerradius1
export outerradius1
export innerradius2
export outerradius2 
export lzapversion

# Printing the environment variables for confirmation
echo "Environment variables set to:"
echo "Acquisition Details: $AcqDet"
echo "Path to list of runs: $poorformatrunlist_path"
echo "Is this WIMP Search Data: $WIMPSEARCHDATA"
echo "Which LZAP Version: $lzapversion"


# Script from here used to belong to the TriggerEfficiencyExternalTrigger.sh script
# The following code did the following:
#     Generate a directory structure in the working directory we just created: trigger_code_setup
#     Take a poorly formatted list of runs copied from the acquisitions spreadsheet
#     Properly format it and split it into lists of split_n runs each
#     Query the data catalog with these run lists and save the catalog queries
#     Run ALPACA over each of these run lists
#     Combine these outputs into a single data file and generate our efficiency report

#Generating the directory structure
cd $triggerefficiencyexternaltrigger || exit 1

#Revision makes these directories in user home directory
mkdir $WORKDIR/TriggerResults/
mkdir $WORKDIR/TriggerResults/$AcqDet || :
mkdir $WORKDIR/TriggerResults/$AcqDet/WSRunsFolder || :
cp $poorformatrunlist_path $WORKDIR/TriggerResults/$AcqDet/WSRunsFolder/$AcqDet.txt
mkdir $WORKDIR/TriggerResults/$AcqDet/WSRunsFolder/GoodFormat || :
mkdir $WORKDIR/TriggerResults/$AcqDet/DCQueries || :
mkdir $WORKDIR/TriggerResults/$AcqDet/InputLists || :
mkdir $WORKDIR/TriggerResults/$AcqDet/Results || :

#And the one directory on scratch
mkdir -p $SCRATCH/TriggerEfficiencyExtTrigger/$AcqDet/ || :

pfrlp=$WORKDIR/TriggerResults/$AcqDet/WSRunsFolder/$AcqDet.txt

# Running a python script to:
# Properly format and split runs
# Write DC queries with the split run lists to the DCQueries folder

export pfrlp

source $lzBuildPath
python $triggerefficiencyexternaltriggerPath/RunListParser.py


#Query the data catalog with these run lists and save the catalog queries.

#Do LZ Build
source $alpacaDirectory/setup.sh
build

#Copy TriggerEfficiencyExtTrigger to ALPACA modules directory and add with module helper
cp -a $triggerefficiencyexternaltriggerPath/TriggerEfficiencyExtTrigger $alpacaDirectory/modules/TriggerEfficiencyExtTrigger
moduleHelper TriggerEfficiencyExtTrigger --add


count=$(ls -l $WORKDIR/TriggerResults/$AcqDet/DCQueries | grep ^- | wc -l)
START=1
END=$count

END=7 #Add by F.W
for (( i=$START; i<=$END; i++ ))
do
	echo $WORKDIR/TriggerResults/$AcqDet/DCQueries/$AcqDet.DCquery_part$i.yaml
	queryData $WORKDIR/TriggerResults/$AcqDet/DCQueries/$AcqDet.DCquery_part$i.yaml -o $WORKDIR/TriggerResults/$AcqDet/InputLists/$AcqDet.InputList_part$i.list
done

#Running ALPACA over each file list


source $alpacaDirectory/setup.sh #build ALPACA again because we just added a module
build

for (( i=$START; i<=$END; i++ ))
do
	cp $WORKDIR/TriggerResults/$AcqDet/InputLists/$AcqDet.InputList_part$i.list $alpacaDirectory/modules/TriggerEfficiencyExtTrigger/inputs/TriggerEfficiencyExtTriggerInputFiles.list #Copy the input list to the proper place
	TriggerEfficiencyExtTrigger -w #Run the module

	cp $alpacaDirectory/run/TriggerEfficiencyExtTrigger/TriggerEfficiencyExtTriggerAnalysis.root $SCRATCH/TriggerEfficiencyExtTrigger/$AcqDet/$AcqDet.part$i.root #copy ALPACA output to scratch

	rm $alpacaDirectory/run/TriggerEfficiencyExtTrigger/TriggerEfficiencyExtTriggerAnalysis.root #clear the file
done

moduleHelper TriggerEfficiencyExtTrigger --remove
rm -rf $alpacaDirectory/modules/TriggerEfficiencyExtTrigger
#Run a python script collating all of this output
source $lzBuildPath

#python PythonScript1.py
python $triggerefficiencyexternaltriggerPath/TriggerEfficiencyProcessor.py
