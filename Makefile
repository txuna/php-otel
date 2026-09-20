REGISTRY := localhost:5001

.PHONY: cluster-up cluster-down build-base build-fpm

## 클러스터 생성 부
cluster-up:
	@sh ./kind/cluster.sh

cluster-down:
	@kind delete cluster -n php-otel

## 이미지 생성 부
build-base:
	@docker build -t $(REGISTRY)/base:latest -f base/Dockerfile .
	@docker push $(REGISTRY)/base:latest

build-fpm:
	@docker build -t $(REGISTRY)/fpm:latest -f src/php-fpm/Dockerfile .
	@docker push $(REGISTRY)/fpm:latest

## 배포 부
deploy-fpm:
	@helm upgrade --install fpm ./install/charts/php-fpm -f ./install/values/values.php-fpm.yaml -n fpm --create-namespace

remove-fpm:
	@helm uninstall fpm -n fpm