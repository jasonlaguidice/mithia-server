# Mithia Character Server - Standalone Container
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

# Copy only the files needed for character server
COPY --chown=RTK:RTK rtk/src/common/ rtk/src/common/
COPY --chown=RTK:RTK rtk/src/char/ rtk/src/char/
COPY --chown=RTK:RTK rtk/Makefile rtk/Makefile
COPY --chown=RTK:RTK rtk/conf/ rtk/conf/

# Build only character server as RTK user
USER RTK
RUN cd rtk && make clean && make char

# Make server executable
RUN chmod +x rtk/char-server

# Expose character server port
EXPOSE 2005

# Run character server
WORKDIR /home/RTK/rtk
CMD ["./char-server"]