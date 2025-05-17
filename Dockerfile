FROM ubuntu:22.04

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set environment variables for Omada Controller
ENV OMADA_DIR="/opt/tp-link/omada-controller"
ENV OMADA_VERSION="5.12.7"

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    wget \
    jsvc \
    autoconf \
    make \
    gcc \
    openjdk-11-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# Install MongoDB
# Import the MongoDB public key
RUN curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
    gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

# Add MongoDB repository and install MongoDB 7.0
RUN echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
    tee /etc/apt/sources.list.d/mongodb-org-7.0.list
RUN apt-get update && apt-get install -y \
    mongodb-org \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p ${OMADA_DIR}

# Download and install Omada Controller
WORKDIR /tmp
RUN wget -nv "https://static.tp-link.com/upload/software/2023/202310/20231009/Omada_SDN_Controller_v5.12.7_Linux_x64.tar.gz" && \
    tar zxvf Omada_SDN_Controller_v5.12.7_Linux_x64.tar.gz && \
    cd Omada_SDN_Controller_v5.12.7_Linux_x64 && \
    mkdir -p ${OMADA_DIR} && \
    cp -r * ${OMADA_DIR} && \
    cd ${OMADA_DIR} && \
    mkdir -p logs && \
    chmod 755 bin/*.sh && \
    cd /tmp && \
    rm -rf Omada_SDN_Controller_v5.12.7_Linux_x64* 

# Set volumes and ports
VOLUME ["/opt/tp-link/omada-controller/data", "/opt/tp-link/omada-controller/logs", "/opt/tp-link/omada-controller/work"]

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
