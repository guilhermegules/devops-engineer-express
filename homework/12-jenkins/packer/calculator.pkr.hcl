packer {
  required_plugins {
    docker = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/docker"
    }
  }
}

variable "image_name" {
  type    = string
  default = "calculator-microservice"
}

variable "tag" {
  type    = string
  default = "latest"
}

source "docker" "calculator" {
  build {
    path      = "${path.root}/../../07-docker/Dockerfile"
    build_dir = "${path.root}/../../.."
  }
  commit = true
}

build {
  sources = ["source.docker.calculator"]

  post-processor "docker-tag" {
    repository = var.image_name
    tags       = [var.tag]
  }
}
