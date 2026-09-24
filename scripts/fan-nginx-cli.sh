#!/bin/bash
#
# fan-nginx CLI（与 fan-webssh 系列面板一致的命令风格）
# 在 install.sh 安装时通过软链接部署为 /usr/local/bin/fan-nginx，
# 以便无需记住繁琐的 java 命令即可管理服务、查看/重置管理员账号密码、卸载。
#
# 用法:
#   fan-nginx status                  显示运行方式/systemd状态/PID/端口/访问地址/运行时长/内存/路径
#   fan-nginx credentials             重置并打印全部管理员账号密码(关闭两步验证)
#   fan-nginx start|stop|restart      启停/重启 systemd 服务
#   fan-nginx uninstall [-y] [--purge|--keep-data]
#   fan-nginx version                 显示版本号
#   fan-nginx help                    显示帮助
set -u

GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'

self_realpath() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null && return 0
    fi
    local d
    d=$(cd "$(dirname "$1")" && pwd -P)
    echo "${d}/$(basename "$1")"
}

# CLI 所在目录(解析软链接), 以便定位 uninstall.sh / credentials jar 等
CLI_PATH=$(self_realpath "${BASH_SOURCE[0]}")
CLI_DIR=$(dirname "${CLI_PATH}")
SCRIPTS_DIR=$(dirname "${CLI_DIR}")    # 可能为 APP_DIR 或 APP_DIR/scripts
DATA_DIR="${FAN_NGINX_DATA_DIR:-}"
[ -z "${DATA_DIR}" ] && [ -f /etc/fan-nginx.conf ] && DATA_DIR=$(sed -n 's/^DATA_DIR=//p' /etc/fan-nginx.conf 2>/dev/null)
[ -z "${DATA_DIR}" ] && [ -f /etc/fan-nginx.conf ] && DATA_DIR=$(grep -E '^(DATA_DIR|APP_DIR)=' /etc/fan-nginx.conf 2>/dev/null | head -n1 | cut -d= -f2-)
APP_DIR="${DATA_DIR}"

find_pids() {
    local pat=$1
    ps -eo pid=,comm=,args= 2>/dev/null | awk -v p="$pat" '$3 ~ p {print $1}'
}

version() {
    local f
    for f in "${DATA_DIR}"/fan-nginx-*.jar "${DATA_DIR}"/fan-nginx.jar; do
        [ -f "${f}" ] && { basename "$f" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1; return 0; }
    done
    echo "unknown"
}

is_systemd_manage() {
    [ -f /run/systemd/system ] || command -v systemctl >/dev/null 2>&1 || return 1
    systemctl cat fan-nginx.service >/dev/null 2>&1
}

service_active() { systemctl is-active fan-nginx.service >/dev/null 2>&1; }

systemd_main_pid() { systemctl show -p MainPID --value fan-nginx.service 2>/dev/null; }

proc_uptime() {
    local pid=$1
    if [ -n "${pid}" ] && [ "${pid}" != "0" ] && [ -r "/proc/${pid}/stat" ]; then
        local start_s since uptime_s clock
        clock=$(getconf CLK_TCK 2>/dev/null || echo 100)
        start_s=$(awk '{print $22}' "/proc/${pid}/stat")
        since=$(awk '{print int($1)}' /proc/uptime)
        uptime_s=$(( (since - start_s) / clock ))
        [ "${uptime_s}" -lt 0 ] && uptime_s=0
        echo "${uptime_s}"
        return 0
    fi
}

format_uptime() {
    local s=$1
    [ "${s}" -lt 60 ] && { echo "${s} 秒"; return; }
    [ "${s}" -lt 3600 ] && { echo "$((s / 60)) 分 $((s % 60)) 秒"; return; }
    [ "${s}" -lt 86400 ] && { echo "$((s / 3600)) 时 $(((s % 3600) / 60)) 分"; return; }
    echo "$((s / 86400)) 天 $(((s % 86400) / 3600)) 时"
}

proc_mem() {
    local pid=$1
    if [ -n "${pid}" ] && [ -r "/proc/${pid}/status" ]; then
        local kb; kb=$(awk '/^VmRSS:/{print $2}' "/proc/${pid}/status")
        echo "$(( kb / 1024 )) MB"
    else
        echo "-"
    fi
}

detect_port() {
    local port=""
    port=$(grep -oE -- '--server.port=[0-9]+' /etc/systemd/system/fan-nginx.service 2>/dev/null | head -n1 | cut -d= -f2)
    [ -z "${port}" ] && port=$(systemctl cat fan-nginx.service 2>/dev/null | grep -oE -- '--server\.port=[0-9]+' | head -n1 | cut -d= -f2)
    [ -z "${port}" ] && port="8080"
    echo "${port}"
}

detect_jar() {
    systemctl cat fan-nginx.service 2>/dev/null | grep -oE '[^ ]*fan-nginx-[0-9.]+\.jar|[^ ]*fan-nginx\.jar' | head -n1
}

