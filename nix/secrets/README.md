# Encrypted secrets

`ntfy-admin.age` stores ntfy's administrator username, password, and server URL as an
age-encrypted JSON document. `agenix-rules.nix` derives its recipients from the SSH public
keys in `../public_keys/`. Each corresponding private key can decrypt the credentials.

## Recover ntfy credentials

From the repository root, decrypt using an authorized private SSH key:

```sh
age --decrypt --identity ~/.ssh/id_ed25519 nix/secrets/ntfy-admin.age
```

The command prints the credentials to your terminal. To recover to the ignored local file
instead, set restrictive permissions before writing:

```sh
mkdir -p generated
(umask 077; age --decrypt --identity ~/.ssh/id_ed25519 \
  nix/secrets/ntfy-admin.age > generated/ntfy-admin.json)
chmod 0600 generated/ntfy-admin.json
```

Use the private key that corresponds to an authorized recipient. Listing a hardware-backed
SSH public key as a recipient does not make its private key available as an ordinary SSH
identity file.

## Update recipients

Changing public-key files updates the rules but does not change existing ciphertext.
After changing keys, re-encrypt with an identity that can still decrypt the current file.
With the agenix CLI available:

```sh
cd nix/secrets
agenix --rekey --identity ~/.ssh/id_ed25519
```

Review and commit the rules, public-key changes, and re-encrypted file together. Removing
a recipient does not revoke access to earlier ciphertext; rotate the password if access
to old credentials must be revoked.

## Credential rotation

Editing this encrypted file does not update ntfy's password. Rotation must update both
`ntfy-admin.age` and the password hash in `apps/ntfy/auth.sealed.yaml`, followed by an
authorized deployment and restart of ntfy.

This file is for credential recovery and is not mounted into the service. ntfy continues
to use its SealedSecret for authentication. The existing `k3s-cluster-token.age` is managed
separately and is not included in these agenix rules.
