# Infra Tools

- Set of script and tools to help on infrastructure management

# Installation

Add the following entry to your .bashrc file
```
source <project_location>/automash.bash
```

# Creating a project

Command:
- create_project <```project name```> -> create a project in the current directory


# A common project structure

```
├── resources 
│   └── <local resources>
├── ssh-keys
│   └── <context>
│       ├── id_rsa
│       └── id_rsa.pub
├── terraform
│   ├── <terraform project>
│   │   ├── backend
│   │   │   └── config.tfvars
│   │   ├── backend.tf
│   │   ├── provider.tf
│   │   ├── main.tf
│   │   └── vars
│   │       ├── main.tfvars
│   │       └── secrets.tfvars
│   └── modules 
│       └── < local terraform modules >
├── playbooks
│   ├── roles
│   │       └── <ansible roles here>
│   └── < playbooks here >
├── ansible.cfg
├── hosts
├── project.rc
├── Readme.MD
├── repository.vault
└── ssh.cfg
```

# Project config file 

You might change the structure above you just need to set ```project.rc``` to reflect the changes

```
ANSIBLE_INVENTORY="hosts"
ANSIBLE_PLAYBOOKS="playbooks"
TERRAFORM_PROJECTS="terraform"
SSH_KEYS="ssh-keys"
```

# SSH configuration

```ssh.cfg``` : A simple ssh config file that will be used by ansible. Useful for cases with proxy jumps.

# Ansible configuration

```ansible.cfg``` : Ansible configuration file
```hosts``` : Ansible inventory

# Password vault

The vault use an environment variable called ```VAULT_MASTER_PASSWORD```, to use it always set this variable before running any command.

Available commands:
- get <```name```> : show password
- set <```name```> <```value```> : set password
- list : list passwords
- clip <```name```> : copy to clipoard

## Using secrets in terraform

Inside the ```vars``` folder create a tfvars file with this header

```
#VAULT - Don't remove this or this file will not be processed
```

Examples of using secrets:

```
aws_access_key="$(vault_get_quoted_value AWS_ACCESS_KEY)"
aws_secret_key="$(vault_get_quoted_value AWS_SECRET_KEY)"
mysql_root_password="$(vault_get_quoted_value MYSQL_ROOT_PASSWORD)"
mysql_wordpress_password="$(vault_get_quoted_value MYSQL_WORDPRESS_PASSWORD)"
```

## Using secrets in ansible

Needs documentation

# Terraform

Commands:
- tf_create <```project name```> 
- tf_apply <```project name```> <```terraform options```>
- tf_destroy <```project name```> <```terraform options```>

# Ansible

Commands:
- ansible_run <```target name```> <```playbook name```> <```ansible options```>


