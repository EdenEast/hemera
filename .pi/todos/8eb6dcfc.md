{
"id": "8eb6dcfc",
"title": "Document Initial Setup operational safety checks",
"tags": [
"ready-for-agent"
],
"status": "closed",
"created_at": "2026-05-20T16:31:39.201Z"
}

## Parent

TODO-e9b3507c

## What to build

Document the safety-critical operational expectations for Initial Setup: Terraform state handling, generated file handling, secret handling, and VM template identity validation.

## Acceptance criteria

- [x] Terraform state and manual TrueNAS backup expectations are documented.
- [x] Generated outputs, decrypted secrets, age private keys, and kubeconfigs are documented as excluded from git.
- [x] The VM template identity checklist explains how to confirm cloned Cluster Nodes do not share SSH host keys or `/etc/machine-id`.

## Completed

- Added Operational Safety Checks to `docs/initial-setup.md`.
- Documented files/material that must stay out of git.
- Documented manual TrueNAS backup expectation for local Terraform state.
- Added SSH host key and machine-id uniqueness validation commands.
