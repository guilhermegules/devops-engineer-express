FROM jenkins/jenkins:lts-jdk17

USER root

# Maven runs the Gatling simulation. Debian's maven is 3.8.x, above Gatling's 3.6.3 minimum.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       maven \
       curl \
    && rm -rf /var/lib/aptlists/*

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt \
        --plugin-download-directory /usr/share/jenkins/ref/plugins

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

COPY init.groovy.d/ /usr/share/jenkins/ref/init.groovy.d/

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]