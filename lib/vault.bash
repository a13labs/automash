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
# File: vault.bash 

# If vault master password is not defined, abort
[ -z ${VAULT_MASTER_PASSWORD} ] && { echo >&2 "I require VAULT_MASTER_PASSWORD but it's not defined. Aborting."; return 1; }

S2K_CIPHER_ALGO="AES256"
S2K_DIGEST_ALGO="SHA512"
S2K_COUNT=65011712

# If vault file is not defined, revert to default
[ -z ${VAULT_PASSWORD_FILE} ] && VAULT_PASSWORD_FILE="repository.vault"

function encrypt () {
    local MASTER_PASSWORD="${1}"
   
    if [ -z ${2} ]; then
        gpg --force-mdc --quiet -c --batch --passphrase "${MASTER_PASSWORD}" --s2k-cipher-algo ${S2K_CIPHER_ALGO} --s2k-digest-algo ${S2K_DIGEST_ALGO} --s2k-count ${S2K_COUNT} | base64 --wrap 0
        return 0
    fi

    [ -f ${2} ] || return 1
    
    gpg --force-mdc --quiet -c --batch --passphrase "${MASTER_PASSWORD}" --s2k-cipher-algo ${S2K_CIPHER_ALGO} --s2k-digest-algo ${S2K_DIGEST_ALGO} --s2k-count ${S2K_COUNT} ${2} | base64 --wrap 0 
}

function decrypt () {
    local MASTER_PASSWORD="${1}"

    if [ -z ${2} ]; then
         base64 -d | gpg --force-mdc --quiet -d --batch --passphrase "${MASTER_PASSWORD}"
        return 0
    fi

    [ -f ${2} ] || return 1
    
     cat ${2} | base64 -d | gpg --force-mdc --quiet -d --batch --passphrase "${MASTER_PASSWORD}"
}

function encrypt_stdin () {
    local MASTER_PASSWORD="${1}"
    encrypt ${MASTER_PASSWORD}
}

function encrypt_from_file () {
    local MASTER_PASSWORD="${1}"
    local FILE="${2}"
    encrypt ${MASTER_PASSWORD} ${FILE}
}

function encrypt_to_file () {
    local MASTER_PASSWORD="${1}"
    local FILE="${2}"
    encrypt ${MASTER_PASSWORD} > ${FILE}
}

function encrypt_file () {
    local MASTER_PASSWORD="${1}"
    local SRC="${2}"
    local DST="${3}"
    encrypt ${MASTER_PASSWORD} ${SRC} > ${DST}
}

function decrypt_stdin () {
    local MASTER_PASSWORD="${1}"
    decrypt ${MASTER_PASSWORD}
}

function decrypt_from_file () {
    local MASTER_PASSWORD="${1}"
    local FILE="${2}"
    decrypt ${MASTER_PASSWORD} ${FILE}
}

function decrypt_to_file () {
    local MASTER_PASSWORD="${1}"
    local FILE="${2}"
    decrypt ${MASTER_PASSWORD} > ${FILE}
}

function decrypt_file () {
    local MASTER_PASSWORD="${1}"
    local SRC="${2}"
    local DST="${3}"
    decrypt ${MASTER_PASSWORD} ${SRC} > ${DST}
}

function vault_has_value () {

    local KEY="${1}"

    # No master password defined, cannot continue
    [ -z ${VAULT_MASTER_PASSWORD} ] && return 1

    # Check if vault file exists
    [ ! -f "${VAULT_PASSWORD_FILE}" ] && return 1

    # Check if cault is encrypted
    is_encrypted "${VAULT_PASSWORD_FILE}" || return 1
    
    # Check if key exists
    cat "${VAULT_PASSWORD_FILE}" | decrypt "${VAULT_MASTER_PASSWORD}" | grep -q ^${KEY}=
}

function vault_get_variable () {

    local KEY="${1}"

    # No master password defined, cannot continue
    [ -z ${VAULT_MASTER_PASSWORD} ] && return 1
    
    # Check if vault file exists
    [ ! -f "${VAULT_PASSWORD_FILE}" ] && return 1

    # Check if cault is encrypted
    is_encrypted "${VAULT_PASSWORD_FILE}" || return 1
    
    # Check if key exists
    cat "${VAULT_PASSWORD_FILE}" | decrypt "${VAULT_MASTER_PASSWORD}" | grep -q ^${KEY}= || return 1

    # Return the value
    printf "%s" $(cat "${VAULT_PASSWORD_FILE}" | decrypt "${VAULT_MASTER_PASSWORD}" | grep ^${KEY}=)
}

function vault_get_local_variable () {
    local KEY="${1}"
    echo "local $(vault_get_variable ${KEY})"
}

function vault_get_export_variable () {
    local KEY="${1}"
    echo "export $(vault_get_variable ${KEY})"
}

function vault_get_quoted_value () {

    local KEY="${1}"
    eval $(vault_get_variable ${KEY})
    echo "\"${!KEY}\""
}

