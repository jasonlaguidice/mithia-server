# Use i386 Ubuntu for 32-bit compatibility
# QEMU will automatically emulate this on ARM64
FROM i386/ubuntu:16.04

# Set up timezone configuration to avoid interactive prompts
RUN echo tzdata tzdata/Zones/Europe select London | debconf-set-selections && \
    echo tzdata tzdata/Zones/Etc select UTC | debconf-set-selections

# Install dependencies for 32-bit compilation
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
    && rm -rf /var/lib/apt/lists/*

# Create RTK user and directories
RUN useradd -m -d /home/RTK -s /bin/bash RTK

# Set working directory
WORKDIR /home/RTK

# Copy source code (excluding build artifacts via .dockerignore)
COPY --chown=RTK:RTK . .

# Build the application as RTK user
USER RTK
RUN cd rtk && make clean && make

# Make server management scripts executable
RUN chmod +x rtk/*-server* rtk/check-mithia-server-state

# Expose default ports for RTK servers
# Login server: 2000, Map server: 2001, Character server: 2005
EXPOSE 2000 2001 2005

# Default command - can be overridden in docker-compose or run commands
CMD ["tail", "-f", "/dev/null"]

# TODO: Implement cron job for automated database backups