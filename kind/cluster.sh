#!/bin/sh
# Copyright The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit

# 어디서 실행하든 같은 디렉터리의 cluster.yaml 을 찾도록 한다
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cluster_config="${script_dir}/cluster.yaml"

command -v envsubst >/dev/null 2>&1 || {
  echo "error: envsubst 가 없습니다. brew install gettext" >&2
  exit 1
}

env_file="${script_dir}/../.env"
if [ ! -f "${env_file}" ]; then
  echo "error: ${env_file} 가 없습니다. cp .env.example .env 후 REPO_ROOT 를 채우세요." >&2
  exit 1
fi

# set -a: 이후 대입을 자동 export 한다. envsubst 는 셸 변수가 아니라
# 환경변수를 읽으므로 export 없이는 빈 문자열로 치환된다.
set -a
. "${env_file}"
set +a

: "${REPO_ROOT:?REPO_ROOT 가 .env 에 설정되지 않았습니다}"

# 클러스터 이름은 cluster.yaml 의 최상위 name 을 단일 출처로 삼는다
cluster_name=$(sed -n 's/^name:[[:space:]]*//p' "${cluster_config}")
if [ -z "${cluster_name}" ]; then
  echo "error: no top-level 'name:' in ${cluster_config}" >&2
  exit 1
fi

# 1. Create registry container unless it already exists
reg_name='kind-registry'
reg_port='5001'
if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --network bridge --name "${reg_name}" \
    registry:3
fi

# 2. Create kind cluster with containerd registry config dir enabled
#
# NOTE: the containerd config patch is not necessary with images from kind v0.27.0+
# It may enable some older images to work similarly.
# If you're only supporting newer relases, you can just use `kind create cluster` here.
#
# See:
# https://github.com/kubernetes-sigs/kind/issues/2875
# https://github.com/containerd/containerd/blob/main/docs/cri/config.md#registry-configuration
# See: https://github.com/containerd/containerd/blob/main/docs/hosts.md
envsubst '${REPO_ROOT}' < "${cluster_config}" | kind create cluster --config=-

# 3. Add the registry config to the nodes
#
# This is necessary because localhost resolves to loopback addresses that are
# network-namespace local.
# In other words: localhost in the container is not localhost on the host.
#
# We want a consistent name that works from both ends, so we tell containerd to
# alias localhost:${reg_port} to the registry container when pulling images
REGISTRY_DIR="/etc/containerd/certs.d/localhost:${reg_port}"
for node in $(kind get nodes --name "${cluster_name}"); do
  docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
  cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
[host."http://${reg_name}:5000"]
EOF
done

# 4. Connect the registry to the cluster network if not already connected
# This allows kind to bootstrap the network but ensures they're on the same network
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
  docker network connect "kind" "${reg_name}"
fi

# 5. Document the local registry
# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF