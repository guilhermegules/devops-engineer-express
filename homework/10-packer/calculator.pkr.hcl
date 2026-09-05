packer {
  required_plugins {
    docker = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/docker"
    }
  }
}

variable "tag" {
  type    = string
  default = "latest"
}

source "docker" "calculator" {
  build {
    path      = "../07-docker/Dockerfile"
    build_dir = "../.."
  }
  commit = true
}

build {
  sources = ["source.docker.calculator"]

  post-processor "docker-tag" {
    repository = "calculator"
    tags       = [var.tag]
  }
}