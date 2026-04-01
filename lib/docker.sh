#!/usr/bin/env bash
# Docker module (appliance‑grade)
# Requires: lib/logging.sh, lib/colors.sh, modules/system.sh

# shellcheck source=../lib/logging.sh
source "${LIB_DIR}/logging.sh"

###############################################
# SECTION: Internal helpers
###############################################

docker::_install_prereqs() {
    log::info "Installing Docker prerequisites…"

    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        jq || log::die "Failed to install Docker prerequisites."

    log::ok "Prerequisites installed."
}

docker::_add_repo() {
    log::info "Adding Docker repository…"

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update -y
    log::ok "Docker repository added."
}

docker::_install_engine() {
    log::info "Installing Docker Engine + Compose…"

    apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        || log::die "Docker installation failed."

    log::ok "Docker Engine installed."
}

docker::_daemon_config() {
    log::info "Configuring Docker daemon…"

    mkdir -p /etc/docker

    cat >/etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

    systemctl daemon-reload
    systemctl restart docker

    log::ok "Docker daemon configured."
}

docker::_enable_service() {
    log::info "Enabling Docker service…"
    systemctl enable docker || log::die "Failed to enable Docker service."
    log::ok "Docker service enabled."
}

docker::_self_heal() {
    log::info "Applying Docker self‑healing…"

    systemctl is-active --quiet docker || {
        log::warn "Docker not running — attempting recovery…"
        systemctl restart docker
    }

    systemctl is-active --quiet docker \
        && log::ok "Docker is healthy." \
        || log::die "Docker failed to start."
}

docker::_post_install_diagnostics() {
    log::section "Docker Diagnostics"

    docker --version | log::indent
    docker info | log::indent || log::warn "docker info failed."

    log::ok "Diagnostics complete."
}

###############################################
# SECTION: Public API
###############################################

docker::install() {
    log::section "Installing Docker"

    docker::_install_prereqs
    docker::_add_repo
    docker::_install_engine
    docker::_daemon_config
    docker::_enable_service
    docker::_self_heal
    docker::_post_install_diagnostics

    log::ok "Docker installation complete."
}

docker::register() {
    # Register with system container registry
    if command -v system::register_container >/dev/null 2>&1; then
        system::register_container "docker" "Docker Engine + Compose"
        log::ok "Docker registered with container registry."
    else
        log::warn "system::register_container not found — skipping registry."
    fi
}

docker::init() {
    log::title "Initializing Docker Module"

    docker::install
    docker::register

    log::ok "Docker module complete."
}
