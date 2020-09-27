docker build -t jstrader/docker-wireguard-pia:arm32v7 -f .\Dockerfile.arm32v7 ./
docker build -t jstrader/docker-wireguard-pia:arm64v8 -f .\Dockerfile.arm64v8 ./
docker build -t jstrader/docker-wireguard-pia:amd64 -f .\Dockerfile ./
docker build -t jstrader/docker-wireguard-pia:test -f .\Dockerfile.test ./