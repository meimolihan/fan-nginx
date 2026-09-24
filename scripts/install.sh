#!/usr/bin/env bash
#
# fan-nginx - Nginx 图形化管理平台 安装脚本
# 将 fan-nginx jar 发行包安装为 systemd 服务（并裸机部署/检测 Nginx）。
# 可重复执行，升级等同于重新安装（覆盖 jar 并重启服务，数据目录保留）。
#
# Usage:
#   交互式安装（将提示端口与数据目录）:
#     bash scripts/install.sh
#   参数静默安装（-p 端口 / -d 数据目录 / -j jar路径 / -u 管理员 / -P 管理员密码）:
#     bash scripts/install.sh -p 8080 -d /var/lib/fan-nginx
#     bash scripts/install.sh -p 8080 -d /var/lib/fan-nginx -j /tmp/fan-nginx-4.4.2.jar
#   预编译 jar 在线安装（不需要源码/maven）:
#     bash scripts/install.sh -p 8080 -b
#     默认已优先使用二进制（auto）；不指定 -j/-s 且本地无 jar 时自动下载 GitHub Releases 预编译 jar
#   国内网络可用镜像仓库:
#     FAN_NGINX_REPO=https://ghfast.top/https://github.com/meimolihan/fan-nginx.git bash scripts/install.sh -y
#   初始管理员账号（仅首次生效）:
#     bash scripts/install.sh -u admin -P 123456

set -euo pipefail

# ================== terminal colors ==================
list_color_init() {
    export gl_hui=$'\033[38;5;59m'
    export gl_hong=$'\033[38;5;9m'
    export gl_lv=$'\033[38;5;10m'
    export gl_huang=$'\033[38;5;11m'
    export gl_lan=$'\033[38;5;32m'
    export gl_bai=$'\033[38;5;15m'
    export gl_zi=$'\033[38;5;13m'
    export gl_bufan=$'\033[38;5;14m'
    export reset=$'\033[0m'
}
list_color_init

sep_line() {
  printf '%s' "$gl_bufan"
  printf '—%.0s' {1..32}
  printf '%s\n' "$reset"
}

section() {
  printf "  %s %s\n" "${gl_zi}▶${reset}" "$1"
}

ok() {
  printf "  %s %s\n" "${gl_lv}>>>${reset}" "$1"
}

skip() {
  printf "  %s %s\n" "${gl_hui}--${reset}" "$1"
}

print_banner() {
  local z="$gl_zi" r="$reset" b="$gl_bai" l="$gl_lan"
  printf '%s\n' \
    "" \
    "  ${z}┌─────────────────────────────────────────┐${r}" \
    "  ${z}│${r}   ${b}fan-nginx${r}  ${l}Nginx 管理平台 · 安装${r}      ${z}│${r}" \
    "  ${z}└─────────────────────────────────────────┘${r}" \
    ""
}

error() { printf "  %s %s\n" "${gl_hong}[错误]${reset}" "$1" >&2; exit 1; }

# ================== customize me ==================
APP_NAME="fan-nginx"
DEFAULT_PORT=8080
APP_DIR="/var/lib/${APP_NAME}"
DEFAULT_DATA_DIR="${APP_DIR}"
CONFIG_FILE="/etc/${APP_NAME}.conf"
SERVICE_FILE="/etc/systemd/system/${APP_NAME}.service"
CLI_BIN="/usr/local/bin/${APP_NAME}"
CLI_SCRIPT="fan-nginx-cli.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" && pwd)"
DEFAULT_SRC_DIR="${SCRIPT_DIR}/.."
GITHUB_REPO="https://github.com/meimolihan/fan-nginx.git"
GITHUB_BIN_REPO="meimolihan/fan-nginx"

# ================== GitHub 下载加速镜像 ==================
# 原始 GitHub 地址超时/失败时，按下列顺序依次尝试（末尾必须带斜杠）
GITHUB_MIRRORS=(
  "https://ghfast.top/"
  "https://ghproxy.net/"
  "https://gh.xxooo.cf/"
  "https://githubproxy.cc/"
)
# v6.gh-proxy.org 为纯 IPv6 代理：本机未配置 IPv6 地址时剔除，避免每次空等超时
if [ ! -s /proc/net/if_inet6 ]; then
  _no_v6=()
  for _m in "${GITHUB_MIRRORS[@]}"; do
    case "${_m}" in
      *v6.gh-proxy.org*) continue ;;
    esac
    _no_v6+=("${_m}")
  done
  GITHUB_MIRRORS=("${_no_v6[@]}")
