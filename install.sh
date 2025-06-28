#!/bin/bash

#
# Nezha 多探针实例修复脚本
#
# 功能:
# 1. 查找所有 nezha-agent 的随机配置文件。
# 2. 批量修改这些配置文件中的服务器地址。
# 3. 重启所有 nezha-agent 进程以应用新配置。
#

# --- 新的服务器地址 ---
NEW_SERVER_ADDRESS="8.219.183.120:8008"

# --- 可视化用的颜色定义 ---
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
cyan='\033[0;36m'

# --- 标准化输出函数 ---
err() {
    printf "${red}%s${plain}\n" "$*" >&2
}

success() {
    printf "${green}%s${plain}\n" "$*"
}

info() {
    printf "${yellow}%s${plain}\n" "$*"
}

# --- 脚本主体 ---

# 1. 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    err "错误：此脚本需要以 root 权限运行。"
    info "请尝试使用 'sudo ./fix_multiple_agents.sh'"
    exit 1
fi

AGENT_DIR="/opt/nezha/agent"
info "目标Agent目录: ${AGENT_DIR}"

if [ ! -d "$AGENT_DIR" ]; then
    err "错误: 目录 ${AGENT_DIR} 不存在！"
    info "请确认此服务器已安装 Nezha 探针。"
    exit 1
fi

# 2. 查找并批量修改所有配置文件
info "正在查找所有 config-*.yml 格式的配置文件..."

# 使用 find 命令查找文件，并通过 while read 循环处理
# -print0 和 read -d $'\0' 组合可以安全处理包含特殊字符的文件名
config_files_found=0
find "${AGENT_DIR}" -name "config-*.yml" -print0 | while IFS= read -r -d $'\0' file; do
    config_files_found=$((config_files_found + 1))
    printf "  -> 正在修改文件: ${cyan}%s${plain}\n" "$file"
    # 使用 sed 命令进行替换
    sed -i "s|^server:.*|server: ${NEW_SERVER_ADDRESS}|" "$file"
    if [ $? -ne 0 ]; then
        err "    修改失败！请检查文件权限。"
    fi
done

if [ "$config_files_found" -eq 0 ]; then
    warn "警告：未找到任何 'config-*.yml' 格式的随机配置文件。"
    info "脚本将继续尝试修改主配置文件 'config.yml'。"
fi

# 3. 额外修改主配置文件 (以防万一)
MAIN_CONFIG_FILE="${AGENT_DIR}/config.yml"
if [ -f "$MAIN_CONFIG_FILE" ]; then
    info "正在修改主配置文件: ${MAIN_CONFIG_FILE}..."
    sed -i "s|^server:.*|server: ${NEW_SERVER_ADDRESS}|" "$MAIN_CONFIG_FILE"
    success "  -> 主配置文件修改成功。"
else
    warn "警告：主配置文件 ${MAIN_CONFIG_FILE} 未找到。"
fi

success "✅ 所有找到的配置文件均已更新。"
echo

# 4. 重启所有探针进程
info "正在重启所有 nezha-agent 进程..."

# 第一步：强制杀死所有现存的 agent 进程
info "1. 正在强制停止所有旧的 'nezha-agent' 进程..."
pkill -9 nezha-agent
# 等待1秒确保进程已终止
sleep 1
# 再次检查
if pgrep -f nezha-agent > /dev/null; then
    warn "警告：部分进程未能被 pkill 终止，可能需要手动处理。"
else
    success "  -> 所有旧进程已停止。"
fi

# 第二步：重启系统服务
# 这是基于一个假设：这些失控的进程是由某个主服务启动的。
# 即使不是，重启主服务也是一个恢复到已知状态的好方法。
SERVICE_FILE="/etc/systemd/system/nezha-agent.service"
if [ -f "$SERVICE_FILE" ]; then
    info "2. 正在通过 systemd 重启主服务..."
    systemctl restart nezha-agent.service
    if [ $? -ne 0 ]; then
        err "通过 systemd 重启服务失败！"
        info "请尝试手动重启: sudo systemctl restart nezha-agent.service"
        exit 1
    fi
    sleep 2 # 等待服务启动
    # 检查服务状态
    if systemctl is-active --quiet nezha-agent.service; then
        success "  -> 主服务已成功重启并正在运行。"
    else
        err "  -> 主服务重启后状态异常！请使用 'systemctl status nezha-agent.service' 查看详情。"
    fi
else
    warn "警告：未找到 systemd 服务文件 ${SERVICE_FILE}。"
    info "这意味着探针可能是以其他方式启动的，您可能需要手动启动它。"
fi

echo
success "🎉 修复脚本执行完毕！"
info "请稍等片刻，然后检查主面板上的探针状态。"
echo 
