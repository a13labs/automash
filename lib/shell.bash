shopt -s expand_aliases

eval "alias reload=\"source ${INFRA_TOOLS_DIR}/lib/shell.bash\""

function set_git_key () {
    if [ -f ${HOME}/.ssh/keys/id_rsa.${1} ]; then
        echo "Setting GIT key to ${HOME}/.ssh/keys/id_rsa.${1}"
        export GIT_SSH_COMMAND="ssh -i ${HOME}/.ssh/keys/id_rsa.${1}"
        return 0
    fi

    echo "No key found! Using default key..."
    export GIT_SSH_COMMAND="ssh -i ${HOME}/.ssh/keys/id_rsa.default"
    return 0
}

function set_ssh_key () {
    if [ -f ${HOME}/.ssh/keys/id_rsa.${1} ]; then
        echo "Using key ${HOME}/.ssh/keys/id_rsa.${1}"
        [ -f ${HOME}/.ssh/id_rsa ] && rm ${HOME}/.ssh/id_rsa
        ln -s ${HOME}/.ssh/keys/id_rsa.${1} ${HOME}/.ssh/id_rsa 
        return 0
    fi

    echo "No key found, Using default key..."
    [ -f ${HOME}/.ssh/id_rsa ] && rm ${HOME}/.ssh/id_rsa
    ln -s ${HOME}/.ssh/keys/id_rsa.default ${HOME}/.ssh/id_rsa
    return 1
}

