Homework [0-Lean.Agile]
========================

### 1. Agile methods (excluding XP and Scrum)

**Kanban:** Visualizes the workflow on a board (e.g. To Do / Doing / Done), limits work-in-progress (WIP) to avoid overload, and pulls new work only when there is capacity. It makes bottlenecks visible and enables continuous, incremental delivery without fixed time-boxed iterations.

**Lean Software Development:** Derived from the Lean/Toyota Production System. It focuses on eliminating waste, amplifying learning, deciding as late as possible, delivering as fast as possible, empowering the team, and building quality in. Value is defined from the customer's perspective and the process is continuously improved.

**Crystal:** A family of methodologies (Crystal Clear, Yellow, Orange, etc.) tuned by team size and project criticality. It emphasizes communication, simplicity, and frequent delivery, applying a set of properties (frequent delivery, reflective improvement, etc.) with policies weighted to the project context.

**Feature-Driven Development (FDD):** Iterative and incremental, built around a domain object model. It follows 5 processes: develop overall model, build feature list, plan by feature, design by feature, and build by feature. Small client-valued features are designed and built in short 2-week cycles.

**Dynamic Systems Development Method (DSDM):** A framework based on the Pareto principle (80% of value comes from 20% of effort). Time, cost, and quality are fixed, and requirements are prioritized so the most important features are delivered first through time-boxed iterations with active user involvement.

**Adaptive Software Development (ASD):** Built around three phases: speculate, collaborate, and learn. Instead of rigid planning, teams speculate about the future, collaborate closely, and continuously learn and adapt, embracing constant change.

**Agile Unified Process (AUP):** A simplified version of the Rational Unified Process (RUP) adapted for agile teams. It runs four disciplines (model, implementation, test, deployment) in an iterative cycle, focused on simplicity, agility, and continuous feedback.

### 2. Issues with "Agile"

Agile, when applied as a rigid framework or "cargo cult", becomes counterproductive: teams perform ceremonies (stand-ups, sprints, retrospectives) without the underlying mindset of collaboration, feedback, and continuous improvement, ending up with "Water-Scrum-Fall" and extra bureaucracy. Without frequent delivery of working software, agile is just a way to hide bad planning. Metrics such as story points and velocity are often used to push people, recreating micromanagement and blame culture. Agile is also misused as an excuse for no planning or no documentation, producing chaos, rework, and technical debt. Finally, organizations keep silos and command-and-control cultures, so agile at the team level never changes how value flows, leading to frustration and failure at scale.

### 3. Relation of Agile / Lean, Bi-Modal and DevOps

Agile, Lean, Bi-Modal, and DevOps are distinct but related movements attacking the same problem: delivering value faster and more reliably. Agile focuses on the development team, improving how requirements are handled and delivered in small iterations with feedback. Lean widens the view to the whole value stream, removing waste and optimizing flow. DevOps breaks the wall between Dev and Ops, automating delivery pipelines (CI/CD) so software reaches production quickly, safely, and continuously. Bi-Modal is an enterprise governance model that separates IT into Mode 1 (stable and traditional) and Mode 2 (agile and exploratory) to balance stability and speed. They are complementary: Agile is the team practice, Lean is the value-stream optimization, DevOps is the organizational/cultural bridge that makes continuous delivery real, and Bi-Modal is a governance attempt to let both worlds coexist. DevOps effectively unifies agile delivery with operations, and Lean principles (small batches, flow, feedback) support all of them.