#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${HOME}/.local/bin/hub-agent"
DO_INSTALL=false

for arg in "$@"; do
  case "$arg" in
    --install) DO_INSTALL=true ;;
    *)
      echo "Uso: $0 [--install]" >&2
      exit 1
      ;;
  esac
done

echo "==> [1/3] Compilando hub_agent_daemon (Dart AOT)..."
cd "${ROOT_DIR}/packages/agent_core"
mkdir -p build
dart compile exe bin/hub_agent_daemon.dart -o build/hub_agent_daemon

echo "==> [2/3] Compilando hub_tray_linux (C / ayatana-appindicator3)..."
cd "${ROOT_DIR}/apps/cms_app/linux/tray_helper"
gcc -Wall -Wextra -Werror -O2 hub_tray_linux.c \
  $(pkg-config --cflags --libs ayatana-appindicator3-0.1 gtk+-3.0) \
  -o "${ROOT_DIR}/packages/agent_core/build/hub_tray_linux"

echo "==> [3/3] Compilando cms_app (Flutter Linux release)..."
cd "${ROOT_DIR}/apps/cms_app"
flutter build linux --release

BUNDLE_DIR="${ROOT_DIR}/apps/cms_app/build/linux/x64/release/bundle"
cp -f "${ROOT_DIR}/packages/agent_core/build/hub_agent_daemon" "${BUNDLE_DIR}/hub_agent_daemon"
cp -f "${ROOT_DIR}/packages/agent_core/build/hub_tray_linux" "${BUNDLE_DIR}/hub_tray_linux"
chmod +x "${BUNDLE_DIR}/hub_agent_daemon" "${BUNDLE_DIR}/hub_tray_linux" "${BUNDLE_DIR}/cms_app"

echo "==> Bundle pronto em: ${BUNDLE_DIR}"
ls -lh "${BUNDLE_DIR}/hub_agent_daemon" "${BUNDLE_DIR}/hub_tray_linux" "${BUNDLE_DIR}/cms_app"

if [ "${DO_INSTALL}" = true ]; then
  echo "==> Instalando em ${INSTALL_DIR}..."
  pkill -f "${INSTALL_DIR}/hub_agent_daemon" 2>/dev/null || true
  pkill -f "${INSTALL_DIR}/hub_tray_linux" 2>/dev/null || true
  pkill -f "${INSTALL_DIR}/cms_app" 2>/dev/null || true
  sleep 0.5

  mkdir -p "${INSTALL_DIR}"
  cp -a "${BUNDLE_DIR}/." "${INSTALL_DIR}/"

  AUTOSTART_FILE="${HOME}/.config/autostart/hub-agent-cms.desktop"
  mkdir -p "$(dirname "${AUTOSTART_FILE}")"
  cat > "${AUTOSTART_FILE}" <<EOF
[Desktop Entry]
Type=Application
Name=Hub Agent Daemon
Comment=Daemon leve do Hub Agent em segundo plano
Exec=${INSTALL_DIR}/hub_agent_daemon
Icon=hub-agent-cms
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

  echo "==> Instalação concluída! Autostart atualizado em ${AUTOSTART_FILE}"
fi
