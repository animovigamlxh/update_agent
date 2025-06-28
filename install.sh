#!/bin/bash

#
# Nezha Agent 一键修改服务器地址并重启脚本
#
# 使用方法:
# 1. 上传此脚本到需要修改的 VPS 上。
# 2. chmod +x update_agent_server.sh
# 3. sudo ./update_agent_server.sh
#

# --- 新的服务器地址 (请根据需要修改) ---
NEW_SERVER_ADDRESS="8.219.183.120:8008"

# --- 可视化用的颜色定义 ---
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

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
    info "请尝试使用 'sudo ./update_agent_server.sh'"
    exit 1
fi

# 2. 定义配置文件路径
CONFIG_FILE="/opt/nezha/agent/config.yml"
info "目标配置文件: ${CONFIG_FILE}"

# 3. 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    err "错误: 配置文件 ${CONFIG_FILE} 不存在！"
    info "请确认此服务器已正确安装 Nezha 探针。"
    exit 1
fi
success "✅ 配置文件定位成功。"

# 4. 修改配置文件
info "正在将服务器地址修改为: ${NEW_SERVER_ADDRESS}..."

# 使用 sed 命令进行替换。-i 表示直接修改文件。
# s|^server:.*|...| 中的 | 是分隔符，避免与地址中的 : 冲突。^server: 匹配以 "server:" 开头的行。
sed -i "s|^server:.*|server: ${NEW_SERVER_ADDRESS}|" "${CONFIG_FILE}"

if [ $? -ne 0 ]; then
    err "修改配置文件失败！请检查文件权限。"
    exit 1
fi
success "✅ 配置文件修改成功。"

# 5. 重启探针服务
info "正在重启 nezha-agent 服务..."
systemctl restart nezha-agent

if [ $? -ne 0 ]; then
    err "重启服务失败！"
    info "请尝试手动重启: sudo systemctl restart nezha-agent"
    exit 1
fi
success "✅ 服务重启成功。"
sleep 2

# 6. 检查服务状态
info "正在检查服务状态..."
if systemctl is-active --quiet nezha-agent; then
    success "🎉 Nezha 探针已更新并成功运行！"
    info "您可以运行 'sudo systemctl status nezha-agent' 查看详细日志。"
else
    err "服务状态异常！请使用 'sudo systemctl status nezha-agent' 查看错误详情。"
fi

echo
