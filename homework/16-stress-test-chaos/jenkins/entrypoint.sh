#!/bin/sh
set -e

JENKINS_HOME="${JENKINS_HOME:-/var/jenkins_home}"
JOB_NAME="calculator-stress-test"

if [ ! -f "$JENKINS_HOME/.ref-copied" ]; then
    echo "Copying init.groovy.d scripts..."
    mkdir -p "$JENKINS_HOME/init.groovy.d"
    cp -rn /usr/share/jenkins/ref/init.groovy.d/* "$JENKINS_HOME/init.groovy.d/" 2>/dev/null || true

    echo "Copying bundled plugins..."
    mkdir -p "$JENKINS_HOME/plugins"
    cp -rn /usr/share/jenkins/ref/plugins/* "$JENKINS_HOME/plugins/" 2>/dev/null || true

    touch "$JENKINS_HOME/.ref-copied"
fi

# The pipeline job is created from a script, not from an SCM checkout, so its workspace
# is seeded from the repository bind mount. Everything the build writes (target/, reports)
# stays inside JENKINS_HOME and never reaches the bind mount.
JOB_WS="$JENKINS_HOME/workspace/$JOB_NAME"
if [ -d /workspace ] && [ ! -d "$JOB_WS/homework" ]; then
    echo "Seeding '${JOB_NAME}' workspace with the repository..."
    mkdir -p "$JOB_WS"
    cp -a /workspace/. "$JOB_WS/"
fi

echo "Starting Jenkins..."
exec java $JAVA_OPTS -jar /usr/share/jenkins/jenkins.war $JENKINS_OPTS