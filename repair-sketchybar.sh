#!/bin/zsh

set -euo pipefail

SBARLUA_DIR="${HOME}/.local/share/sketchybar_lua"
SBARLUA_SO="${SBARLUA_DIR}/sketchybar.so"
BUILD_INFO="${SBARLUA_DIR}/build-info"

check_only=false
force_rebuild=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      check_only=true
      ;;
    --force)
      force_rebuild=true
      ;;
    *)
      echo "Usage: $0 [--check] [--force]"
      exit 1
      ;;
  esac
  shift
done

progress() {
  echo "\033[1m\033[32m[*]\033[0m $1"
}

success() {
  echo "\033[1m\033[32m[+]\033[0m $1"
}

warn() {
  echo "\033[1m\033[33m[!]\033[0m $1"
}

current_lua_version="$(lua -v 2>&1 | head -n 1)"
current_lua_path="$(command -v lua)"
current_sketchybar_version="$(sketchybar --version)"
current_sketchybar_path="$(command -v sketchybar)"

built_lua_version=""
built_lua_path=""
built_sketchybar_version=""
built_sketchybar_path=""
built_at=""

if [[ -f "${BUILD_INFO}" ]]; then
  while IFS='=' read -r key value; do
    case "${key}" in
      lua_version) built_lua_version="${value}" ;;
      lua_path) built_lua_path="${value}" ;;
      sketchybar_version) built_sketchybar_version="${value}" ;;
      sketchybar_path) built_sketchybar_path="${value}" ;;
      built_at) built_at="${value}" ;;
    esac
  done < "${BUILD_INFO}"
fi

reasons=()

if [[ "${force_rebuild}" == true ]]; then
  reasons+=("forced rebuild requested")
fi

if [[ ! -f "${SBARLUA_SO}" ]]; then
  reasons+=("missing ${SBARLUA_SO}")
fi

if [[ ! -f "${BUILD_INFO}" ]]; then
  reasons+=("missing ${BUILD_INFO}")
fi

if [[ -f "${BUILD_INFO}" && "${built_lua_version}" != "${current_lua_version}" ]]; then
  reasons+=("lua changed from '${built_lua_version}' to '${current_lua_version}'")
fi

if [[ -f "${BUILD_INFO}" && "${built_lua_path}" != "${current_lua_path}" ]]; then
  reasons+=("lua path changed from '${built_lua_path}' to '${current_lua_path}'")
fi

if [[ -f "${BUILD_INFO}" && "${built_sketchybar_version}" != "${current_sketchybar_version}" ]]; then
  reasons+=("Sketchybar changed from '${built_sketchybar_version}' to '${current_sketchybar_version}'")
fi

if [[ -f "${BUILD_INFO}" && "${built_sketchybar_path}" != "${current_sketchybar_path}" ]]; then
  reasons+=("Sketchybar path changed from '${built_sketchybar_path}' to '${current_sketchybar_path}'")
fi

if (( ${#reasons[@]} == 0 )); then
  success "SbarLua is up to date for ${current_lua_version} and ${current_sketchybar_version}"
  if [[ -n "${built_at}" ]]; then
    echo "Built at: ${built_at}"
  fi
  exit 0
fi

warn "SbarLua rebuild recommended:"
for reason in "${reasons[@]}"; do
  echo " - ${reason}"
done

if [[ "${check_only}" == true ]]; then
  exit 1
fi

tmp_dir="$(mktemp -d /tmp/SbarLua.XXXXXX)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

progress "Rebuilding SbarLua..."
git clone https://github.com/FelixKratz/SbarLua.git "${tmp_dir}/SbarLua" >/dev/null 2>&1
(cd "${tmp_dir}/SbarLua" && make install)

mkdir -p "${SBARLUA_DIR}"
{
  printf 'lua_version=%s\n' "${current_lua_version}"
  printf 'lua_path=%s\n' "${current_lua_path}"
  printf 'sketchybar_version=%s\n' "${current_sketchybar_version}"
  printf 'sketchybar_path=%s\n' "${current_sketchybar_path}"
  printf 'built_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "${BUILD_INFO}"

if brew services list | grep -q '^sketchybar'; then
  progress "Restarting Sketchybar..."
  brew services restart sketchybar >/dev/null 2>&1 || true
fi

success "SbarLua rebuilt and metadata updated"
