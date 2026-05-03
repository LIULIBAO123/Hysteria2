#!/bin/bash

# ============================================
# Hysteria2 一键部署脚本
# 功能：自动安装、ACME证书、端口跳跃、生成订阅链接
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   Hysteria2 一键部署脚本${NC}"
echo -e "${CYAN}   支持：ACME证书 + 端口跳跃 + v2rayN订阅${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# ============ 用户输入 ============

read -p "请输入你的域名（已解析到本机IP）: " DOMAIN
read -p "请输入邮箱（用于ACME证书申请）: " EMAIL
read -p "请输入认证密码（留空自动生成）: " PASSWORD
read -p "请输入主监听端口 [默认443]: " PORT
PORT=${PORT:-443}
read -p "请输入端口跳跃范围起始 [默认20000]: " HOP_START
HOP_START=${HOP_START:-20000}
read -p "请输入端口跳跃范围结束 [默认40000]: " HOP_END
HOP_END=${HOP_END:-40000}
read -p "请输入下行带宽(mbps) [默认900]: " BW_DOWN
BW_DOWN=${BW_DOWN:-900}
read -p "请输入上行带宽(mbps) [默认900]: " BW_UP
BW_UP=${BW_UP:-900}

# 自动生成密码
if [ -z "$PASSWORD" ]; then
    PASSWORD=$(openssl rand -base64 16)
    echo -e "${GREEN}自动生成密码: ${PASSWORD}${NC}"
fi

# 获取服务器公网IP
SERVER_IP=$(curl -s4 ifconfig.me || curl -s4 ip.sb)
echo -e "${GREEN}检测到服务器IP: ${SERVER_IP}${NC}"

# ============ 安装 Hysteria2 ============

echo ""
echo -e "${YELLOW}[1/5] 安装 Hysteria2...${NC}"

if command -v hysteria &> /dev/null; then
    echo -e "${GREEN}Hysteria2 已安装，跳过${NC}"
