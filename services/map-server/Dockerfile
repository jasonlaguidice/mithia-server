# Mithia Map Server - Standalone Container
# Using Ubuntu 16.04 for legacy library compatibility
FROM i386/ubuntu:16.04

# Set up timezone configuration to avoid interactive prompts
RUN echo tzdata tzdata/Zones/America select New_York | debconf-set-selections && \
    echo tzdata tzdata/Zones/Etc select EST | debconf-set-selections

# Install legacy dependencies matching RTK server era
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
    liblua5.1-dev \
    mysql-client-5.7 \
    pkg-config \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Create RTK user and directories
RUN useradd -m -d /home/RTK -s /bin/bash RTK

# Set working directory
WORKDIR /home/RTK

# Install getent for hostname resolution and envsubst for template processing
RUN apt-get update && apt-get install -y gettext-base dnsutils curl && rm -rf /var/lib/apt/lists/*

# Copy ALL source files (dependencies exist across directories)
COPY --chown=RTK:RTK rtk/src/ rtk/src/
COPY --chown=RTK:RTK rtk/Makefile rtk/Makefile
COPY --chown=RTK:RTK rtk/db/ rtk/db/
COPY --chown=RTK:RTK rtklua/ rtklua/
COPY --chown=RTK:RTK rtkmaps/ rtkmaps/

# Copy configuration templates and startup script
COPY --chown=RTK:RTK rtk/conf/*.template rtk/conf/
COPY --chown=RTK:RTK rtk/conf/*.conf rtk/conf/
# Backup templates to a separate location for post-mount restoration
COPY --chown=RTK:RTK rtk/conf/*.template rtk/conf-templates/
COPY --chown=RTK:RTK docker/startup.sh /startup.sh
RUN chmod +x /startup.sh && sed -i 's/\r$//' /startup.sh

# Create log directory and build map server as RTK user
USER RTK
RUN mkdir -p rtk/log rtk/logs
RUN cd rtk && make map

# Make server executable
RUN chmod +x rtk/map-server

# Expose map server port
EXPOSE 2001

# Use startup script as entrypoint
WORKDIR /home/RTK/rtk
ENTRYPOINT ["/startup.sh"]
CMD ["./map-server"]