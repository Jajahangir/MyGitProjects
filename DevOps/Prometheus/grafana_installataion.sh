#!/usr/bin/env bash
#--------------------------------------------------------------------
# Улучшенный скрипт установки Grafana OSS на Ubuntu / Debian
# Поддержка архитектур: amd64 (x86_64), arm64 (aarch64)
# Автоматическая настройка источника данных Prometheus
#--------------------------------------------------------------------

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }

if [[ $EUID -ne 0 ]]; then
    log_error "Скрипт должен быть запущен с правами суперпользователя (sudo)."
    exit 1
fi

PROMETHEUS_URL="${PROMETHEUS_URL:-http://ip-address:9090}"
# Если оставить пустой, будет установлена актуальная стабильная версия из apt-репозитория
GRAFANA_VERSION="${GRAFANA_VERSION:-}"

export DEBIAN_FRONTEND=noninteractive

# Установка базовых утилит
log_info "Установка зависимостей..."
apt-get update -qq
apt-get install -y -qq \
    apt-transport-https \
    software-properties-common \
    wget \
    curl \
    gnupg

log_info "Настройка официального репозитория Grafana..."
install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/grafana.gpg
chmod 0644 /etc/apt/keyrings/grafana.gpg

echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
    > /etc/apt/sources.list.d/grafana.list

apt-get update -qq

# Установка пакета
if [ -n "$GRAFANA_VERSION" ]; then
    log_info "Установка Grafana конкретной версии: ${GRAFANA_VERSION}..."
    apt-get install -y -qq "grafana=${GRAFANA_VERSION}" || {
        log_warn "Версия ${GRAFANA_VERSION} не найдена в репозитории, попытка прямой установки deb-пакета..."
        
        ARCH=$(dpkg --print-architecture)
        TMP_DIR=$(mktemp -d)
        DEB_URL="https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_${ARCH}.deb"
        
        curl -sSL "$DEB_URL" -o "${TMP_DIR}/grafana.deb"
        apt-get install -y -qq "${TMP_DIR}/grafana.deb"
        rm -rf "$TMP_DIR"
    }
else
    log_info "Установка последней стабильной версии Grafana OSS..."
    apt-get install -y -qq grafana
fi

PROVISIONING_DIR="/etc/grafana/provisioning/datasources"
mkdir -p "$PROVISIONING_DIR"

log_info "Настройка DataSource Prometheus (${PROMETHEUS_URL})..."
cat <<EOF > "${PROVISIONING_DIR}/prometheus.yaml"
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: ${PROMETHEUS_URL}
    isDefault: true
    editable: true
    jsonData:
      httpMethod: POST
      timeInterval: 15s
EOF

chown -R root:grafana /etc/grafana/provisioning
chmod -R 755 /etc/grafana/provisioning

log_info "Запуск grafana-server..."
systemctl daemon-reload
systemctl enable --now grafana-server

log_info "Ожидание инициализации Grafana..."
READY=false
for i in {1..15}; do
    if curl -s -f http://localhost:3000/api/health >/dev/null 2>&1; then
        READY=true
        break
    fi
    sleep 1
done

if [ "$READY" = true ]; then
    log_info "Grafana успешно запущена и доступна на http://localhost:3000"
    log_info "Логин по умолчанию: admin / admin"
else
    log_warn "Сервис стартовал, но HTTP API пока не отвечает на порту 3000. Проверьте: journalctl -u grafana-server"
fi

grafana-server -v || true
