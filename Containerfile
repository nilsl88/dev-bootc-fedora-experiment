FROM ghcr.io/bootc-dev/dev-bootc:fedora-43

# set keyboard setting & dnf parallel downloads
RUN printf 'KEYMAP=dk\n' > /etc/vconsole.conf && \
    echo "max_parallel_downloads=20" >> /etc/yum.conf

# Install Caddy and keep the image clean
RUN dnf upgrade -y && dnf -y install caddy && \
    dnf clean all

# Put in a very simple static Caddy config
COPY Caddyfile /etc/caddy/Caddyfile

# Put in a very simple passwordless-sudo config
COPY wheel-passwordless-sudo /etc/sudoers.d/wheel-passwordless-sudo

RUN chmod 0440 /etc/sudoers.d/wheel-passwordless-sudo

# Enable caddy.service for booted systems
RUN mkdir -p /usr/lib/systemd/system/multi-user.target.wants && \
    ln -sf ../caddy.service /usr/lib/systemd/system/multi-user.target.wants/caddy.service

LABEL org.opencontainers.image.title="Fedora 43 bootc with Caddy"
LABEL org.opencontainers.image.description="Fedora 43 bootc image with Caddy enabled"