fi

# 根据原始 GitHub URL 生成候选地址列表：原始地址优先，然后依次套用各镜像
make_url_candidates() {
  local github_url="$1"
  local p
  printf '%s\n' "$github_url"
  for p in "${GITHUB_MIRRORS[@]}"; do
    printf '%s\n' "${p}${github_url}"
  done
}
# ==========================================================

# 经 curl|bash 远程执行时，SCRIPT_DIR 指向 bash 抽取的临时目录，本地源码仓库
# 需按常见目录回退探测（当前目录 / 上一级目录 / 上级的上级），否则会误判"无本地源码"。
resolve_local_src() {
  local candidates=(
    "${SCRIPT_DIR:-}/.."
    "$(pwd)"
    "$(pwd)/.."
    "$(dirname "$(pwd)")"
    "$(dirname "$(dirname "$(pwd)")")"
  )
  for c in "${candidates[@]}"; do
    if [ -f "${c}/pom.xml" ]; then
      printf '%s' "${c}"
      return 0
    fi
  done
  return 1
}

# 在源码仓库中查找已编译好的 jar（target/fan-nginx-<ver>.jar / fan-nginx.jar）
find_local_jar() {
  local src="$1"
  local jar=""
  jar="$(ls -1 "${src}"/target/fan-nginx-*.jar 2>/dev/null | head -n 1 || true)"
  [ -n "${jar}" ] && printf '%s' "${jar}" && return 0
  [ -f "${src}/fan-nginx.jar" ] && printf '%s' "${src}/fan-nginx.jar" && return 0
  return 1
}

# ================== 命令行解析 ==================
PORT=""
DATA_DIR=""
JAR_PATH=""
SRC_DIR=""
SRC_DIR_EXPLICIT=0
BINARY_MODE="auto"
INSTALL_YES=0
INIT_ADMIN=""
INIT_PASS=""

# ---- bootstrap: support `bash -c "$(curl ...)" -p ... -d ...` ----
case "$0" in
  -*) set -- "$0" "$@" ;;
esac

while [ "$#" -gt 0 ]; do
  case "$1" in
    -p|--port)
      shift
      [ -n "${1:-}" ] || error "缺少 -p/--port 的值"
      PORT="$1"
      ;;
    -d|--data)
      shift
      [ -n "${1:-}" ] || error "缺少 -d/--data 的值"
      DATA_DIR="$1"
      ;;
    -j|--jar)
      shift
      [ -n "${1:-}" ] || error "缺少 -j/--jar 的值"
      JAR_PATH="$1"
      ;;
    -s|--src)
      shift
      [ -n "${1:-}" ] || error "缺少 -s/--src 的值"
      SRC_DIR="$1"
      SRC_DIR_EXPLICIT=1
      ;;
    -b|--binary)
      BINARY_MODE="force"
      ;;
    -u|--username)
      shift
      [ -n "${1:-}" ] || error "缺少 -u/--username 的值"
      INIT_ADMIN="$1"
      ;;
    -P|--password)
      shift
      [ -n "${1:-}" ] || error "缺少 -P/--password 的值"
      INIT_PASS="$1"
      ;;
    -y|--yes)
      INSTALL_YES=1
      ;;
    -h|--help)
      printf "%s\n" "${gl_lan}fan-nginx${reset} - ${gl_bai}Nginx 图形化管理平台 安装脚本${reset}"
      printf "  %-13s %s\n" "${gl_bai}用法:${reset}" "bash scripts/install.sh [-p PORT] [-d DATA_DIR] [-j JAR] [-u USER] [-P PASS] [-b] [-y]"
      printf "  %-13s %s\n" "${gl_bai}-p, --port${reset}" "监听端口（默认 ${gl_lan}${DEFAULT_PORT}${reset}）"
      printf "  %-13s %s\n" "${gl_bai}-d, --data${reset}" "项目数据目录 project.home（默认 ${gl_lan}${DEFAULT_DATA_DIR}${reset}）"
      printf "  %-13s %s\n" "${gl_bai}-j, --jar${reset}" "本地 jar 发行包路径（默认自动查找 target/fan-nginx-*.jar）"
      printf "  %-13s %s\n" "${gl_bai}-s, --src${reset}" "源码仓库路径（默认 ${gl_lan}${DEFAULT_SRC_DIR}${reset}）"
      printf "  %-13s %s\n" "${gl_bai}-b, --binary${reset}" "强制在线下载预编译 jar（无需源码/maven）"
      printf "  %-13s %s\n" "${gl_bai}-u, --username${reset}" "初始管理员用户名（仅首次启动生效）"
      printf "  %-13s %s\n" "${gl_bai}-P, --password${reset}" "初始管理员密码（仅首次启动生效）"
      printf "  %-13s %s\n" "${gl_bai}-y, --yes${reset}" "免交互，未指定项全部使用默认值"
      printf "  %-13s %s\n" "${gl_bai}-h, --help${reset}" "显示本帮助"
      printf "%s\n" "${gl_hui}指定任意参数即进入静默安装；不带参数则为交互式安装。${reset}"
      printf "%s\n" "${gl_hui}默认优先使用 GitHub Releases 预编译 jar（无需源码/maven）；可用 FAN_NGINX_VERSION 指定版本号（默认 latest）。${reset}"
      printf "%s\n" "${gl_hui}国内网络可设 FAN_NGINX_REPO 自定义仓库或镜像地址，如 FAN_NGINX_REPO=https://ghfast.top/https://github.com/meimolihan/fan-nginx.git${reset}"
      printf "%s\n" "${gl_hui}安装后内置 CLI 命令：${gl_bai}fan-nginx${reset}（fan-nginx help 查看用法）${reset}"
      exit 0
      ;;
    *)
      error "未知参数: $1（使用 -h 查看帮助）"
      ;;
  esac
  shift
