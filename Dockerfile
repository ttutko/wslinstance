# syntax=docker/dockerfile:1
# =============================================================================
# Airgapped WSL builder image.
#
# This container is NOT meant to be run as a normal image. build.sh flattens it
# with `docker export` into a rootfs tarball for `wsl --import`. Everything the
# airgapped target needs is baked in here at build time (network is used ONLY
# during this build).
# =============================================================================
FROM debian:13-slim

# C.UTF-8 always exists in Debian, so the build works before en_US.UTF-8 is
# generated. The instance's runtime locale (en_US.UTF-8) is set by the base
# role via /etc/default/locale.
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# --- Bootstrap: just enough to run Ansible and fetch downloads ---------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3 python3-pip python3-apt \
      ca-certificates curl gnupg unzip tar xz-utils git \
 && pip3 install --no-cache-dir --break-system-packages ansible-core \
 && rm -rf /var/lib/apt/lists/*

# --- Provision with Ansible (local connection) -------------------------------
WORKDIR /provision
COPY ansible/  ./ansible/
COPY config/   ./config/
COPY firstrun/ ./firstrun/
COPY docs/     ./docs/
COPY tests/    ./tests/

RUN ansible-playbook -i 'localhost,' -c local ansible/playbook.yml

# --- Slim down: drop the build-only Ansible install and caches --------------
# NB: do NOT `apt-get autoremove` here — it cascades through Python and removes
# httpie/bpytop. And preserve /root/.cache/tealdeer (the offline tldr cache);
# only the pip download cache is cleared.
RUN pip3 uninstall -y --break-system-packages ansible-core || true \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /root/.cache/pip /root/.ansible /tmp/* /var/tmp/* \
           /provision

CMD ["/usr/bin/zsh"]
