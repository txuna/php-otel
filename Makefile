REGISTRY := localhost:5001

.PHONY: cluster-up cluster-down build-base build-fpm help deploy-jaeger remove-jaeger repo-add

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

deploy-jaeger:
	@helm upgrade --install jaeger jaegertracing/jaeger -f ./install/values/values.jaeger.yaml -n telemetry --create-namespace

remove-jaeger:
	@helm uninstall jaeger -n telemetry

## HELP
repo-add:
	@helm repo add jaegertracing https://jaegertracing.github.io/helm-charts

## HELP
help:
	@echo "make cluster-up			: 클러스터 생성"
	@echo "make cluster-down		: 클러스터 삭제"
	@echo "make build-base			: php-fpm:8.4.7 베이스 이미지 생성"
	@echo "make build-fpm			: 웹서버 소스 빌드"
	@echo "make deploy-fpm			: PHP-FPM with Nginx 배포"
	@echo "make remove-fpm			: PHP-FPM with Nginx 삭제"
	@echo "make deploy-jaeger		: Jaeger 배포"
	@echo "make remove-jaeger		: Jaeger 삭제"
	@echo "make repo-add			: HELM 차트 업데이트"