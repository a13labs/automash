#!/bin/zsh

# If we are running the script then we want to install it
if [[ $0 == $_ ]]; then
    printf "Running infra-tools installation!\n"
    
    # Get script directory
    SCRIPTDIR=$(dirname "$(readlink -f "$0")")
    
    # Check if the source line is already added to users bashrc
    cat ${HOME}/.zshrc | grep -q "source ${SCRIPTDIR}/infra-tools.zsh" && { printf "Already installed! Exiting...\n"; exit 0; }
    
    # Create required folders folder
    mkdir -p ${HOME}/.ssh/keys
    
    # Add source line to users bashrx
    printf "\n%s\n" "source ${SCRIPTDIR}/infra-tools.zsh" >> ${HOME}/.zshrc
    printf "Successful installed on your system!\n"
    sudo -u ${USER} -i
fi

# This part the source part
INFRA_TOOLS_DIR="$( cd "$( dirname "$0" )" >/dev/null 2>&1 && pwd )"

# Added our binary directory to the current path
PATH=${INFRA_TOOLS_DIR}/bin:${PATH}

# Include the shell functions
source ${INFRA_TOOLS_DIR}/lib/shell.bash

