# Mithia Character Server - Multi-Architecture Native Build
# Supports Linux amd64/arm64, Windows amd64 via modern compilation
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

# Copy source files with proper ownership
COPY --chown=RTK:RTK rtk/src/ rtk/src/
COPY --chown=RTK:RTK rtk/Makefile rtk/Makefile

# Copy configuration templates and startup script
COPY --chown=RTK:RTK rtk/conf/*.template rtk/conf/
COPY --chown=RTK:RTK rtk/conf/*.conf rtk/conf/
# Backup templates for post-mount restoration
COPY --chown=RTK:RTK rtk/conf/*.template rtk/conf-templates/
COPY --chown=RTK:RTK docker/startup.sh /startup.sh

# Make startup script executable and fix line endings
RUN chmod +x /startup.sh && sed -i 's/\r$//' /startup.sh

# Switch to RTK user for compilation
USER RTK

# Create log directories and build character server natively
RUN mkdir -p rtk/log rtk/logs
RUN cd rtk && make char

# Verify binary was built for correct architecture
RUN file rtk/char-server

# Make server executable (in case it's not already)
RUN chmod +x rtk/char-server

# Expose character server port
EXPOSE 2005

# Set working directory for runtime
WORKDIR /home/RTK/rtk

# Health check to verify server can start
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:2005/ || exit 1

# Use startup script as entrypoint
ENTRYPOINT ["/startup.sh"]
CMD ["./char-server"]

# Add labels for multi-arch metadata
LABEL org.opencontainers.image.title="Mithia Character Server"
LABEL org.opencontainers.image.description="Native multi-architecture character server for Mithia MMORPG"
LABEL org.opencontainers.image.platform="${TARGETPLATFORM}"
LABEL org.opencontainers.image.architecture="${TARGETARCH}"
LABEL org.opencontainers.image.os="${TARGETOS}"