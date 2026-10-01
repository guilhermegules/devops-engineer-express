#!groovy
import jenkins.model.Jenkins
import jenkins.install.InstallState
import hudson.security.HudsonPrivateSecurityRealm
import hudson.security.FullControlOnceLoggedInAuthorizationStrategy
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition
import org.jenkinsci.plugins.scriptsecurity.scripts.ScriptApproval
import org.jenkinsci.plugins.scriptsecurity.scripts.languages.GroovyLanguage

def instance = Jenkins.instance

if (instance.installState != InstallState.INITIAL_SETUP_COMPLETED) {
    instance.installState = InstallState.INITIAL_SETUP_COMPLETED
}

if (!(instance.getSecurityRealm() instanceof HudsonPrivateSecurityRealm)) {
    def realm = new HudsonPrivateSecurityRealm(false)
    realm.createAccount('admin', 'admin')
    instance.setSecurityRealm(realm)
}

instance.setAuthorizationStrategy(new FullControlOnceLoggedInAuthorizationStrategy())
instance.save()

// Seed the pipeline job from the mounted Jenkinsfile
def jobName = 'calculator-stress-test'
def seedWs = new File(instance.getRootDir(), "workspace/${jobName}")
def jenkinsfile = new File(seedWs, 'homework/16-stress-test-chaos/Jenkinsfile')

if (jenkinsfile.exists()) {
    def wf = instance.getItem(jobName)
    if (wf == null) {
        wf = instance.createProject(WorkflowJob, jobName)
    }
    wf.definition = new CpsFlowDefinition(jenkinsfile.text, true)
    wf.save()
    instance.save()

    // Pre-approve the CPS script so builds don't stall on manual approval
    ScriptApproval.get().preapprove(jenkinsfile.text, GroovyLanguage.get())
} else {
    println "[seed] Jenkinsfile not found at ${jenkinsfile.absolutePath}"
}