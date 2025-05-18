FROM --platform=linux/amd64 ubuntu:22.04

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set environment variables for Omada Controller
ENV OMADA_DIR="/opt/tplink/EAPController"
ENV OMADA_VERSION="5.15.20.18"

# Install dependencies
RUN apt-get update && apt-get install -y \
  curl \
  gnupg \
  wget \
  openjdk-17-jdk-headless \
  jsvc \
  net-tools

# Get LibSSL 1.1
RUN echo "deb http://security.ubuntu.com/ubuntu focal-security main" | tee /etc/apt/sources.list.d/focal-security.list && \
  apt-get update && \
  apt-get install libssl1.1

# Install MongoDB 4.4
RUN apt-get update && \
  curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | gpg -o /usr/share/keyrings/mongodb-server-4.4.gpg --dearmor && \
  echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-4.4.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list && \
  # This next part has to be done to handle an issue with installing MongoDB on a container. 
  ln -T /bin/true /usr/bin/systemctl && \
  apt-get update && \
  apt-get install -y mongodb-org

# Create necessary directories ahead of time
RUN mkdir -p ${OMADA_DIR}

# Use a direct download from TP-Link's website for the Omada Controller
RUN curl "https://static.tp-link.com/upload/software/2025/202503/20250331/Omada_SDN_Controller_v${OMADA_VERSION}_linux_x64.deb" -o /tmp/omada-controller.deb

# Set volumes and ports
VOLUME ["${OMADA_DIR}/data", "${OMADA_DIR}/logs", "${OMADA_DIR}/work", "/data/db"]

# Expose ports
# 8088 - HTTP portal
# 8043 - HTTPS portal 
# 8843 - HTTPS portal for controller to manage EAPs
# 29810-29814 - Discovery ports
# 27001-27002 - MongoDB ports
EXPOSE 8088 8043 8843 29810-29814 27001-27002

# Create the startup script
COPY ./container_scripts/start-omada.sh /start-omada.sh
RUN chmod +x /start-omada.sh

# Start the controller
CMD ["/start-omada.sh"]
