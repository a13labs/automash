#!/bin/bash
# 
# Copyright 2019 Alexandre Pires (c.alexandre.pires@gmail.com)
# 
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
# 
#        http://www.apache.org/licenses/LICENSE-2.0
# 
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
# 
# File: ansible.bash 

# Make sure we can use vault functions
type -t is_encrypted | grep -q "^function$" || { echo >&2 "I require is_encrypted but it's not defined. Aborting."; return 1; }
type -t vault_has_value | grep -q "^function$" || { echo >&2 "I require vault_has_value but it's not defined. Aborting."; return 1; }
type -t vault_get_local_variable | grep -q "^function$" || { echo >&2 "I require vault_get_local_variable but it's not defined. Aborting."; return 1; }
type -t vault_set_value | grep -q "^function$" || { echo >&2 "I require vault_set_value but it's not defined. Aborting."; return 1; }

# If vault file is not defined, revert to default
[ -z ${ANSIBLE_CONFIG_FILE} ] && ANSIBLE_CONFIG_FILE="ansible.cfg"

function ansible_config_get_value() {

    local KEY="${1}"

    if [ -z ${2} ]; then
        local SECTION="${2}"
    else
        local SECTION="defaults"
    fi

    # Exits if config file does not exists
    [ -f ${ANSIBLE_CONFIG_FILE} ] || return 1

    # Check if value exists
    sed -nr "/^\[${SECTION}\]/ { :l /^\s*[^#].*/ p; n; /^\[/ q; b l; }" ${ANSIBLE_CONFIG_FILE} | grep -q ^private_key_file= || return 1

    # Return value
    sed -nr "/^\[${SECTION}\]/ { :l /^\s*[^#].*/ p; n; /^\[/ q; b l; }" ${ANSIBLE_CONFIG_FILE} | grep ^private_key_file=
}

function ansible_available_targets() {

    local ANSIBLE_INVENTORY="${1}"

    # Exits if inventory does not exists
    [ -f ${ANSIBLE_INVENTORY} ] || return 1

    sed -nr "/^\[all\]/ { :l /^\s*[^#].*/ p; n; /^\[/ q; b l; }" ${ANSIBLE_INVENTORY} | tail -n +2 | awk '{print $1, $8}'
}

function ansible_is_target_available () {

    local ANSIBLE_INVENTORY="${1}"
    local TARGET="${2}"

    # Exits if inventory does not exists
    [ -f ${ANSIBLE_INVENTORY} ] || return 1

    ansible_available_targets ${ANSIBLE_INVENTORY} | grep -q ${TARGET}
}

