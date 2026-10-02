#!/usr/bin/env bash

set -euo pipefail

readonly PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DERIVED_DATA_DIR="${PROJECT_DIR}/.build/DerivedData"
readonly BUILT_APP="${DERIVED_DATA_DIR}/Build/Products/Release/Quarda.app"
readonly INSTALL_DIR="${QUARDA_INSTALL_DIR:-/Applications}"
readonly INSTALLED_APP="${INSTALL_DIR}/Quarda.app"
readonly LEGACY_QUADRA_APP="${INSTALL_DIR}/Quadra.app"
readonly LEGACY_EISENHOWER_APP="${INSTALL_DIR}/Eisenhower Matrix.app"

echo "Собираем Quarda…"
xcodebuild \
  -project "${PROJECT_DIR}/Quarda.xcodeproj" \
  -scheme Quarda \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "${DERIVED_DATA_DIR}" \
  CODE_SIGNING_ALLOWED=NO \
  -quiet \
  build

echo "Подписываем приложение локальной подписью…"
/usr/bin/codesign --force --deep --sign - "${BUILT_APP}"

echo "Закрываем предыдущую версию Quarda…"
/usr/bin/pkill -x Quarda 2>/dev/null || true
/usr/bin/pkill -x Quadra 2>/dev/null || true
/usr/bin/pkill -x EisenhowerMatrix 2>/dev/null || true

install_app() {
  /bin/mkdir -p "${INSTALL_DIR}"
  if [[ -e "${INSTALLED_APP}" ]]; then
    /bin/rm -rf "${INSTALLED_APP}"
  fi
  if [[ -e "${LEGACY_QUADRA_APP}" ]]; then
    /bin/rm -rf "${LEGACY_QUADRA_APP}"
  fi
  if [[ -e "${LEGACY_EISENHOWER_APP}" ]]; then
    /bin/rm -rf "${LEGACY_EISENHOWER_APP}"
  fi
  /usr/bin/ditto "${BUILT_APP}" "${INSTALLED_APP}"
}

echo "Устанавливаем приложение в ${INSTALLED_APP}…"
if [[ ! -d "${INSTALL_DIR}" ]]; then
  if ! /bin/mkdir -p "${INSTALL_DIR}" 2>/dev/null; then
    sudo /bin/mkdir -p "${INSTALL_DIR}"
  fi
fi

if [[ -w "${INSTALL_DIR}" ]]; then
  install_app
else
  if [[ -e "${INSTALLED_APP}" ]]; then
    sudo /bin/rm -rf "${INSTALLED_APP}"
  fi
  if [[ -e "${LEGACY_QUADRA_APP}" ]]; then
    sudo /bin/rm -rf "${LEGACY_QUADRA_APP}"
  fi
  if [[ -e "${LEGACY_EISENHOWER_APP}" ]]; then
    sudo /bin/rm -rf "${LEGACY_EISENHOWER_APP}"
  fi
  sudo /usr/bin/ditto "${BUILT_APP}" "${INSTALLED_APP}"
fi

echo "Готово: ${INSTALLED_APP}"

if [[ "${QUARDA_SKIP_OPEN:-0}" != "1" ]]; then
  /usr/bin/open "${INSTALLED_APP}"
fi