print_status() {
    echo -e "${CYAN}━━━ fan-nginx 运行状态 ━━━${RESET}"
    if is_systemd_manage; then
        echo -e "${GREEN}运行方式:${RESET} systemd (fan-nginx.service)"
        echo -e "${GREEN}systemd 状态:${RESET} $(systemctl is-active fan-nginx.service 2>/dev/null)"
        echo -e "${GREEN}开机自启:${RESET} $(systemctl is-enabled fan-nginx.service 2>/dev/null)"
        local pid; pid=$(systemd_main_pid)
        echo -e "${GREEN}PID:${RESET} ${pid:-无}"
        if service_active && [ -n "${pid}" ] && [ "${pid}" != "0" ]; then
            echo -e "${GREEN}运行时长:${RESET} $(format_uptime "$(proc_uptime "${pid}")")"
            echo -e "${GREEN}内存占用:${RESET} $(proc_mem "${pid}")"
        fi
        echo -e "${GREEN}端口:${RESET} $(detect_port)"
        local jar; jar=$(detect_jar)
        echo -e "${GREEN}jar 路径:${RESET} ${jar:-未知}"
        echo -e "${GREEN}数据目录:${RESET} ${DATA_DIR:-未知}"
        local ip hostname
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        hostname=$(hostname 2>/dev/null)
        echo -e "${GREEN}访问地址:${RESET} http://${ip:-127.0.0.1}:$(detect_port) (主机名:${hostname:-未知})"
    else
        echo -e "${GREEN}运行方式:${RESET} 非 systemd(后台 jar 进程)"
        local pids; pids=$(find_pids 'fan-nginx')
        if [ -n "${pids}" ]; then
            echo -e "${GREEN}PID:${RESET} $(echo "${pids}" | tr '\n' ' ')"
            local pid; pid=$(echo "${pids}" | head -n1)
            echo -e "${GREEN}运行时长:${RESET} $(format_uptime "$(proc_uptime "${pid}")")"
            echo -e "${GREEN}内存占用:${RESET} $(proc_mem "${pid}")"
        else
            echo -e "${RED}未发现运行中的 fan-nginx 进程${RESET}"
        fi
        echo -e "${GREEN}端口:${RESET} $(detect_port)"
        echo -e "${GREEN}数据目录:${RESET} ${DATA_DIR:-未知}"
    fi
    echo -e "${GREEN}版本:${RESET} $(version)"
    echo -e "${GREEN}配置文件:${RESET} /etc/fan-nginx.conf"
    echo
}

do_credentials() {
    # 等价于 fan-nginx 面板的 --project.findPass=true：打印全部账号密码并关闭两步验证
    local jar=""
    for f in "${DATA_DIR}"/fan-nginx-*.jar "${DATA_DIR}"/fan-nginx.jar; do
        [ -f "${f}" ] && { jar="${f}"; break; }
    done
    if [ -z "${jar}" ]; then
        echo -e "${RED}未在数据目录 ${DATA_DIR} 找到 jar，请先执行 install.sh 安装${RESET}" >&2
        return 1
    fi
    local java_bin="java"
    command -v "${java_bin}" >/dev/null 2>&1 || { echo -e "${RED}未安装 Java 运行环境(java)，无法执行${RESET}" >&2; return 1; }
    echo -e "${YELLOW}正在重置管理员密码并关闭两步验证...${RESET}"
    "${java_bin}" -jar "${jar}" --project.home="${DATA_DIR}/" --project.findPass=true
}

do_start()   { systemctl start fan-nginx.service; echo -e "${GREEN}已启动${RESET}"; }
do_stop()    { systemctl stop fan-nginx.service; echo -e "${GREEN}已停止${RESET}"; }
do_restart() { systemctl restart fan-nginx.service; echo -e "${GREEN}已重启${RESET}"; }

do_uninstall() {
    local u="${SCRIPTS_DIR}/uninstall.sh"
    [ -f "${u}" ] || u="${DATA_DIR}/scripts/uninstall.sh"
    [ -f "${u}" ] || { echo -e "${RED}未找到 uninstall.sh，请直接执行脚本目录中的 uninstall.sh${RESET}" >&2; return 1; }
    bash "${u}" "$@"
}

print_help() {
    cat <<'EOF'
fan-nginx — 命令行管理工具 (Fan-Nginx)

用法: fan-nginx <命令> [参数]

命令:
  status                  显示运行方式/systemd状态/PID/端口/访问地址/运行时长/内存/路径
  credentials             重置并打印全部管理员账号和密码(关闭两步验证)
  start                   启动 systemd 服务
  stop                    停止 systemd 服务
  restart                 重启 systemd 服务
  uninstall [-y] [--purge|--keep-data]   卸载(默认保留数据目录)
  version                 显示版本号
  help                    显示帮助

示例:
  fan-nginx status
  fan-nginx credentials
  fan-nginx uninstall -y --purge
EOF
}

CMD="${1:-help}"
shift 2>/dev/null || true

case "${CMD}" in
    status) print_status ;;
    credentials) do_credentials ;;
    start) do_start ;;
    stop) do_stop ;;
    restart) do_restart ;;
    uninstall) do_uninstall "$@" ;;
    version) version ;;
    help|-h|--help) print_help ;;
    *) echo -e "${RED}未知命令: ${CMD}${RESET}" >&2; print_help >&2; exit 1 ;;
esac
