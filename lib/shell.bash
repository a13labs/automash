shopt -s expand_aliases

eval "alias reload=\"source ${INFRA_TOOLS_DIR}/lib/shell.bash\""

function set_ssh_key {
    # Set the ssh key to use
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

function create_ssh_key {

    mkdir -p ${HOME}/.ssh/keys

    if [ -f ${HOME}/.ssh/keys/id_rsa.${1} ]; then
        echo "Key already exists"
        return 1
    fi

    ssh-keygen -f ${HOME}/.ssh/keys/id_rsa.${1} ${@:2}
}

function create_project {

    [ ${#} -eq 0 ] && return 1

    # Sanitize the filename
    NAME=$(echo -n $1 | perl -pe 's/[\?\[\]\/\\=<>:;,''"&\$#*()|~`!{}%+]//g;' -pe 's/[\r\n\t -]+/-/g;')
    
    if [ -d ./${1} ]; then
        echo "Project already exists (${1})"
        return 1
    fi

    echo "Creating project: ${NAME}"
    mkdir -p ${NAME} ${NAME}/playbooks ${NAME}/terraform ${NAME}/ssh-keys
    echo "[all]" > ${NAME}/hosts
    cp ${INFRA_TOOLS_DIR}/resources/* ${NAME}
    echo "Project created."
}

function tf_create {

    if [ ! -f ./project.rc ]; then
        echo "Project configuration not found!"
        return 1
    fi

    [ ${#} -eq 0 ] && return 1

    source project.rc

    NAME=$(echo -n $1 | perl -pe 's/[\?\[\]\/\\=<>:;,''"&\$#*()|~`!{}%+]//g;' -pe 's/[\r\n\t -]+/-/g;')

    if [ -d ${TERRAFORM_PROJECTS}/${1} ]; then
        echo "Project already exists (${1})"
        return 1
    fi

    echo "Creating terraform project: ${NAME}"
    mkdir -p ${TERRAFORM_PROJECTS}/${1}
    cp -r ${INFRA_TOOLS_DIR}/resources/templates/terraform/* ${TERRAFORM_PROJECTS}/${1}
    echo "Project created."
}
