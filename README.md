# dev-bootc-fedora

Fedora `bootc` experiment for building a bootable container image with Caddy and converting it into:

- `qcow2`
- `iso`
- `anaconda-iso` with Kickstart and XFS
- `anaconda-iso` with Kickstart and Btrfs

This repository is a write-up of working with bootc and the working commands that came out of it.

## What This Image Does

The source image is built from:

```Dockerfile
FROM ghcr.io/bootc-dev/dev-bootc:fedora-43
```

The image includes a working Caddy web server and is intended to be converted into bootable artifacts with `bootc-image-builder`.

![Docker Image Size](https://img.shields.io/docker/image-size/l88repo/dev-bootc/fedora-43-caddy-v2?logo=docker&label=image%20size)
| Architecture | Available | Tag |
| :----: | :----: | ---- |
| x86-64 | ✅ | \<version tag\> |
| arm64 | ✅ | \<version tag\> |
| armhf | ❌ | |

## Notes From The Experiment

- `bootc-image-builder` converts a bootc container image into bootable artifacts such as `qcow2`, `iso`, and `anaconda-iso`.
- `config.toml` is the right fit for disk-image outputs like `qcow2` when you want `[[customizations.user]]` and `[[customizations.filesystem]]`.
- `config-kickstart.toml` and `config-kickstart-btrfs.toml` are the right fit when you want to control installed partitioning and filesystem layout through Kickstart.
- The demo password in the config files is only for testing. Do not use a real plaintext password in Git.

## Reference Links

- bootc docs: <https://bootc.dev/bootc/>
- bootc-image-builder: <https://github.com/osbuild/bootc-image-builder>
- Fedora bootc getting started: <https://docs.fedoraproject.org/en-US/bootc/getting-started/>
- dev-bootc container package: <https://github.com/bootc-dev/bootc/pkgs/container/dev-bootc>
- bootc review notes: <https://github.com/bootc-dev/bootc/blob/main/REVIEW.md>
- Youtube: Setting Up Bootc with Red Hat Satellite: A Guide to Bootable Container Images: <https://www.youtube.com/watch?v=7d8DqlDuwJU>
- Using image mode for RHEL to build, deploy, and manage operating systems: <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html-single/using_image_mode_for_rhel_to_build_deploy_and_manage_operating_systems/index>
- Intro - Image mode for Red Hat Enterprise Linux <https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux-10/image-mode>
- Interactive labs - `Introduction to image mode for Red Hat Enterprise Linux`, `Day 2 operations with image mode for Red Hat Enterprise Linux`: <https://www.redhat.com/en/interactive-labs/enterprise-linux#build>

## Prerequisites

- Fedora, RHEL, CentOS Stream, or another Linux host with Podman
- root access for artifact builds
- enough disk space for `./output` and intermediate artifacts, around 10 GB or more
- a registry login if you want to push the source image to a container registry such as Docker Hub

Clone the repo and create the output directory:

```bash
git clone git@github.com:nilsl88/dev-bootc-fedora-experiment.git
cd dev-bootc-fedora-experiment
mkdir -p output
```

## Build The Source OCI Image

Build the bootc source image into the root Podman store:

```bash
sudo podman build -t docker.io/l88repo/dev-bootc:fedora-43-caddy-v1 .
```

Optional push:

```bash
sudo podman push docker.io/l88repo/dev-bootc:fedora-43-caddy-v1
```

If you built the source image without `sudo`, make sure you still pull it into the root store before running `bootc-image-builder`:

```bash
sudo podman pull docker.io/l88repo/dev-bootc:fedora-43-caddy-v1
```

## Multi-Arch Source Image Examples

### Option 1: Build Separate `amd64` and `arm64` Images

This is the simplest way to build per-architecture source images:

```bash
sudo podman build \
  --platform linux/amd64 \
  -t docker.io/l88repo/dev-bootc:fedora-43-caddy-v1-amd64 .

sudo podman build \
  --platform linux/arm64 \
  -t docker.io/l88repo/dev-bootc:fedora-43-caddy-v1-arm64 .
```

Push them if needed:

```bash
sudo podman push docker.io/l88repo/dev-bootc:fedora-43-caddy-v1-amd64
sudo podman push docker.io/l88repo/dev-bootc:fedora-43-caddy-v1-arm64
```

### Option 2: Build One Multi-Arch Manifest (recommended)

Podman can build a single manifest list for `amd64` + `arm64`:

```bash
MANIFEST='docker.io/l88repo/dev-bootc:fedora-43-caddy-v2'
sudo podman build \
  --platform linux/amd64,linux/arm64 \
  --manifest $MANIFEST .

sudo podman manifest push --all \
  $MANIFEST \
  docker://$MANIFEST
```

Note:

- multi-arch builds with `RUN` instructions require cross-architecture emulation on the build host
- when building multiple platforms, use `--manifest` instead of `-t`


## Build the image for hypervisor and bare metal boot

Pre-pull the required helper images:

```bash
sudo podman pull quay.io/curl/curl:latest
sudo podman pull quay.io/curl/curl-base:latest
sudo podman pull quay.io/centos-bootc/bootc-image-builder:latest
sudo podman pull registry.access.redhat.com/ubi9/podman:latest
```

## Build `qcow2`

`config.toml` is used here for the user plus filesystem sizing.

```bash
sudo podman run --rm -it --privileged \
  --pull=newer \
  --security-opt label=type:unconfined_t \
  -v ./config.toml:/config.toml:ro \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 \
  --use-librepo=True \
  --rootfs btrfs \
  --config /config.toml \
  docker.io/l88repo/dev-bootc:fedora-43-caddy-v1
```

## Build `ISO`

`config-iso.toml` is used here for ISO metadata plus a user definition.

```bash
sudo podman run --rm -it --privileged \
  --pull=newer \
  --security-opt label=type:unconfined_t \
  -v ./config-iso.toml:/config.toml:ro \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type iso \
  --use-librepo=True \
  --rootfs btrfs \
  --config /config.toml \
  docker.io/l88repo/dev-bootc:fedora-43-caddy-v1
```

## Build `Kickstart ISO With XFS`

`config-kickstart.toml` embeds a Kickstart file that creates:

- `/boot/efi` as EFI
- `/boot` as `ext4`
- one LVM PV using the remaining disk
- `/` as XFS on an LVM logical volume

```bash
sudo podman run --rm -it --privileged \
  --pull=newer \
  --security-opt label=type:unconfined_t \
  -v ./config-kickstart.toml:/config.toml:ro \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type anaconda-iso \
  --use-librepo=True \
  --rootfs xfs \
  --config /config.toml \
  docker.io/l88repo/dev-bootc:fedora-43-caddy-v1
```

## Build `Kickstart ISO With Btrfs`

`config-kickstart-btrfs.toml` embeds a Kickstart file that creates:

- `/boot/efi` as EFI
- `/boot` as `ext4`
- the rest of the disk as `btrfs`
- `/` as a Btrfs subvolume

```bash
sudo podman run --rm -it --privileged \
  --pull=newer \
  --security-opt label=type:unconfined_t \
  -v ./config-kickstart-btrfs.toml:/config.toml:ro \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type anaconda-iso \
  --use-librepo=True \
  --rootfs btrfs \
  --config /config.toml \
  docker.io/l88repo/dev-bootc:fedora-43-caddy-v1
```

## Quick Verification

Check what landed in the output directory:

```bash
find ./output -maxdepth 3 -type f | sort
```

Verify the source image contains Caddy and the service symlink:

```bash
sudo podman run --rm --entrypoint bash \
  docker.io/l88repo/dev-bootc:fedora-43-caddy-v1 \
  -lc '
    rpm -q caddy &&
    test -f /etc/caddy/Caddyfile &&
    test -L /usr/lib/systemd/system/multi-user.target.wants/caddy.service &&
    echo "caddy installed and enabled in image"
  '
```

## Day 2 Operations

Day 2 operations for `bootc` usually have two sides:

- update and publish a new image in the registry
- upgrade, switch, or roll back on the booted VM or bare-metal host

### Update The Image And Push It To The Registry

After you change the `Containerfile`, Caddy config, or other image content, build a new image and push it.

Example with a new tag:

```bash
NEW_TAG='docker.io/l88repo/dev-bootc:fedora-43-caddy-v2'

sudo podman build -t $NEW_TAG .
sudo podman push $NEW_TAG
```

If your booted systems are already tracking a fixed tag such as `fedora-43-caddy-v1`, and you rebuild and push that same **tag** again, the host can pick up the new image with `bootc upgrade`.

If you prefer immutable versioning, publish a new tag such as `fedora-43-caddy-v2` and move hosts to it with `bootc switch`.

### Check The Current State On A Booted VM Or Bare-Metal Host

Use `bootc status` to see the current image, staged deployments, and update state:

```bash
sudo bootc status
```

For more detail, including download-only status:

```bash
sudo bootc status --verbose
```

### Upgrade The Currently Tracked Image

If the system should keep following the same image reference, use:

```bash
sudo bootc upgrade
sudo systemctl reboot
```

This checks the currently tracked image reference, stages the new deployment, and applies it on reboot.

### Controlled Upgrade With A Maintenance Window

If you want to download the update first and apply it later:

```bash
sudo bootc upgrade --download-only
sudo bootc status --verbose
sudo bootc upgrade --from-downloaded --apply
```

This is useful when you want to fetch the image ahead of time and reboot only during a planned maintenance window.

### Switch To A Different Image Tag

If the host should move from one tag to another, for example from `fedora-43-caddy-v1` to `fedora-43-caddy-v2`, use:

```bash
sudo bootc switch docker.io/l88repo/dev-bootc:fedora-43-caddy-v2
sudo systemctl reboot
```

`bootc switch` changes the image reference the host tracks. Existing state in `/etc` and `/var` is preserved.

### Roll Back To The Previous Deployment

If the newly booted deployment is not good, roll back to the previous boot entry:

```bash
sudo bootc rollback
sudo systemctl reboot
```

### Optional: Update The Bootloader

`bootc upgrade` updates the operating system image, but it does not update the bootloader. To update the bootloader as well:

```bash
sudo bootupctl update
```

### Practical Day 2 Flow

One simple workflow looks like this:

1. Update the image locally.
2. Build and push a new tag such as `docker.io/l88repo/dev-bootc:fedora-43-caddy-v2`.
3. On the booted VM or bare-metal host, check the current state with `bootc status`.
4. If the host should stay on the same tracked tag, run `bootc upgrade`.
5. If the host should move to a new tag, run `bootc switch <new-tag>`.
6. Reboot into the staged deployment.
7. If needed, run `bootc rollback` and reboot again.