function vault_get_value () {

    local KEY="${1}"
    eval $(vault_get_variable ${KEY})
    echo ${!KEY}
}

function vault_set_value () {

    local KEY="${1}"
    local VALUE="${2}"

    # No master password defined, cannot continue
    [ -z ${VAULT_MASTER_PASSWORD} ] && return 1

    local TMP_FILE=$(mktemp)
    local TIMESTAMP=$(date +"%Y%m%d%H%M%S")

    # If vault file exists, we need to unencrypt first
    if [ -f "${VAULT_PASSWORD_FILE}" ]; then
        # Check if vault is encrypted, otherwise return
        is_encrypted "${VAULT_PASSWORD_FILE}" || return 1
        cat "${VAULT_PASSWORD_FILE}" | decrypt "${VAULT_MASTER_PASSWORD}" >"${TMP_FILE}"
    fi
    
    # Check if key exists
    if grep -q "${KEY}=" ${TMP_FILE} >/dev/null; then
        sed -i 's/^'${KEY}'=.*/'${KEY}'='${VALUE}'/' ${TMP_FILE}
    else
        echo "${KEY}=${VALUE}" >> ${TMP_FILE}
    fi

    # If vault file already exists, create a backup and delete it
    if [ -f ${VAULT_PASSWORD_FILE} ]; then
        cp "${VAULT_PASSWORD_FILE}" "${VAULT_PASSWORD_FILE}.${TIMESTAMP}.bak"
        rm --preserve-root "${VAULT_PASSWORD_FILE}"
    fi

    # Encrypt the vault and remove temp file
    cat ${TMP_FILE} | encrypt "${VAULT_MASTER_PASSWORD}" > "${VAULT_PASSWORD_FILE}"
    rm --preserve-root "${TMP_FILE}"
}

function vault_open () {

    # No master password defined, cannot continue
    [ -z ${VAULT_MASTER_PASSWORD} ] && return 1

    local TMP_FILE=$(mktemp)
    local TIMESTAMP=$(date +"%Y%m%d%H%M%S")

    # If vault file exists, we need to unencrypt first
    if [ -f "${VAULT_PASSWORD_FILE}" ]; then
        # Check if vault is encrypted, otherwise return
        is_encrypted "${VAULT_PASSWORD_FILE}" || return 1
        cat "${VAULT_PASSWORD_FILE}" | decrypt "${VAULT_MASTER_PASSWORD}" >"${TMP_FILE}"
    fi
    
    # Call passed arguments
    ${@} ${TMP_FILE} || { echo "Error running command! Aborting...."; rm --preserve-root "${TMP_FILE}"; return 1; }

    # If vault file already exists, create a backup and delete it
    if [ -f ${VAULT_PASSWORD_FILE} ]; then
        cp "${VAULT_PASSWORD_FILE}" "${VAULT_PASSWORD_FILE}.${TIMESTAMP}.bak"
        rm --preserve-root "${VAULT_PASSWORD_FILE}"
    fi

    # Encrypt the vault and remove temp file
    cat ${TMP_FILE} | encrypt "${VAULT_MASTER_PASSWORD}" > "${VAULT_PASSWORD_FILE}"
    rm --preserve-root "${TMP_FILE}"
}

function vault_list_keys () {

    # No master password defined, cannot continue
    [ -z ${VAULT_MASTER_PASSWORD} ] && return 1
    
    # Check if vault file exists
    [ ! -f "${VAULT_PASSWORD_FILE}" ] && return 1

    # Check if cault is encrypted
    is_encrypted "${VAULT_PASSWORD_FILE}" || return 1
    
    # Return the value
    printf "%s\n" $(cat "${VAULT_PASSWORD_FILE}" | decrypt "${VAULT_MASTER_PASSWORD}" | awk -F"=" '{print $1}'  )

}

function vault_del_key () {

    local KEY="${1}"

    # No master password defined, cannot continue
    [ -z ${VAULT_MASTER_PASSWORD} ] && return 1
    
    # Check if vault file exists
    [ ! -f "${VAULT_PASSWORD_FILE}" ] && return 1

    # Check if cault is encrypted
    is_encrypted "${VAULT_PASSWORD_FILE}" || return 1
    
    local TMP_FILE=$(mktemp)

    # Decrypt the vault and remove the key
    cat "${VAULT_PASSWORD_FILE}" | decrypt "${VAULT_MASTER_PASSWORD}" | grep -v ^${KEY}= > "${TMP_FILE}" 

    # Encrypt the vault and remove temp file
    cat ${TMP_FILE} | encrypt "${VAULT_MASTER_PASSWORD}" > "${VAULT_PASSWORD_FILE}"
    rm --preserve-root "${TMP_FILE}"

}

function is_encrypted {
    local TMP_FILE=$(mktemp)
    cat ${1} | base64 -d &> ${TMP_FILE} || return 1
    file "${TMP_FILE}" | grep -q "PGP symmetric key encrypted data" || return 1
    rm --preserve-root ${TMP_FILE}
}
