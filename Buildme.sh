docker build -t jstrader/docker-wireguard-pia:arm32v7 -f .\Dockerfile.arm32v7 ./
docker push jstrader/docker-wireguard-pia:arm32v7
docker build -t jstrader/docker-wireguard-pia:arm64v8 -f .\Dockerfile.arm64v8 ./
docker push jstrader/docker-wireguard-pia:arm64v8
docker build -t jstrader/docker-wireguard-pia:amd64 -f .\Dockerfile ./
docker push jstrader/docker-wireguard-pia:amd64
docker manifest create jstrader/docker-wireguard-pia:latest --amend jstrader/docker-wireguard-pia:arm32v7 --amend jstrader/docker-wireguard-pia:arm64v8 --amend jstrader/docker-wireguard-pia:amd64
docker manifest push jstrader/docker-wireguard-pia:latest