done

# ---- firewall: automatically open the listen port ----
FW_OPENED="n"
open_firewall_port() {
  local PORT="$1"
  if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
    if ! firewall-cmd --query-port="${PORT}/tcp" >/dev/null 2>&1; then
      firewall-cmd --permanent --add-port="${PORT}/tcp" >/dev/null 2>&1 || true
      firewall-cmd --reload >/dev/null 2>&1 || true
    fi
    ok "已通过 ${gl_bai}firewalld${reset} 开放端口 ${gl_lan}${PORT}/tcp${reset}"
    FW_OPENED="y"
    return 0
  fi

  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
    if ! ufw status 2>/dev/null | grep -q "${PORT}/tcp"; then
      ufw allow "${PORT}/tcp" >/dev/null 2>&1 || true
    fi
    ok "已通过 ${gl_bai}ufw${reset} 开放端口 ${gl_lan}${PORT}/tcp${reset}"
    FW_OPENED="y"
    return 0
  fi

  if command -v iptables >/dev/null 2>&1; then
    if iptables -C INPUT -p tcp --dport "${PORT}" -j ACCEPT >/dev/null 2>&1; then
      ok "端口 ${gl_lan}${PORT}/tcp${reset} 已在 iptables 中放行"
      FW_OPENED="y"
      return 0
    fi
    if iptables -L INPUT -n 2>/dev/null | grep -qE 'policy (DROP|REJECT)|REJECT|DROP'; then
      if iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT >/dev/null 2>&1; then
        ok "已通过 ${gl_bai}iptables${reset} 开放端口 ${gl_lan}${PORT}/tcp${reset}"
        FW_OPENED="y"
        return 0
      fi
    fi
  fi
  printf "  %s %s\n" "${gl_huang}[提示]${reset}" "未检测到活跃的防火墙（firewalld/ufw/iptables），跳过端口开放。"
}

[ "$(id -u)" != "0" ] && error "请以 root 身份运行（例如 sudo bash scripts/install.sh）"

print_banner
sep_line
section "安装信息"
printf "  %-14s %s\n" "${gl_lan}系统${reset}" "$(uname -s) $(uname -m)"
printf "  %-14s %s\n" "${gl_lan}程序${reset}" "${gl_bai}${APP_NAME}${reset}"
sep_line

# ---- Java 运行时检查 ----
check_java_runtime() {
  if ! command -v java >/dev/null 2>&1; then
    error "未检测到 Java（要求 >= 8），请先安装，例如：apt install openjdk-8-jre / openjdk-11-jre"
  fi
  JAVA_BIN="$(command -v java)"
  ok "Java 运行时：${gl_bai}${JAVA_BIN}${reset}"
}

