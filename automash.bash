#!/bin/bash

# If we are running the script then we want to install it
if [[ $0 == $BASH_SOURCE ]]; then
    printf "Running automash installation!\n"
    
    # Get script directory
    SCRIPTDIR=$(dirname "$(readlink -f "$0")")
    
    # Check if the source line is already added to users bashrc
    cat ${HOME}/.bashrc | grep -q "source ${SCRIPTDIR}/automash.bash" && { printf "Already installed! Exiting...\n"; exit 0; }
    
    # Create required folders folder
    mkdir -p ${HOME}/.ssh/keys
    
    # Add source line to users bashrx
    printf "\n%s\n" "source ${SCRIPTDIR}/automash.bash" >> ${HOME}/.bashrc
    printf "Successful installed on your system!\n"
    sudo -u ${USER} -i
fi

# This part the source part
INFRA_TOOLS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Added our binary directory to the current path
PATH=${INFRA_TOOLS_DIR}/bin:${PATH}

# Include the shell functions
source ${INFRA_TOOLS_DIR}/lib/shell.bash

