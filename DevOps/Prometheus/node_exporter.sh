#!/usr/bin/env bash
#--------------------------------------------------------------------
# Улучшенный скрипт установки Prometheus Node Exporter на Linux
# Поддержка: x86_64 (amd64), aarch64 (arm64), armv7 (armv7)
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
    log_error "Скрипт должен быть запущен с правами root (sudo)."
    exit 1
fi

install_dependencies() {
    local pkgs=()
    command -v curl >/dev/null 2>&1 || pkgs+=(curl)
    command -v tar >/dev/null 2>&1  || pkgs+=(tar)

    if [ ${#pkgs[@]} -gt 0 ]; then
        log_info "Установка зависимостей: ${pkgs[*]}..."
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update -qq && apt-get install -y -qq "${pkgs[@]}"
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y -q "${pkgs[@]}"
        elif command -v yum >/dev/null 2>&1; then
            yum install -y -q "${pkgs[@]}"
        else
            log_error "Не удалось определить пакетный менеджер. Установите вручную: ${pkgs[*]}"
            exit 1
        fi
    fi
}

# Определение архитектуры процессора
detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64)          echo "amd64" ;;
        aarch64|arm64)   echo "arm64" ;;
        armv7l|armhf)    echo "armv7" ;;
        *)
            log_error "Неподдерживаемая архитектура: $arch"
            exit 1
            ;;
    esac
}

get_latest_version() {
    local latest
    latest=$(curl -sSL -H "Accept: application/vnd.github+json" https://api.github.com/repos/prometheus/node_exporter/releases/latest \
        | grep -Po '"tag_name":\s*"v\K[^"]*' || true)
    
    if [ -z "$latest" ]; then
        log_warn "Не удалось запросить последнюю версию через API. Используется fallback: 1.8.2"
        echo "1.8.2"
    else
        echo "$latest"
    fi
}
# creating system user
create_user() {
    if ! id -u node_exporter >/dev/null 2>&1; then
        log_info "Создание системного пользователя node_exporter..."
        useradd --system --no-create-home --shell /usr/sbin/nologin node_exporter
    fi
}

install_dependencies

ARCH=$(detect_arch)
VERSION=${NODE_EXPORTER_VERSION:-$(get_latest_version)}
TMP_DIR=$(mktemp -d)
TAR_FILE="node_exporter-${VERSION}.linux-${ARCH}.tar.gz"
URL="https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/${TAR_FILE}"

log_info "Целевая версия: v${VERSION} | Архитектура: ${ARCH}"
log_info "Скачивание ${URL}..."

curl -sSL "$URL" -o "${TMP_DIR}/${TAR_FILE}"
tar -xzf "${TMP_DIR}/${TAR_FILE}" -C "$TMP_DIR"

log_info "Установка бинарного файла в /usr/local/bin..."
install -m 0755 -o root -g root "${TMP_DIR}/node_exporter-${VERSION}.linux-${ARCH}/node_exporter" /usr/local/bin/node_exporter

# Очистка временных файлов
rm -rf "$TMP_DIR"

create_user

# Создание директории и файла для аргументов запуска
mkdir -p /etc/default
if [ ! -f /etc/default/node_exporter ]; then
    cat <<'EOF' > /etc/default/node_exporter
NODE_EXPORTER_OPTS="--web.listen-address=:9100 --collector.systemd"
EOF
fi

log_info "Настройка systemd-сервиса..."
cat <<'EOF' > /etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
Documentation=https://github.com/prometheus/node_exporter
After=network-online.target
Wants=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
EnvironmentFile=-/etc/default/node_exporter
ExecStart=/usr/local/bin/node_exporter $NODE_EXPORTER_OPTS
Restart=on-failure
RestartSec=5s

# Усиление изоляции процесса (Hardening)
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF

log_info "Перезапуск и включение сервиса..."
systemctl daemon-reload
systemctl enable --now node_exporter

# Проверка доступности метрик
sleep 1
if curl -s -f http://localhost:9100/metrics >/dev/null; then
    log_info "Node Exporter успешно запущен и отдает метрики на порту 9100!"
else
    log_warn "Сервис запущен, но эндпоинт http://localhost:9100/metrics пока не отвечает."
fi

/usr/local/bin/node_exporter --version