# ---- 检测/安装 nginx（裸机部署时 fan-nginx 依赖本机 nginx）----
ensure_nginx() {
  if command -v nginx >/dev/null 2>&1; then
    ok "Nginx：${gl_bai}nginx $(nginx -v 2>&1 | awk '{print $3}' || true)${reset}"
    return 0
  fi
  printf "  %s\n" "${gl_huang}[提示]${reset} 未检测到 nginx，尝试为 ${gl_bai}${APP_NAME}${reset} 安装 ..."
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update >/dev/null 2>&1 || true
    apt-get install -y nginx >/dev/null 2>&1 && { ok "已通过 apt 安装 nginx"; return 0; }
  elif command -v yum >/dev/null 2>&1; then
    yum install -y nginx >/dev/null 2>&1 && { ok "已通过 yum 安装 nginx"; return 0; }
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y nginx >/dev/null 2>&1 && { ok "已通过 dnf 安装 nginx"; return 0; }
  fi
  printf "  %s\n" "${gl_huang}[警告]${reset} nginx 安装失败，面板可正常启动，但 Nginx 配置管理功能需本机存在 nginx 命令。"
}

# ---- 安装方式判定：预编译 jar 优先，可回退本地 jar ----
INSTALL_METHOD="source"
JAR_VER=""
local_src="$(resolve_local_src)" || true
local_jar=""
if [ -n "${local_src}" ]; then
  local_jar="$(find_local_jar "${local_src}" || true)"
fi
if [ "${BINARY_MODE}" = "force" ]; then
  INSTALL_METHOD="binary"
elif [ -n "${JAR_PATH}" ]; then
  INSTALL_METHOD="source"
elif [ -n "${SRC_DIR_EXPLICIT}" ] && [ "${SRC_DIR_EXPLICIT}" = "1" ]; then
  INSTALL_METHOD="source"
elif [ -n "${local_jar}" ]; then
  INSTALL_METHOD="source"
else
  INSTALL_METHOD="binary"
fi

if [ "${INSTALL_METHOD}" = "binary" ]; then
  ok "安装方式：${gl_lan}在线预编译 jar${reset}（单文件，无需源码/maven）"
else
  ok "安装方式：${gl_lan}本地 jar${reset}"
  check_java_runtime
fi

