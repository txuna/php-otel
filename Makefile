REGISTRY := localhost:5001

.PHONY: cluster-up cluster-down build-base build-fpm help

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

## HELP
help:
	@echo "make cluster-up			: 클러스터 생성"
	@echo "make cluster-down		: 클러스터 삭제"
	@echo "make build-base			: php-fpm:8.4.7 베이스 이미지 생성"
	@echo "make build-fpm			: 웹서버 소스 빌드"
	@echo "make deploy-fpm			: PHP-FPM with Nginx 배포"
	@echo "make remove-fpm			: PHP-FPM with Nginx 삭제"