FROM jenkins/jenkins:lts-jdk17

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       docker-cli \
       curl \
       unzip \
    && rm -rf /var/lib/apt/lists/*

ARG PACKER_VERSION=1.11.2
RUN curl -fsSL "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip" \
        -o /tmp/packer.zip \
    && unzip /tmp/packer.zip -d /usr/local/bin \
    && rm /tmp/packer.zip

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt \
        --plugin-download-directory /usr/share/jenkins/ref/plugins

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

COPY init.groovy.d/ /usr/share/jenkins/ref/init.groovy.d/

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]