# ---- 下载并使用预编译 jar ----
install_jar() {
  local tag="${FAN_NGINX_VERSION:-latest}" name="" url_path="" tmp="" hdr="" magic="" url=""
  if [ -n "${JAR_PATH}" ] && [ -f "${JAR_PATH}" ]; then
    name="$(basename "${JAR_PATH}")"
    case "${name}" in
      fan-nginx-*.jar)
        JAR_VER="${name#fan-nginx-}"
        JAR_VER="${JAR_VER%.jar}"
        ;;
    esac
    cp -f "${JAR_PATH}" "${APP_DIR}/${name}"
    chmod +x "${APP_DIR}/${name}"
    ok "已部署本地 jar ${gl_bai}${APP_DIR}/${name}${reset}"
    return 0
  fi
  if [ "${tag}" = "latest" ]; then
    # latest 不能确定文件名中的版本号，改为查询重定向地址
    url_path="releases/latest/download"
    name="fan-nginx-4.4.2.jar"
    printf "  %s\n" "${gl_huang}[提示]${reset} 未指定版本号，将下载最新 release。"
  else
    case "${tag}" in v*) ;; *) tag="v${tag}" ;; esac
    url_path="releases/download/${tag}"
    name="fan-nginx-${tag#v}.jar"
    JAR_VER="${tag#v}"
  fi
  ok "下载预编译 jar ${gl_bai}${name}${reset}（版本 ${gl_lan}${tag}${reset}）"

  if command -v curl >/dev/null 2>&1; then
    DL_CURL="y"
  elif command -v wget >/dev/null 2>&1; then
    DL_CURL="n"
  else
    printf "  %s\n" "${gl_huang}[警告]${reset} 未检测到 curl/wget，无法下载 jar。"
    return 1
  fi

  tmp="$(mktemp)"
  hdr="${tmp}.hdr"

  local candidates=()
  mapfile -t candidates < <(make_url_candidates "https://github.com/${GITHUB_BIN_REPO}/${url_path}/${name}")

  for url in "${candidates[@]}"; do
    skip "尝试下载 ${gl_bai}${url}${reset}"
    rm -f "${tmp}" "${hdr}"
    DL_FAIL="n"
    if [ "${DL_CURL}" = "y" ]; then
      if command -v timeout >/dev/null 2>&1; then
        timeout 180 curl -fsSL --connect-timeout 10 --max-time 180 \
          -o "${tmp}" -D "${hdr}" "${url}" 2>/dev/null || DL_FAIL="y"
      else
        curl -fsSL --connect-timeout 10 --max-time 180 \
          -o "${tmp}" -D "${hdr}" "${url}" 2>/dev/null || DL_FAIL="y"
      fi
    else
      wget -qO "${tmp}" --timeout=180 --tries=1 "${url}" 2>/dev/null || DL_FAIL="y"
    fi

    if [ "${DL_FAIL}" = "y" ] || [ ! -s "${tmp}" ]; then
      printf "  %s\n" "${gl_huang}[警告]${reset} 下载失败：${url}"
      continue
    fi

    # 大小核对：镜像/Cache 可能返回被截断的残缺文件（curl 认为传输正常）
    if [ "${DL_CURL}" = "y" ] && [ -f "${hdr}" ]; then
      expected="$(grep -i '^content-length:' "${hdr}" | tail -n 1 | tr -d '\r' | awk '{print $2}')"
      actual="$(stat -c%s "${tmp}" 2>/dev/null || echo 0)"
      if [ -n "${expected}" ] && [ "${actual}" != "${expected}" ]; then
        printf "  %s\n" "${gl_huang}[警告]${reset} 文件不完整（${actual}/${expected} 字节），跳过该源。"
        continue
      fi
    fi

    # 校验 ZIP 头（jar 为 zip 格式）
    magic="$(head -c4 "${tmp}" | od -An -tx1 | tr -d ' \n')"
    if [ "${magic}" != "504b0304" ]; then
      printf "  %s\n" "${gl_huang}[警告]${reset} 下载内容不是 jar 文件，跳过该源。"
      continue
    fi

    mkdir -p "${APP_DIR}"
    cp -f "${tmp}" "${APP_DIR}/${name}"
    chmod 644 "${APP_DIR}/${name}"
    rm -f "${tmp}" "${hdr}"
    ok "jar 已安装至 ${gl_bai}${APP_DIR}/${name}${reset}"
    return 0
  done
  rm -f "${tmp}" "${hdr}"
  printf "  %s\n" "${gl_huang}[警告]${reset} 所有源均下载失败/校验未通过。"
  return 1
}

# ---- silent install detection ----
SILENT="n"
if [ -n "${PORT}" ]; then
  case "${PORT}" in
    ''|*[!0-9]*) error "PORT 无效（需为 1‑65535 的数字）: ${PORT}" ;;
    *) [ "${PORT}" -ge 1 ] && [ "${PORT}" -le 65535 ] || error "PORT 超出范围（1‑65535）: ${PORT}" ;;
  esac
  SILENT="y"
fi
if [ -n "${DATA_DIR}" ]; then
  SILENT="y"
fi
if [ -n "${JAR_PATH}" ]; then
  SILENT="y"
fi
if [ -n "${SRC_DIR}" ]; then
  SILENT="y"
fi
if [ ! -t 0 ]; then
  SILENT="y"
fi

