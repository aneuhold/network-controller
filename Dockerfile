FROM --platform=linux/amd64 ubuntu:22.04

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set environment variables for Omada Controller
ENV OMADA_DIR="/opt/tplink/EAPController"
ENV OMADA_VERSION="5.15.20.18"

# Increase Java heap size for better performance
ENV JAVA_OPTS="-Xms1024m -Xmx4096m -XX:MaxMetaspaceSize=512m -XX:+UseG1GC -XX:ParallelGCThreads=4"
# Set higher CPU priority
ENV JSVC_OPTS="-Xmx4096m -XX:MaxMetaspaceSize=512m -XX:+UseConcMarkSweepGC"

# Install dependencies
RUN apt-get update && apt-get install -y \
  curl \
  gnupg \
  wget \
  autoconf \
  make \
  gcc \
  findutils \
  openjdk-17-jdk-headless \
  expect \
  netcat-openbsd \
  net-tools \
  && rm -rf /var/lib/apt/lists/*

# Install a newer version of JSVC (required for Java 17)
RUN wget https://archive.apache.org/dist/commons/daemon/source/commons-daemon-1.3.3-src.tar.gz && \
  tar zxvf commons-daemon-1.3.3-src.tar.gz && \
  cd commons-daemon-1.3.3-src/src/native/unix && \
  sh support/buildconf.sh && \
  ./configure --with-java=/usr/lib/jvm/java-17-openjdk-amd64 && \
  make && \
  cp jsvc /usr/bin && \
  chmod 755 /usr/bin/jsvc && \
  cd / && \
  rm -rf commons-daemon-1.3.3-src commons-daemon-1.3.3-src.tar.gz

# Create a symlink for the JVM to make it more discoverable
RUN mkdir -p /usr/lib/jvm/java-17-openjdk-amd64/jre/lib/amd64/server && \
  ln -s /usr/lib/jvm/java-17-openjdk-amd64/lib/server/libjvm.so /usr/lib/jvm/java-17-openjdk-amd64/jre/lib/amd64/server/libjvm.so

# Install MongoDB 
# Note: The Omada Controller installer comes with MongoDB but 
# we install a newer version separately to address compatibility issues

# Import the MongoDB public key
RUN curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
  gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

# Add MongoDB repository and install MongoDB 7.0
RUN mkdir -p /etc/apt/sources.list.d && \
  echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
  tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Install MongoDB with proper version and create directories
RUN apt-get update && apt-get install -y \
  mongodb-org=7.0.12 \
  mongodb-org-database=7.0.12 \
  mongodb-org-server=7.0.12 \
  mongodb-org-mongos=7.0.12 \
  mongodb-org-tools=7.0.12 \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /data/db /var/log/mongodb \
  && chmod -R 777 /data/db /var/log/mongodb

# Create necessary directories and ensure they're clean
RUN mkdir -p ${OMADA_DIR} && \
  # Create the compatibility symlinks ahead of time
  mkdir -p /tp-link && \
  ln -sf ${OMADA_DIR} /tp-link/omada-controller && \
  ln -sf ${OMADA_DIR} /omada-controller

# Download and prepare Omada Controller Debian package
WORKDIR /tmp
RUN wget -nv "https://static.tp-link.com/upload/software/2025/202503/20250331/Omada_SDN_Controller_v5.15.20.18_linux_x64.deb" -O omada-controller.deb && \
  # Don't install yet, just download the package
  mkdir -p /opt/tplink

# Set volumes and ports
VOLUME ["${OMADA_DIR}/data", "${OMADA_DIR}/logs", "${OMADA_DIR}/work", "/data/db"]

# Expose ports
# 8088 - HTTP portal
# 8043 - HTTPS portal 
# 8843 - HTTPS portal for controller to manage EAPs
# 29810-29814 - Discovery ports
# 27001-27002 - MongoDB ports
EXPOSE 8088 8043 8843 29810-29814 27001-27002

# Create a startup script
COPY start-omada.sh /start-omada.sh
RUN chmod +x /start-omada.sh

# Start the controller
CMD ["/start-omada.sh"]
