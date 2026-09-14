# Homework 12 - Jenkins

This homework creates a Jenkins pipeline for the **Go calculator microservice** (from `../06-go`). Following the assignment (see `12-Jenkins.txt`), the pipeline has two stages that are also available as standalone shell scripts:

- **BAKE**: uses **Packer** to bake a Docker image of the microservice.
- **LAUNCH**: deploys the baked image as a **Docker** container.

## Files

| File | Description |
|---|---|
| `Jenkinsfile` | Declarative Jenkins pipeline with the `BAKE` and `LAUNCH` stages |
| `bake.sh` | Standalone script that bakes the Docker image with Packer |
| `launch.sh` | Standalone script that stops/starts the microservice container |
| `packer/calculator.pkr.hcl` | Packer template used to bake the image |
| `12-Jenkins.txt` | The homework assignment statement |

## Prerequisites

- [Jenkins](https://www.jenkins.io/doc/book/installing/) running (see `../../source/jenkins/run-jenkins-docker.sh` for a quick Docker-based Jenkins)
- Jenkins user must have permissions to run `docker` and `packer` commands
- [Packer](https://developer.hashicorp.com/packer/downloads) installed on the Jenkins agent
- [Docker](https://docs.docker.com/get-docker/) up and running
- Go microservice source (`../06-go`) and `Dockerfile` (`../07-docker`) present in the repo

## Scripts

### `bake.sh`

Bakes the Docker image with Packer using `packer/calculator.pkr.hcl`.

```bash
./bake.sh [IMAGE_NAME] [TAG]
```

- `IMAGE_NAME` – image name to bake (default: `calculator-microservice`)
- `TAG` – version tag to apply (default: `latest`)

It runs `packer init` (installs plugins) followed by `packer build -var image_name=... -var tag=...`, then lists the resulting image.

### `launch.sh`

Deploys the microservice as a Docker container.

```bash
./launch.sh [IMAGE_NAME] [CONTAINER_NAME] [PORT]
```

- `IMAGE_NAME` – image to run (default: `calculator-microservice`, always uses the `latest` tag)
- `CONTAINER_NAME` – container name (default: `calculator-microservice`)
- `PORT` – host/container port (default: `8080`)

It stops and removes any existing container with the same name, fails if the image was not baked yet, then starts the container and prints the URL.

Example end-to-end flow:

```bash
./bake.sh
./launch.sh
curl http://localhost:8080/calc/sum/2/3
```

## Jenkinsfile

The `Jenkinsfile` is a declarative pipeline mirroring the two scripts:

1. **BAKE** – `packer init` + `packer build` for `homework/12-jenkins/packer/calculator.pkr.hcl`, baking `calculator-microservice:latest`.
2. **LAUNCH** – stops/removes any previous container, then runs `docker run -d --name calculator-microservice -p 8080:8080 calculator-microservice:latest`.

The `post` block prints whether the run succeeded or failed.

### Running it in Jenkins

1. Create a **Pipeline** job.
2. Point **SCM** at this repository, or paste the `Jenkinsfile` content into the **Script** field.
3. Make sure the working directory of the repo is the root (paths like `homework/12-jenkins/packer/...` are resolved from the repo root).
4. Trigger a build. After `LAUNCH` succeeds, the microservice is reachable at:

   ```
   http://localhost:8080/calc/sum/2/3
   ```

## Troubleshooting

- **Image not found on LAUNCH**: run the `BAKE` stage/script first so `calculator-microservice:latest` exists.
- **Packer plugin download fails**: run `packer init` (the `bake.sh` script and the `BAKE` stage already do this).
- **Docker daemon not reachable**: make sure Docker is running and the Jenkins user has `docker` access.
- **Port already in use**: stop/remove the old container or pass a different `PORT` to `launch.sh`.