section "配置参数"
# port prompt
if [ -z "${PORT}" ]; then
  if [ "$INSTALL_YES" = "1" ] || [ ! -t 0 ]; then
    PORT="${DEFAULT_PORT}"
  else
    while :; do
      read -r -p "${gl_bai}请输入监听端口${reset} ${gl_hui}[默认: ${DEFAULT_PORT}]${reset}: " PORT
      PORT="${PORT:-$DEFAULT_PORT}"
      case "$PORT" in
        ''|*[!0-9]*) printf "  %s\n" "${gl_huang}端口无效，请重新输入。${reset}" ;;
        *)
          if [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; then break; fi
          printf "  %s\n" "${gl_huang}端口超出范围（1‑65535），请重新输入。${reset}"
          ;;
      esac
    done
  fi
else
  printf "  %-14s %s\n" "${gl_lan}监听端口${reset}" "${gl_bai}${PORT}${reset}（参数指定）"
fi
PORT="${PORT:-$DEFAULT_PORT}"

# data dir prompt
if [ -z "${DATA_DIR}" ]; then
  if [ "$INSTALL_YES" = "1" ] || [ ! -t 0 ]; then
    DATA_DIR="${DEFAULT_DATA_DIR}"
  else
    read -r -p "${gl_bai}请输入数据目录${reset} ${gl_hui}[默认: ${DEFAULT_DATA_DIR}]${reset}: " DATA_DIR
    DATA_DIR="${DATA_DIR:-$DEFAULT_DATA_DIR}"
  fi
else
  printf "  %-14s %s\n" "${gl_lan}数据目录${reset}" "${gl_bai}${DATA_DIR}${reset}（参数指定）"
fi
DATA_DIR="${DATA_DIR:-$DEFAULT_DATA_DIR}"

# 初始管理员提示
if [ -n "${INIT_ADMIN}" ] && [ -z "${INIT_PASS}" ]; then
  read -r -p "${gl_bai}请输入初始管理员密码${reset}（留空则不初始化账号）: " INIT_PASS
fi

if command -v systemctl >/dev/null 2>&1; then
  USE_SYSTEMD="y"
else
  USE_SYSTEMD="n"
  printf "  %s\n" "${gl_huang}[警告]${reset} 未检测到 systemd（容器或受限环境），将回退为后台运行模式。"
fi

check_java_runtime
ensure_nginx

# ---- 获取 jar ----
sep_line
section "安装程序"
ok "正在安装 ${gl_bai}${APP_NAME}${reset} 程序 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"

mkdir -p "${APP_DIR}"
mkdir -p "${DATA_DIR}"
chmod 700 "${DATA_DIR}" 2>/dev/null || true

if [ "${INSTALL_METHOD}" = "binary" ]; then
  if ! install_jar; then
    if [ "${BINARY_MODE}" = "force" ]; then
      error "在线 jar 安装失败（-b 强制在线模式），可用 -j 指定本地 jar 重新安装"
    fi
    printf "  %s\n" "${gl_huang}[警告]${reset} 在线 jar 获取失败，回退为本地源码/jar 安装。"
    INSTALL_METHOD="source"
  fi
fi

if [ "${INSTALL_METHOD}" = "source" ]; then
  if [ -n "${JAR_PATH}" ] && [ ! -f "${JAR_PATH}" ]; then
    error "指定的 jar 不存在: ${JAR_PATH}"
  fi
  if [ -z "${JAR_PATH}" ]; then
    if [ -n "${SRC_DIR}" ]; then
      JAR_PATH="$(find_local_jar "${SRC_DIR}" || true)"
    fi
    if [ -z "${JAR_PATH}" ] && [ -n "${local_jar}" ]; then
      JAR_PATH="${local_jar}"
    fi
  fi
  if [ -z "${JAR_PATH}" ] || [ ! -f "${JAR_PATH}" ]; then
    # 有 maven 则现场编译
    if command -v mvn >/dev/null 2>&1; then
      SRC="${SRC_DIR:-${SCRIPT_DIR}/..}"
      printf "  %s\n" "${gl_huang}[提示]${reset} 未找到本地 jar，使用 maven 现场编译（${gl_bai}${SRC}${reset}）..."
      ( cd "${SRC}" && mvn clean package >/dev/null )
      JAR_PATH="$(find_local_jar "${SRC}" || true)"
    fi
  fi
  [ -z "${JAR_PATH}" ] || [ ! -f "${JAR_PATH}" ] && error "未找到可安装的 jar。请使用 -j 指定 jar 路径，或先编译（mvn clean package），或使用 -b 在线下载。"
  name="$(basename "${JAR_PATH}")"
  case "${name}" in
    fan-nginx-*.jar)
      JAR_VER="${name#fan-nginx-}"
      JAR_VER="${JAR_VER%.jar}"
      ;;
  esac
  cp -f "${JAR_PATH}" "${APP_DIR}/${name}"
  JAR_PATH="${APP_DIR}/${name}"
  ok "已部署 jar 至 ${gl_bai}${JAR_PATH}${reset}"
fi

# ---- 显示实际部署的 jar ----
JAR_NAME="$(basename "${JAR_PATH}")"
[ -z "${JAR_VER}" ] && JAR_VER="unknown"
ok "jar 版本：${gl_lan}${JAR_VER}${reset}"

