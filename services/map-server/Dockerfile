# Mithia Map Server - Multi-Architecture Native Build
# Supports Linux amd64/arm64 via modern compilation (native performance)
ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Use modern Ubuntu with native architecture support
FROM --platform=${TARGETPLATFORM} ubuntu:22.04

# Build arguments for cross-platform support
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

# Set up timezone and locale
ENV TZ=UTC
ENV DEBIAN_FRONTEND=noninteractive

# Install modern native dependencies with pkg-config support
RUN apt-get update && apt-get install -y \
    build-essential \
    pkg-config \
    libmariadb-dev \
    liblua5.1-dev \
    zlib1g-dev \
    gettext-base \
    dnsutils \
    curl \
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
COPY --chown=RTK:RTK rtk/SObj.tbl rtk/SObj.tbl
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

# Create backup of SObj.tbl for startup script restoration
RUN cp rtk/SObj.tbl rtk/SObj.tbl.backup

# Make server executable
RUN chmod +x rtk/map-server

# Expose map server port
EXPOSE 2001

# Use startup script as entrypoint
WORKDIR /home/RTK/rtk
ENTRYPOINT ["/startup.sh"]
CMD ["./map-server"]