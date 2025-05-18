podman run -d \
  --name omada-controller \
  --restart=always \
  --cpus=4.0 \
  --memory=6g \
  --memory-reservation=2g \
  --ulimit nofile=65536:65536 \
  -p 8088:8088 \
  -p 8043:8043 \
  -p 8843:8843 \
  -p 29810:29810 \
  -p 29811:29811 \
  -p 29812:29812 \
  -p 29813:29813 \
  -p 29814:29814 \
  -v omada-data:/opt/tplink/EAPController/data \
  -v omada-logs:/opt/tplink/EAPController/logs \
  -v omada-work:/opt/tplink/EAPController/work \
  -v mongodb-data:/data/db \
  localhost/omada-controller:latest