# ---- 部署运维脚本（面板"备份/还原"依赖，失败仅告警不阻断）----
mkdir -p "${APP_DIR}/scripts" 2>/dev/null || true
for script_name in fan-nginx_backup.sh fan-nginx_recover.sh; do
  _src="${SCRIPT_DIR}/${script_name}"
  if [ -f "${_src}" ]; then
    cp -f "${_src}" "${APP_DIR}/scripts/${script_name}" 2>/dev/null && chmod +x "${APP_DIR}/scripts/${script_name}"
    ok "已部署运维脚本 ${gl_bai}${script_name}${reset}"
  else
    local raw_candidates=()
    mapfile -t raw_candidates < <(make_url_candidates "https://github.com/${GITHUB_BIN_REPO}/raw/main/scripts/${script_name}")
    for raw_url in "${raw_candidates[@]}"; do
      DL_OK="n"
      curl -fsSL --connect-timeout 10 --max-time 60 "${raw_url}" > "${APP_DIR}/scripts/${script_name}" 2>/dev/null && DL_OK="y"
      if [ "${DL_OK}" = "y" ] && [ -s "${APP_DIR}/scripts/${script_name}" ] \
        && grep -q '^#!/bin/bash' "${APP_DIR}/scripts/${script_name}"; then
        chmod +x "${APP_DIR}/scripts/${script_name}"
        ok "已下发运维脚本 ${gl_bai}${script_name}${reset}"
        break
      fi
      rm -f "${APP_DIR}/scripts/${script_name}"
    done
  fi
done

# ---- 安装记录 ----
mkdir -p "$(dirname "${CONFIG_FILE}")"
cat > "${CONFIG_FILE}" <<EOF
# ${APP_NAME} 安装记录（由 install.sh 生成，请勿手动修改）
APP_NAME=${APP_NAME}
APP_DIR=${APP_DIR}
PORT=${PORT}
DATA_DIR=${DATA_DIR}
BACKUP_DIR=${APP_DIR}/backup
JAR_PATH=${JAR_PATH}
JAR_NAME=${JAR_NAME}
VERSION=${JAR_VER}
JAVA_BIN=${JAVA_BIN}
EOF
chmod 0644 "${CONFIG_FILE}"
ok "已写入安装记录 ${gl_bai}${CONFIG_FILE}${reset}"

# ---- 安装内置 CLI 命令 ----
# 将 CLI 部署至 APP_DIR/scripts，并在 /usr/local/bin 建立软链：
# 软链方式保证 CLI 能定位同目录的 uninstall.sh（卸载命令依赖）
CLI_SRC="${SCRIPT_DIR}/${CLI_SCRIPT}"
if [ ! -f "${CLI_SRC}" ]; then
  CLI_SRC="${APP_DIR}/scripts/${CLI_SCRIPT}"
fi
if [ -f "${CLI_SRC}" ]; then
  cp -f "${CLI_SRC}" "${APP_DIR}/scripts/${CLI_SCRIPT}"
  chmod +x "${APP_DIR}/scripts/${CLI_SCRIPT}"
  rm -f "${CLI_BIN}"
  ln -sf "${APP_DIR}/scripts/${CLI_SCRIPT}" "${CLI_BIN}"
  ok "已安装命令 ${gl_bai}${CLI_BIN}${reset}（运行 ${gl_bai}${APP_NAME} help${reset} 查看用法）"
fi

# ---- 启动服务 ----
sep_line
section "启动服务"
INIT_ARGS=""
[ -n "${INIT_ADMIN}" ] && INIT_ARGS=" --init.admin=${INIT_ADMIN}"
[ -n "${INIT_PASS}" ] && INIT_ARGS="${INIT_ARGS} --init.pass=${INIT_PASS}"
[ -n "${INIT_ADMIN}" ] && INIT_ARGS="${INIT_ARGS} --init.api=true"

EXEC_START="${JAVA_BIN} -Xmx128m -jar -Dfile.encoding=UTF-8 ${JAR_PATH} --server.port=${PORT} --project.home=${DATA_DIR}/${INIT_ARGS}"

if [ "${USE_SYSTEMD}" = "y" ]; then
  cat > "${SERVICE_FILE}" <<UNIT
