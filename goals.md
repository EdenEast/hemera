# Hemera

This project contains my homelab configuration. It is both a useful way to host and manage my internal services but also
a concrete example of me using devops concepts that I can point to on my resume and interview.

## Goals

1. A place to host and manage my homelab and local selfhosted services
2. A resume example to show that I have relevant devops experience as I am also running this at home
3. A playground to learn devops concepts and principles

## Tools and areas of study

1. Kubernetes management and orchestration
2. terraform
3. monitoring and alerting dashboard with pagers

## Physical machines and infrastructure

I do not want to pay for any cloud services to everything will be run and executed on my own hardware. Unfortunately hardware is currently unfathomably expensive so I will have to make do with what I have.

- Truenas
  - 5x3TB HDD in zfs pool
  - 8GB RAM
  - 256GB boot drive
- Old desktop computer (thor)
  - i7-3770S CPU @ 3.10GHz
  - 16 GB of RAM
  - 1TB SSD

## Initial concepts

Taking into account my goals in physical machine and infrastructure constraints. My initial idea is to use the old desktop computer as a Proxmox host and have multiple either VMs or LXE containers to run Kubernetes master and worker nodes. This would create my cluster in Proxmox. Eventually when I can afford or find more machines, I can move the cluster off a single Proxmox machine with VMs to multiple physical machines as the nodes.

To set up the machines and Proxmox containers I would like to use Terraform to learn more about it.

I am not sure what everything entails to create in cluster and all the components required. This will have to be fleshed out during a research / structure phase.

## Future Goals

This is something to review in the future but all of these services (Kubernetes, terraform, etc...) use yaml as their format and are not very reproducible. Finding all the places where I can incorporate `nix` would be a useful endeavour.

Some useful links for later

- https://github.com/Lillecarl/nix-csi
- https://github.com/Lillecarl/easykubenix

## Why the Name?

Hemera is the goddess of day and is the daughter of Nyx the goddess of night which is also my nixos system
configuration so it is fitting.