else
    bash <(curl -fsSL https://get.hy2.sh/)
fi

# ============ 生成配置文件 ============

echo -e "${YELLOW}[2/5] 生成服务端配置...${NC}"

mkdir -p /etc/hysteria

cat > /etc/hysteria/config.yaml << EOF
listen: :${PORT}

acme:
  domains:
    - ${DOMAIN}
  email: ${EMAIL}

auth:
  type: password
  password: ${PASSWORD}

masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true

bandwidth:
  up: ${BW_UP} mbps
  down: ${BW_DOWN} mbps

quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520

outbounds:
  - name: default
    type: direct
EOF

echo -e "${GREEN}配置文件已写入 /etc/hysteria/config.yaml${NC}"

# ============ 配置端口跳跃 ============

echo -e "${YELLOW}[3/5] 配置端口跳跃 (${HOP_START}-${HOP_END} -> ${PORT})...${NC}"

# 清除旧规则（如果存在）
iptables -t nat -D PREROUTING -p udp --dport ${HOP_START}:${HOP_END} -j REDIRECT --to-ports ${PORT} 2>/dev/null || true
ip6tables -t nat -D PREROUTING -p udp --dport ${HOP_START}:${HOP_END} -j REDIRECT --to-ports ${PORT} 2>/dev/null || true

# 添加新规则
iptables -t nat -A PREROUTING -p udp --dport ${HOP_START}:${HOP_END} -j REDIRECT --to-ports ${PORT}
ip6tables -t nat -A PREROUTING -p udp --dport ${HOP_START}:${HOP_END} -j REDIRECT --to-ports ${PORT}

# 放行防火墙
if command -v ufw &> /dev/null; then
    ufw allow ${PORT}/udp
    ufw allow ${HOP_START}:${HOP_END}/udp
    ufw reload
fi

# 持久化 iptables 规则
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save
else
    apt-get install -y iptables-persistent 2>/dev/null && netfilter-persistent save || true
fi

echo -e "${GREEN}端口跳跃配置完成${NC}"

# ============ 启动服务 ============

echo -e "${YELLOW}[4/5] 启动 Hysteria2 服务...${NC}"

systemctl enable hysteria-server
systemctl restart hysteria-server

sleep 2

if systemctl is-active --quiet hysteria-server; then
    echo -e "${GREEN}Hysteria2 服务启动成功！${NC}"
else
    echo -e "${RED}服务启动失败，查看日志：journalctl -u hysteria-server -f${NC}"
    exit 1
fi

# ============ 生成订阅链接 ============

echo -e "${YELLOW}[5/5] 生成客户端订阅链接...${NC}"

# v2rayN 格式的 Hysteria2 分享链接
# 官方格式: hysteria2://auth@hostname[:port]/?[key=value]&[key=value]...
# 注意：密码需要URL编码，端口后必须有斜杠，不包含带宽参数
ENCODED_PASSWORD=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${PASSWORD}', safe=''))" 2>/dev/null || echo "${PASSWORD}")

SUBSCRIBE_LINK="hysteria2://${ENCODED_PASSWORD}@${DOMAIN}:${PORT}/?sni=${DOMAIN}&insecure=0#Hysteria2-${DOMAIN}"

# 带端口跳跃的链接（mport参数）
SUBSCRIBE_LINK_HOP="hysteria2://${ENCODED_PASSWORD}@${DOMAIN}:${PORT}/?sni=${DOMAIN}&insecure=0&mport=${HOP_START}-${HOP_END}#Hysteria2-PortHop-${DOMAIN}"

# 生成 Base64 订阅内容
SUBSCRIBE_CONTENT=$(echo -e "${SUBSCRIBE_LINK}\n${SUBSCRIBE_LINK_HOP}" | base64 -w 0)

# 保存订阅文件
mkdir -p /etc/hysteria/subscribe
echo "${SUBSCRIBE_CONTENT}" > /etc/hysteria/subscribe/index.html

# 保存明文链接
cat > /etc/hysteria/client-links.txt << EOF
============================================
  Hysteria2 客户端连接信息
============================================

服务器地址: ${DOMAIN}
端口: ${PORT}
端口跳跃范围: ${HOP_START}-${HOP_END}
密码: ${PASSWORD}
SNI: ${DOMAIN}
TLS: ACME (可信证书)

============================================
  v2rayN 导入链接（标准）
============================================
${SUBSCRIBE_LINK}

============================================
  v2rayN 导入链接（端口跳跃）
============================================
${SUBSCRIBE_LINK_HOP}

============================================
  Base64 订阅内容（可托管为订阅地址）
============================================
${SUBSCRIBE_CONTENT}

============================================
  v2rayN 使用方法
============================================
1. 复制上方链接
2. v2rayN → 服务器 → 从剪贴板导入
3. 或：订阅 → 订阅设置 → 添加订阅地址

============================================
  客户端配置文件 (config.yaml)
============================================
server: ${DOMAIN}:${HOP_START}-${HOP_END}
auth: ${PASSWORD}

bandwidth:
  up: 900 mbps
  down: 900 mbps

tls:
  sni: ${DOMAIN}
  insecure: false

socks5:
  listen: 127.0.0.1:1080

http:
  listen: 127.0.0.1:8080
EOF

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   部署完成！${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "${GREEN}服务器地址: ${DOMAIN}${NC}"
echo -e "${GREEN}端口: ${PORT}${NC}"
echo -e "${GREEN}端口跳跃: ${HOP_START}-${HOP_END}${NC}"
echo -e "${GREEN}密码: ${PASSWORD}${NC}"
echo ""
echo -e "${YELLOW}v2rayN 导入链接（标准）:${NC}"
echo -e "${CYAN}${SUBSCRIBE_LINK}${NC}"
echo ""
echo -e "${YELLOW}v2rayN 导入链接（端口跳跃）:${NC}"
echo -e "${CYAN}${SUBSCRIBE_LINK_HOP}${NC}"
echo ""
echo -e "${GREEN}完整信息已保存到: /etc/hysteria/client-links.txt${NC}"
echo -e "${GREEN}查看: cat /etc/hysteria/client-links.txt${NC}"
echo ""
echo -e "${YELLOW}管理命令:${NC}"
echo -e "  启动: systemctl start hysteria-server"
echo -e "  停止: systemctl stop hysteria-server"
echo -e "  重启: systemctl restart hysteria-server"
echo -e "  状态: systemctl status hysteria-server"
echo -e "  日志: journalctl -u hysteria-server -f"
echo ""
