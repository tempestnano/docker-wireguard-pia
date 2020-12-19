docker buildx create --name docker-multiarch
docker buildx inspect --builder docker-multiarch --bootstrap
docker buildx build --builder docker-multiarch --platform linux/amd64,linux/arm64,linux/arm/v7 ./ --push -t jstrader/docker-wireguard-pia