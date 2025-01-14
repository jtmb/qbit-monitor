docker build --platform linux/amd64 -t jtmb92/qbit-monitor:amd64 .
docker push jtmb92/qbit-monitor:amd64

docker build --platform linux/amd64 -t jtmb92/qbit-monitor:latest .
docker push jtmb92/qbit-monitor:latest