function ansible_available_playbooks() {

    local PLAYBOOK_DIR="${1}"

    # Exits if inventory does not exists
    [ -d ${PLAYBOOK_DIR} ] || return 1

    for PLAYBOOK in $(ls ${PLAYBOOK_DIR}/*.yml); do
        printf "%s\n" "$(basename ${PLAYBOOK})"
    done
}

function ansible_run_playbook () {

    local ANSIBLE_INVENTORY="${1}"
    local ANSIBLE_PLAYBOOK="${2}"

    # Exits if inventory does not exists
    [ -f ${ANSIBLE_INVENTORY} ] || return 1

    # Exits if playbook does not exists
    [ -f ${ANSIBLE_PLAYBOOK} ] || return 1

    # If we have the password set on the Vault we get the value
    if vault_has_value "ANSIBLE_MASTER_PASSWORD"; then
        eval $(vault_get_local_variable "ANSIBLE_MASTER_PASSWORD")
    else
        return 1
    fi

    # Create a temporay file name to link to a FIFO
    local ANSIBLE_VAULT_PIPE=$(mktemp -u)
    
    # Create a temporary FIFO pipe and lock permissions to user
    mkfifo "${ANSIBLE_VAULT_PIPE}"
    chmod 600 "${ANSIBLE_VAULT_PIPE}"

    # Write Ansible password to the pipe
    echo "${ANSIBLE_MASTER_PASSWORD}" > ${ANSIBLE_VAULT_PIPE} &
    
    # Run Ansible playbook and link to the temporary FIFO pipe for the password
    ansible-playbook --vault-password-file=${ANSIBLE_VAULT_PIPE} ${@:3} -i ${ANSIBLE_INVENTORY} ${ANSIBLE_PLAYBOOK} 
    
    # Remove the pip
    rm --preserve-root "${ANSIBLE_VAULT_PIPE}"
}

function ansible_encrypt_key_value () {

    local KEY="${1}"
    local VALUE="${2}"

    # If we have the password set on the Vault we get the value
    if vault_has_value "ANSIBLE_MASTER_PASSWORD"; then
        eval $(vault_get_local_variable "ANSIBLE_MASTER_PASSWORD")
    else
        return 1
    fi

    # Create a temporay file name to link to a FIFO
    local ANSIBLE_VAULT_PIPE=$(mktemp -u)
    
    # Create a temporary FIFO pipe and lock permissions to user
    mkfifo "${ANSIBLE_VAULT_PIPE}"
    chmod 600 "${ANSIBLE_VAULT_PIPE}"

    # Write Ansible password to the pipe
    echo "${ANSIBLE_MASTER_PASSWORD}" > ${ANSIBLE_VAULT_PIPE} &
    
    # Ansible vault encrypt key/vaule
    ansible-vault encrypt_string --vault-password-file=${ANSIBLE_VAULT_PIPE} ${VALUE} --name ${KEY}
    
    # Remove the pip
    rm --preserve-root "${ANSIBLE_VAULT_PIPE}"
}

function ansible_encrypt_key_stdin () {

    local KEY="${1}"

    # If we have the password set on the Vault we get the value
    if vault_has_value "ANSIBLE_MASTER_PASSWORD"; then
        eval $(vault_get_local_variable "ANSIBLE_MASTER_PASSWORD")
    else
        return 1
    fi

    # Create a temporay file name to link to a FIFO
    local ANSIBLE_VAULT_PIPE=$(mktemp -u)
    
    # Create a temporary FIFO pipe and lock permissions to user
    mkfifo "${ANSIBLE_VAULT_PIPE}"
    chmod 600 "${ANSIBLE_VAULT_PIPE}"

    # Write Ansible password to the pipe
    echo "${ANSIBLE_MASTER_PASSWORD}" > ${ANSIBLE_VAULT_PIPE} &
    
    # Ansible vault encrypt from stdin
    ansible-vault encrypt_string --vault-password-file=${ANSIBLE_VAULT_PIPE} --stdin-name ${KEY}
    
    # Remove the pip
    rm --preserve-root "${ANSIBLE_VAULT_PIPE}"
}

function tf_ansible_run_playbook () {

    local ANSIBLE_INVENTORY="${1}"
    local ANSIBLE_PLAYBOOK="${2}"

    # Exits if playbook does not exists
    [ -f ${ANSIBLE_PLAYBOOK} ] || return 1

    # If we have the password set on the Vault we get the value
    if vault_has_value "ANSIBLE_MASTER_PASSWORD"; then
        eval $(vault_get_local_variable "ANSIBLE_MASTER_PASSWORD")
    else
        return 1
    fi

    # Create a temporay file name to link to a FIFO
    local ANSIBLE_VAULT_PIPE=$(mktemp -u)
    
    # Create a temporary FIFO pipe and lock permissions to user
    mkfifo "${ANSIBLE_VAULT_PIPE}"
    chmod 600 "${ANSIBLE_VAULT_PIPE}"

    # Write Ansible password to the pipe
    echo "${ANSIBLE_MASTER_PASSWORD}" > ${ANSIBLE_VAULT_PIPE} &
    
    # Run Ansible playbook and link to the temporary FIFO pipe for the password
    ansible-playbook --vault-password-file=${ANSIBLE_VAULT_PIPE} ${@:3} -i ${ANSIBLE_INVENTORY}, ${ANSIBLE_PLAYBOOK} 
    
    # Remove the pip
    rm --preserve-root "${ANSIBLE_VAULT_PIPE}"
}

function ansible_set_password () {

    local NEW_PASSWORD="${1}"
    vault_set_value "ANSIBLE_MASTER_PASSWORD" "${NEW_PASSWORD}"
}