[Unit]
Description=${APP_NAME} - Nginx 图形化管理平台
After=network-online.target local-fs.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
# KillMode=process：systemctl stop 只终止主 java 进程，不波及面板 spawn 的备份/还原脚本
KillMode=process
ExecStart=${EXEC_START}
WorkingDirectory=${APP_DIR}
Environment=TZ=Asia/Shanghai
Restart=on-failure
RestartSec=3
# 面板 stop 缓慢时快速收敛，避免备份/还原时 systemctl stop 长时间阻塞
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
UNIT

  systemctl daemon-reload
  systemctl enable "${APP_NAME}" >/dev/null 2>&1 || true
  systemctl restart "${APP_NAME}"
  sleep 4
  if systemctl is-active "${APP_NAME}" >/dev/null 2>&1; then
    ok "${gl_bai}${APP_NAME}${reset} 服务已启动。"
    systemctl status "${APP_NAME}" --no-pager || true
  else
    printf "  %s\n" "${gl_hong}[错误]${reset} 服务启动失败，请检查：${gl_bai}journalctl -u ${APP_NAME} -n 50${reset}" >&2
    exit 1
  fi
else
  if command -v pgrep >/dev/null 2>&1 && pgrep -f "fan-nginx.*\.jar" >/dev/null 2>&1; then
    printf "  %s\n" "${gl_huang}[警告]${reset} 检测到 ${APP_NAME} 进程可能已在运行"
  else
    nohup ${JAVA_BIN} -Xmx128m -jar -Dfile.encoding=UTF-8 ${JAR_PATH} --server.port=${PORT} --project.home=${DATA_DIR}/ ${INIT_ARGS} >> "${DATA_DIR}/${APP_NAME}.log" 2>&1 &
    ok "${APP_NAME} 已在后台启动，pid: ${gl_bai}$!${reset}"
  fi
fi

# 取第一个IPv4
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
[ -z "${IP}" ] && IP="<服务器IP>"

open_firewall_port "${PORT}"

if [ "${FW_OPENED}" = "y" ]; then
  FW_STATUS="${gl_lv}已开放 ${PORT}/tcp${reset}"
else
  FW_STATUS="${gl_huang}未检测到活跃防火墙，已跳过${reset}"
fi

sep_line
if [ "${USE_SYSTEMD}" = "y" ]; then
  printf "  %s\n" "${gl_lv}✔ ${APP_NAME} 安装成功！${reset}"
  printf "  %-14s %s\n" "${gl_lan}访问地址${reset}" "${gl_bai}http://${IP}:${PORT}${reset}"
  printf "  %-14s %s\n" "${gl_lan}数据目录${reset}" "${gl_bai}${DATA_DIR}${reset}"
  printf "  %-14s %s\n" "${gl_lan}程序目录${reset}" "${gl_bai}${APP_DIR}${reset}"
  printf "  %-14s %s\n" "${gl_lan}jar 版本${reset}" "${gl_bai}${JAR_VER}${reset}"
  printf "  %-14s %s\n" "${gl_lan}防火墙状态${reset}" "$FW_STATUS"
  printf "  %-14s %s\n" "${gl_lan}运行模式${reset}" "${gl_bai}systemd 服务${reset}"
  printf "  %-14s %s\n" "${gl_lan}服务命令${reset}" "${gl_hui}systemctl status ${APP_NAME}${reset} / ${gl_bai}${APP_NAME} status${reset}"
  printf "  %-14s %s\n" "${gl_lan}升级方式${reset}" "${gl_hui}重新执行 scripts/install.sh（数据自动保留）${reset}"
  printf "  %-14s %s\n" "${gl_lan}账号密码${reset}" "${gl_huang}$([ -n \"${INIT_ADMIN}\" ] && echo \"${INIT_ADMIN} / ${INIT_PASS}\" || echo '首次打开页面时设置（或 fan-nginx credentials）')${reset}"
else
  printf "  %s\n" "${gl_lv}✔ ${APP_NAME} 安装成功！${reset} ${gl_huang}（后台运行模式）${reset}"
  printf "  %-14s %s\n" "${gl_lan}访问地址${reset}" "${gl_bai}http://${IP}:${PORT}${reset}"
  printf "  %s\n" "  ${gl_huang}注意：${reset}后台运行模式在系统重启后不会自动恢复。"
fi
sep_line