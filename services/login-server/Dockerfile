# Mithia Login Server - Standalone Container
# Supports 32-bit execution on ARM64 via qemu
FROM i386/ubuntu:latest

# Set up timezone configuration to avoid interactive prompts
RUN echo tzdata tzdata/Zones/Europe select London | debconf-set-selections && \
    echo tzdata tzdata/Zones/Etc select UTC | debconf-set-selections

# Install dependencies matching working Dockerfile
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && apt-get install -y \
    build-essential \
    make \
    gcc \
    g++ \
    libc6-dev \
    libmysqlclient20 \
    libmysqlclient-dev \
    lua5.1 \
    liblua5.1 \
    mysql-client-5.7 \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Create RTK user and directories
RUN useradd -m -d /home/RTK -s /bin/bash RTK

# Set working directory
WORKDIR /home/RTK

# Install getent for hostname resolution and envsubst for template processing
RUN apt-get update && apt-get install -y gettext-base dnsutils curl && rm -rf /var/lib/apt/lists/*

# Copy source files needed for login server
COPY --chown=RTK:RTK rtk/src/common/ rtk/src/common/
COPY --chown=RTK:RTK rtk/src/login/ rtk/src/login/
COPY --chown=RTK:RTK rtk/Makefile rtk/Makefile

# Copy configuration templates and startup script
COPY --chown=RTK:RTK rtk/conf/*.template rtk/conf/
COPY --chown=RTK:RTK rtk/conf/*.conf rtk/conf/
COPY --chown=RTK:RTK docker/startup.sh /startup.sh
RUN chmod +x /startup.sh

# Build only login server as RTK user
USER RTK
RUN cd rtk && make login

# Make server executable
RUN chmod +x rtk/login-server

# Expose login server port
EXPOSE 2000

# Use startup script as entrypoint
WORKDIR /home/RTK/rtk
ENTRYPOINT ["/startup.sh"]
CMD ["./login-server"]