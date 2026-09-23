#!/bin/bash

#
# Copyright (C) 2026 tebbi
# SPDX-License-Identifier: GPL-3.0-or-later
#

# Terminate on error
set -e

# Prepare variables for later use
images=()
# The images will be pushed to the GitHub container registry
repobase="${REPOBASE:-ghcr.io/tebbiworld}"
# Module package image name
reponame="sagemath"
# Runtime image name + tag. The runtime image is referenced (pinned) by the
# module via the org.nethserver.images label, so the node pre-pulls it and
# exposes it as ${SAGEMATH_APP_IMAGE}.
appname="sagemath-app"
apptag="${APPTAG:-1.0.0}"  # CI auto-release passes APPTAG=<module version>
appimage="${repobase}/${appname}:${apptag}"

#
# 1) Build the runtime image: the official SageMath image extended with
#    JupyterHub, the LDAP/AD authenticator and configurable-http-proxy. This is
#    what actually runs on the node (per-user JupyterLab + SageMath kernel).
#
# Set SKIP_APP_IMAGE=1 for module-only releases (imageroot/UI changes): the
# already published runtime image keeps its pinned tag and is not rebuilt.
if [[ -z "${SKIP_APP_IMAGE}" ]]; then
    echo "Build the SageMath + JupyterHub runtime image..."
    podman build --force-rm -t "${appimage}" -f image/Containerfile image/
    images+=("${appimage}")
fi

# The runtime image pinned in the module label. The node exposes its reference
# as ${SAGEMATH_APP_IMAGE} (basename uppercased, non-alphanumeric -> underscore).
runtime_images=(
    "${appimage}"
)

#
# 2) Build the module package image (scratch + imageroot + compiled UI).
#
container=$(buildah from scratch)

# Reuse an existing nodebuilder container to speed up UI rebuilds
if ! buildah containers --format "{{.ContainerName}}" | grep -q nodebuilder-sagemath; then
    echo "Pulling NodeJS runtime..."
    buildah from --name nodebuilder-sagemath -v "${PWD}:/usr/src:Z" docker.io/library/node:24.16.0-slim
fi

echo "Build static UI files with node..."
buildah run \
    --workingdir=/usr/src/ui \
    --env="NODE_OPTIONS=--openssl-legacy-provider" \
    nodebuilder-sagemath \
    sh -c "yarn install && yarn build"

# Add imageroot and the compiled UI to the module image
buildah add "${container}" imageroot /imageroot
buildah add "${container}" ui/dist /ui
# Setup the entrypoint, reserve a single TCP port (the published hub port),
# declare the runtime image and mark the module as rootless.
# The bulk-data volumes can be placed on an additional disk at install time.
buildah config --entrypoint=/ \
    --label="org.nethserver.authorizations=traefik@node:routeadm" \
    --label="org.nethserver.tcp-ports-demand=1" \
    --label="org.nethserver.rootfull=0" \
    --label="org.nethserver.images=${runtime_images[*]}" \
    --label="org.nethserver.volumes=sagemath-userhomes" \
    "${container}"
# Commit the module image
buildah commit "${container}" "${repobase}/${reponame}"

images+=("${repobase}/${reponame}")

#
# Setup CI when pushing to Github.
# Warning! docker::// protocol expects lowercase letters (,,)
if [[ -n "${CI}" ]]; then
    # Set output value for Github Actions
    printf "images=%s\n" "${images[*],,}" >> "${GITHUB_OUTPUT}"
else
    # Just print info for manual push. The runtime image already carries its
    # pinned tag (it must be published under exactly that tag, since the module
    # label references it); the module image is published under IMAGETAG.
    printf "Publish the images with:\n\n"
    printf "  buildah push %s docker://%s\n" "${appimage,,}" "${appimage,,}"
    printf "  buildah push %s docker://%s:%s\n" "${repobase,,}/${reponame,,}" "${repobase,,}/${reponame,,}" "${IMAGETAG:-latest}"
    printf "\n"
fi
