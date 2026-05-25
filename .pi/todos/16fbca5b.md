{
"id": "16fbca5b",
"title": "Prepare NixOS Proxmox template build guidance",
"tags": [
"ready-for-agent"
],
"status": "closed",
"created_at": "2026-05-20T16:31:39.201Z"
}

## Parent

TODO-e9b3507c

## What to build

Prepare the repository guidance or configuration needed to create the reusable NixOS Proxmox VM template for Initial Setup once Thor runs Proxmox.

## Acceptance criteria

- [x] The preferred Nix-based template creation path is documented or scaffolded.
- [x] The fallback official NixOS cloud-image path is documented.
- [x] Baseline template expectations are listed without baking per-node hostname, static IP, k3s role, SSH host keys, or machine identity into the template.

## Completed

- Added `docs/nixos-proxmox-template.md` with preferred Nix tooling path, fallback cloud-image path, baseline template expectations, and identity validation commands.
- Linked the template guide from the Initial Setup runbook.
