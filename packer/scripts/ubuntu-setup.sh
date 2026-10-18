#!/usr/bin/env bash
# Customizes the Ubuntu 24.04 base image: Git, Python, Docker.
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

cloud-init status --wait || true

apt-get update
apt-get -y upgrade
apt-get -y install ca-certificates curl gnupg git python3 python3-pip python3-venv

# ---- Docker Engine from Docker's official apt repository ----
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker
systemctl start docker

# ---- Verify (the build fails here if anything is missing) ----
git --version
python3 --version
pip3 --version
docker --version
docker compose version
systemctl is-active docker

# ---- Proof of what is inside the image ----
cat > /etc/image-info.txt << INFO
Golden image : ubuntu-2404
Version      : ${IMAGE_VERSION}
Built by     : Packer
Git          : $(git --version)
Python       : $(python3 --version)
Docker       : $(docker --version)
INFO

# Shown on every SSH login
cat > /etc/update-motd.d/99-image-info << MOTD
#!/bin/sh
echo
echo "Golden image: ubuntu-2404  version ${IMAGE_VERSION}  (built by Packer)"
echo "Preinstalled: \$(git --version) | \$(python3 --version) | \$(docker --version)"
echo
MOTD
chmod +x /etc/update-motd.d/99-image-info

apt-get clean
