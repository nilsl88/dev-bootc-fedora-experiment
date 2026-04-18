# agent.md

## Purpose

This repository documents and builds a Fedora `bootc` image with Caddy, then converts that image into bootable artifacts such as:

- `qcow2`
- `iso`
- `anaconda-iso` with Kickstart and XFS
- `anaconda-iso` with Kickstart and Btrfs

The repo is mainly documentation plus build inputs. It is not a traditional application codebase.

## Important Files

- `Containerfile`
  Builds the source bootc container image.
- `Caddyfile`
  Caddy configuration copied into the image.
- `wheel-passwordless-sudo`
  Sudoers drop-in installed into the image.
- `config.toml`
  Customizations for `qcow2` builds.
- `config-iso.toml`
  Customizations for `--type iso`.
- `config-kickstart.toml`
  Kickstart-based `anaconda-iso` config using XFS/LVM.
- `config-kickstart-btrfs.toml`
  Kickstart-based `anaconda-iso` config using Btrfs.
- `README.md`
  Main user-facing documentation. Read this before changing commands or workflow text.
- `output/`
  Generated artifacts such as manifests and disk images. Treat as build output, not source.

## Current Image And Tag Conventions

The README currently uses these example image references:

- source image: `docker.io/l88repo/dev-bootc:fedora-43-caddy-v1`
- example updated tag: `docker.io/l88repo/dev-bootc:fedora-43-caddy-v2`

When changing image tags in docs, update all related examples consistently.

## Repo Rules For Agents

1. Read `README.md` before editing docs or build commands.
2. Keep commands copy-pasteable.
3. Preserve the distinction between source image builds and artifact builds.
4. Do not mix `[[customizations.user]]` with `[customizations.installer.kickstart]` in the same config.
5. Keep `qcow2` guidance tied to `config.toml`.
6. Keep `iso` guidance tied to `config-iso.toml`.
7. Keep Kickstart installer ISO guidance tied to `config-kickstart.toml` or `config-kickstart-btrfs.toml`.
8. Treat `output/` as generated content unless the user explicitly wants artifacts committed.

## Build Workflow Summary

### 1. Build The Source OCI Image

Typical example:

```bash
sudo podman build -t docker.io/l88repo/dev-bootc:fedora-43-caddy-v1 .
sudo podman push docker.io/l88repo/dev-bootc:fedora-43-caddy-v1
```

### 2. Pre-Pull Helper Images

Artifact builds in this repo currently assume these are present:

```bash
sudo podman pull quay.io/curl/curl:latest
sudo podman pull quay.io/curl/curl-base:latest
sudo podman pull quay.io/centos-bootc/bootc-image-builder:latest
sudo podman pull registry.access.redhat.com/ubi9/podman:latest
```

### 3. Build Artifacts

- `qcow2` uses `config.toml`
- `iso` uses `config-iso.toml`
- `anaconda-iso` XFS uses `config-kickstart.toml`
- `anaconda-iso` Btrfs uses `config-kickstart-btrfs.toml`

Artifact builds use the root Podman store via:

```bash
-v /var/lib/containers/storage:/var/lib/containers/storage
```

Do not casually remove that from documented commands.

## Day 2 Operations Summary

On a booted VM or bare-metal host, the README documents these operations:

- `bootc status`
- `bootc status --verbose`
- `bootc upgrade`
- `bootc upgrade --download-only`
- `bootc upgrade --from-downloaded --apply`
- `bootc switch <image>`
- `bootc rollback`
- `bootupctl update`

Keep those examples aligned with current README wording unless the user explicitly wants a different workflow.

## Documentation Style

- Prefer short, practical explanations.
- Keep sections task-oriented.
- Prefer exact image references over vague placeholders unless the section is clearly generic.
- If you change one command example, scan the rest of the README for matching tag/version updates.

## Safety Notes

- The config files currently contain demo credentials. Do not replace them with real secrets.
- If adding examples with SSH keys, use placeholders unless the repo owner explicitly wants a real public key shown.
- Large generated artifacts in `output/` may not belong in Git.

## When Editing This Repo

- If you touch `Containerfile`, re-check whether README examples still match the image behavior.
- If you touch config files, re-check the corresponding README build section.
- If you change the image tag naming scheme, update both build and Day 2 sections.
