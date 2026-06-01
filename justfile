set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

_default:
    @just --list

tf-init:
    terraform -chdir=terraform/proxmox init

tf-fmt:
    terraform -chdir=terraform/proxmox fmt -check

tf-validate:
    terraform -chdir=terraform/proxmox validate

tf-plan: tf-fmt tf-validate
    terraform -chdir=terraform/proxmox plan

tf-apply:
    terraform -chdir=terraform/proxmox apply

template-build:
    nix build .#proxmox-cloud-init-template

template-register id name:
    scripts/register-proxmox-template {{id}} {{name}}

colmena-apply host:
    nix develop --no-write-lock-file -c colmena --impure apply --on {{host}} --no-build-on-target --no-substitute

bootstrap-control-plane:
    scripts/bootstrap-control-plane

bootstrap-workers:
    scripts/bootstrap-workers

bootstrap-cluster: bootstrap-control-plane bootstrap-workers

kubeconfig:
    scripts/get-kubeconfig

nix-flake-check:
    nix flake check --no-write-lock-file
