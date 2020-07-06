FROM python:3.8.1-slim

ENV VAULT_MASTER_PASSWORD=""

COPY requirements.txt /tmp

RUN apt-get update && apt upgrade -y \
    && apt-get install --no-install-recommends -y \
    # deps for installing poetry
    wget p7zip-full && \
    cd /usr/local/bin && \
    wget -O /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.12.28/terraform_0.12.28_linux_amd64.zip && \
    7z x /tmp/terraform.zip && rm /tmp/terraform.zip && \
    pip install -r /tmp/requirements.txt && \
    mkdir -p /app/infratools/bin /app/app/infratools/lib /app/infratools/resources && \
    rm -rf /var/lib/apt/lists && rm /tmp/requirements.txt

COPY ./bin /app/infratools/bin/
COPY ./lib /app/infratools/lib/
COPY ./resources /app/infratools/resources/
COPY infra-tools.bash /app/infratools

WORKDIR /app
