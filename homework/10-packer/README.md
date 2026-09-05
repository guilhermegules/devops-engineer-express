# Homework 10 - Packer

Build a Docker image of the **Go calculator microservice** (from `../06-go`) using **HashiCorp Packer**.

Instead of building the Docker image with `docker build`, Packer manages the build, captures the resulting container as a committed image, and tags it as a versioned artifact. This is the same workflow used when baking images for other platforms (e.g. AWS AMIs, GCP Images) — Packer switches the builder while keeping the same config shape.

## Prerequisites

- [Packer](https://developer.hashicorp.com/packer/downloads) installed
- [Docker](https://docs.docker.com/get-docker/) up and running
- Go microservice source from `../06-go` and the `Dockerfile` from `../07-docker` (already present in this repo)

## How it works

The `calculator.pkr.hcl` template:

1. Declares the **docker** plugin (`github.com/hashicorp/docker`).
2. Defines a `docker` source that bootstraps the build from `../07-docker/Dockerfile` (the same Dockerfile used in Homework 07), with the repo root (`../..`) as build directory/context.
3. Sets `commit = true`, so Packer commits the resulting container into an image.
4. Applies a `docker-tag` post-processor to tag the artifact with the desired version.

## Usage

### Format and validate the template

```bash
packer fmt calculator.pkr.hcl
packer validate calculator.pkr.hcl
```

### Build the image

```bash
packer build calculator.pkr.hcl
```

### Build with a custom tag

```bash
packer build -var tag=v1.0.0 calculator.pkr.hcl
```

### Verify the resulting image

```bash
docker images | grep calculator
docker run --rm -p 8080:8080 calculator:latest
```

Then exercise the microservice:

```bash
curl http://localhost:8080/calc/sum/2/3
curl http://localhost:8080/calc/mul/4/5
curl http://localhost:8080/calc/history
```

## Configuration Reference

| Setting | Value | Description |
|---|---|---|
| `required_plugins.docker` | `github.com/hashicorp/docker` `>= 1.1.0` | Docker builder plugin (Dockerfile bootstrap support since v1.1.0) |
| `source.docker.calculator.build.path` | `../07-docker/Dockerfile` | Multi-stage Dockerfile from Homework 07 |
| `source.docker.calculator.build.build_dir` | `../..` | Directory `docker build` runs from (repo root, so `homework/06-go/*` is reachable) |
| `source.docker.calculator.commit` | `true` | Commit the running container into an image artifact |
| `post-processor "docker-tag"` | `calculator` / `var.tag` | Tags the final artifact with the version |

## Variables

| Variable | Default | Description |
|---|---|---|
| `tag` | `latest` | Version tag applied to the produced image |

Override it with `-var tag=<value>` as shown above, or via a `.pkrvars.hcl`/`.pkrvars.json` file.

## Troubleshooting

- **Plugin download fails**: run `packer init calculator.pkr.hcl` to install the required plugins before building.
- **Docker daemon not reachable**: make sure Docker is running (`docker info`).
- **Build context errors**: run Packer from the `homework/10-packer` directory so the relative paths (`../07-docker/Dockerfile`, `../..`) resolve correctly.