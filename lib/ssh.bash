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
# File: ssh.bash 

# Make sure we can use vault functions
type -t is_encrypted | grep -q "^function$" || { echo >&2 "I require is_encrypted but it's not defined. Aborting."; return 1; }
type -t vault_has_value | grep -q "^function$" || { echo >&2 "I require vault_has_value but it's not defined. Aborting."; return 1; }
type -t vault_get_local_variable | grep -q "^function$" || { echo >&2 "I require vault_get_local_variable but it's not defined. Aborting."; return 1; }
type -t vault_set_value | grep -q "^function$" || { echo >&2 "I require vault_set_value but it's not defined. Aborting."; return 1; }

function encrypt_ssh_keys () {

    local SSH_KEYS_FOLDER=${1}

    # If we have the password set on the Vault we get the value
    if vault_has_value "SSH_KEYS_MASTER_PASSWORD"; then
        eval $(vault_get_local_variable "SSH_KEYS_MASTER_PASSWORD")
    else
        return 1
    fi

    for SSH_KEY in $(find ${SSH_KEYS_FOLDER} -type f); do 
        
        # Make sure the key have the right permissions
        chmod 600 "${SSH_KEY}"

        # Skip if it's not a ssh key file
        ssh-keygen -lf "${SSH_KEY}" &>/dev/null || continue

        # If key is already encrypted skip        
        [ -f "${SSH_KEY}.key" ] && continue

        # Encrypt the content
        cat "${SSH_KEY}" | encrypt "${SSH_KEYS_MASTER_PASSWORD}" > "${SSH_KEY}.key" || continue

    done
}

function decrypt_ssh_keys () {
    
    local SSH_KEYS_FOLDER=${1}

    # If we have the password set on the Vault we get the value
    if vault_has_value "SSH_KEYS_MASTER_PASSWORD"; then
        eval $(vault_get_local_variable "SSH_KEYS_MASTER_PASSWORD")
    else
        return 1
    fi

    # Temp file with decrypted content
    local TMP_FILE=$(mktemp /tmp/keyXXXXX)

    for SSH_KEY in $(find ${SSH_KEYS_FOLDER} -type f -name *.key); do 

        # if file is not encrypted continue
        is_encrypted ${SSH_KEY} || continue
        
        # decrypt file contents to temp file
        cat "${SSH_KEY}" | decrypt "${SSH_KEYS_MASTER_PASSWORD}" >"${TMP_FILE}"
        
        # validate if it is a ssh key file
        ssh-keygen -lf "${TMP_FILE}" &>/dev/null || return 1
        
        # restore the file
        cp "${TMP_FILE}" "${SSH_KEY%.*}"

        # Make sure we have the right permissions
        chmod 600 "${SSH_KEY%.*}"
    done

    # clean up
    rm --preserve-root "${TMP_FILE}"
}

function encrypt_ssh_key () {

    local SSH_KEY_FILE=${1}

    # Exit if file does not exists
    [ -f ${SSH_KEY_FILE} ] || return 1

    # If we have the password set on the Vault we get the value
    if vault_has_value "SSH_KEYS_MASTER_PASSWORD"; then
        eval $(vault_get_local_variable "SSH_KEYS_MASTER_PASSWORD")
    else
        return 1
    fi

    # Make sure we have the right permissions
    chmod 600 "${SSH_KEY_FILE}"

    # Check if file is a ssh key file
    ssh-keygen -lf "${SSH_KEY_FILE}" &>/dev/null || return 1

    # If key is already encrypted skip        
    [ -f "${SSH_KEY_FILE}.key" ] && return 0

    # Encript the file and remove the original
    cat "${SSH_KEY_FILE}" | encrypt "${SSH_KEYS_MASTER_PASSWORD}" > "${SSH_KEY_FILE}.key" || continue
}

function decrypt_ssh_key () {

    local SSH_KEY_FILE=${1}

    # Exit if file does not exists
    [ -f ${SSH_KEY_FILE} ] || return 1

    # If we have the password set on the Vault we get the value
    if vault_has_value "SSH_KEYS_MASTER_PASSWORD"; then
        eval $(vault_get_local_variable "SSH_KEYS_MASTER_PASSWORD")
    else
        return 1
    fi

    # if file is not encrypted continue
    is_encrypted ${SSH_KEY_FILE} || return 1
    
    # Temp file with decrypted content
    local TMP_FILE=$(mktemp /tmp/keyXXXXX)

    # decrypt file contents to temp file
    cat "${SSH_KEY_FILE}" | decrypt "${SSH_KEYS_MASTER_PASSWORD}" >"${TMP_FILE}"
    
    # validate if it is a ssh key file
    ssh-keygen -lf "${TMP_FILE}" &>/dev/null || return 1
    
    # restore the file
    cp "${TMP_FILE}" "${SSH_KEY_FILE%.*}"

    # Make sure we have the right permissions
    chmod 600 "${SSH_KEY_FILE%.*}"

    # clean up
    rm --preserve-root "${TMP_FILE}"
}

function ssh_set_password () {

    local NEW_PASSWORD="${1}"

    vault_set_value "SSH_KEYS_MASTER_PASSWORD" "${NEW_PASSWORD}"
}