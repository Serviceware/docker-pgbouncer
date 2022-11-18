IMAGE_NAME=docker-pgbouncer
IMAGE_VERSION=latest

docker:
	docker build --pull -t $(IMAGE_NAME):$(IMAGE_VERSION) .

push:
	docker push $(IMAGE_NAME):$(IMAGE_VERSION)
