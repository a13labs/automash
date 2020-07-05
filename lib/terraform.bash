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
# File: terraform.bash 

# Verify if terraform exists
# command -v terraform >/dev/null 2>&1 || { echo >&2 "I require terraform but it's not installed.  Aborting."; return 1; }

# Make sure we can use vault functions
type -t is_encrypted | grep -q "^function$" || { echo >&2 "I require is_encrypted but it's not defined. Aborting."; return 1; }
type -t vault_has_value | grep -q "^function$" || { echo >&2 "I require vault_has_value but it's not defined. Aborting."; return 1; }
type -t vault_get_value | grep -q "^function$" || { echo >&2 "I require vault_get_value but it's not defined. Aborting."; return 1; }
type -t vault_get_local_variable | grep -q "^function$" || { echo >&2 "I require vault_get_local_variable but it's not defined. Aborting."; return 1; }
type -t vault_set_value | grep -q "^function$" || { echo >&2 "I require vault_set_value but it's not defined. Aborting."; return 1; }

TERRAFORMCMD=${TERRAFORMCMD:-terraform}

function tf_compose_vars_file () {
    local SOURCE_FOLDER=${1}

    [ -d ${SOURCE_FOLDER} ] || return 1

    # Search for tfvars files in folder add as -var-file=${VAR_FILE}
    pushd ${SOURCE_FOLDER} >/dev/null 
    for VAR_FILE in $(find . -type f -name '*.tfvars') ; do 
        head -n 1 ${VAR_FILE} | grep -q "#VAULT" && continue || echo "-var-file=$(pwd)/$(basename ${VAR_FILE})"
    done 
    popd >/dev/null   
}

function tf_compose_vars_export () {
    local SOURCE_FOLDER=${1}

    [ -d ${SOURCE_FOLDER} ] || return 1

    # Search for tfvars files in folder add as -var-file=${VAR_FILE}
    pushd ${SOURCE_FOLDER} >/dev/null 
    for VAR_FILE in $(find . -type f -name '*.tfvars') ; do 
        head -n 1 ${VAR_FILE} | grep -q "#VAULT" && echo $(tf_compose_resource ${VAR_FILE} "export TF_VAR_" ";")
    done    
    popd >/dev/null   
}

function tf_compose_resource () {

    local CONFIG_FILE=${1}
    local PREFIX=${2}
    local SUFFIX=${3}

    # Exits if folder or backend configuration does not exists
    [ -f ${CONFIG_FILE} ] || return 1

    while IFS= read -r LINE
    do
        echo ${LINE} | grep -q "#VAULT" && continue
        echo "${PREFIX}$(eval echo ${LINE})${SUFFIX}"
    done < "${CONFIG_FILE}"
}

function tf_init () {
    
    local SOURCE_FOLDER=${1}

    # Exits if folder or backend configuration does not exists
    [ -d ${SOURCE_FOLDER} ] || return 1

    pushd ${SOURCE_FOLDER} >/dev/null 
    local BACKEND_CONFIG_VARS="backend/config.tfvars"
    local BACKEND_CONFIG_VARS_RENDERED="backend/config-rendered.tfvars"

    # If environment is defined the configuration is related to the current ENV
    if [ ! -z ${ENV} ]; then
        local BACKEND_CONFIG_VARS="backend/${ENV}/config.tfvars"
        local BACKEND_CONFIG_VARS_RENDERED="backend/${ENV}/config-rendered.tfvars"
    fi

    [ -f "${BACKEND_CONFIG_VARS}" ] && tf_compose_resource "${BACKEND_CONFIG_VARS}" > ${BACKEND_CONFIG_VARS_RENDERED} 

    ${TERRAFORMCMD} init -backend-config="${BACKEND_CONFIG_VARS_RENDERED}" -reconfigure .

    rm --preserve-root ${BACKEND_CONFIG_VARS_RENDERED}
    popd >/dev/null
}

function tf_apply () {
   
    local SOURCE_FOLDER="${1}"

    # Exits if folder does not exists
    [ -d ${SOURCE_FOLDER} ] || return 1

    pushd ${SOURCE_FOLDER} >/dev/null 
    ${TERRAFORMCMD} apply -no-color -input=false ${@:2} .
    popd >/dev/null
}

function tf_output () {
   
    local SOURCE_FOLDER="${1}"

    # Exits if folder does not exists
    [ -d ${SOURCE_FOLDER} ] || return 1

    pushd ${SOURCE_FOLDER} >/dev/null 
    ${TERRAFORMCMD} output ${@:2}
    popd >/dev/null
}

function tf_destroy () {

    local SOURCE_FOLDER="${1}"

    # Exits if folder does not exists
    [ -d ${SOURCE_FOLDER} ] || return 1

    pushd ${SOURCE_FOLDER} >/dev/null 
	${TERRAFORMCMD} destroy -input=false ${@:2} .
    popd >/dev/null
}

function tf_encrypt_secrets {

    local SOURCE_FOLDER="${1}"

    # Exits if folder does not exists
    [ -d ${SOURCE_FOLDER}/secrets ] || return 1

    # If we have the password set on the Vault we get the value
    if vault_has_value "TERRAFORM_MASTER_PASSWORD"; then
        eval $(vault_get_local_variable "TERRAFORM_MASTER_PASSWORD")
    else
        return 1
    fi

    for TF_VAR in $(find ${SOURCE_FOLDER}/secrets -type f -name *); do 
        is_encrypted ${TF_VAR} && continue
        cat "${TF_VAR}" | encrypt "${TERRAFORM_MASTER_PASSWORD}" > "${TF_VAR}.key" || continue
        rm --preserve-root "${TF_VAR}"
    done    
}
	
function tf_decrypt_secrets {

    local SOURCE_FOLDER="${1}"

    # Exits if folder does not exists
    [ -d ${SOURCE_FOLDER}/secrets ] || return 1

    # If we have the password set on the Vault we get the value
    if vault_has_value "TERRAFORM_MASTER_PASSWORD"; then
        eval $(vault_get_local_variable "TERRAFORM_MASTER_PASSWORD")
    else
        return 1
    fi

    local TMP_FILE=$(mktemp /tmp/tfXXXXX)

    for TF_VAR in $(find ${SOURCE_FOLDER}/secrets -type f -name *); do 
        is_encrypted ${TF_VAR} || continue
        cat "${TF_VAR}" | decrypt "${TERRAFORM_MASTER_PASSWORD}" >"${TMP_FILE}"
        cp "${TMP_FILE}" "${TF_VAR%.*}"
        rm --preserve-root "${TF_VAR}"
    done
}
