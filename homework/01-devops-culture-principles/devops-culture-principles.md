# Homework 1 - DevOps Culture Principles

## 1. IF I'm doing deploy automation? I'm doing devops? Explain why is true or false?

**True.** Deploy automation is a core practice of DevOps. DevOps is not just about tools but about a culture of collaboration between development and operations teams. Automating deployments breaks down silos, enables faster feedback loops, reduces human error, and allows teams to release software more frequently and reliably. The automation of deployments embodies the DevOps principle of "delivering fast" while maintaining quality and stability.

## 2. How do we improve the reliability of a system? (Tip: Look for SRE)

**We improve system reliability by adopting Site Reliability Engineering (SRE) principles:**

- **Error budgeting** - Define acceptable levels of unreliability and use them to balance feature velocity with stability
- **Service Level Objectives (SLOs)** and **Service Level Indicators (SLIs)** - Measure and track reliability goals quantitatively
- **Automated testing** - Include unit, integration, and end-to-end tests in CI/CD pipelines
- **Chaos engineering** - Introduce controlled failures to identify weaknesses
- **Incident management** - Establish clear processes for responding to and learning from outages
- **Observability** - Implement comprehensive monitoring, logging, and tracing to understand system behavior
- **Gradual rollouts** - Use canary deployments and feature flags to limit risk
- **Postmortem culture** - Focus on blameless analysis and systemic improvements rather than individual blame

## 3. Research about Postmortem and list the basic elements of a post-mortem analysis/report

**Basic elements of a post-mortem analysis/report:**

1. **What happened** - Clear description of the incident, including timings and impact
2. **Timeline** - Chronological account of events from detection to resolution
3. **Root cause analysis** - Identification of the fundamental cause(s), not just symptoms
4. **Impact assessment** - Description of how the incident affected users and systems
5. **Actions taken** - Steps taken to mitigate and resolve the incident
6. **Preventive actions** - Long-term fixes to prevent recurrence
7. **What was learned** - Key takeaways and insights gained
8. **Action items** - Specific, measurable tasks with owners and deadlines
9. **Blameless approach** - Focus on systems and processes, not individual fault
10. **Follow-up** - Verification that fixes are effective and monitoring is updated