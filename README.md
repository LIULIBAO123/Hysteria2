# Hysteria2 一键部署脚本

基于 [Hysteria2](https://github.com/apernet/hysteria) 官方版本的自动化部署脚本。

## 功能特性

- ✅ 一键安装 Hysteria2 官方版本
- ✅ ACME 自动申请 Let's Encrypt 证书
- ✅ 端口跳跃（Port Hopping）防断连
- ✅ 自动生成 v2rayN 兼容的分享链接
- ✅ 伪装为正常网站流量
- ✅ iptables 规则持久化

## 环境要求

- Ubuntu 20.04+ / Debian 11+ / CentOS 7+
- Root 权限
- 一个已解析到服务器 IP 的域名

## 使用方法

```bash
# 下载脚本
wget https://raw.githubusercontent.com/LIULIBAO123/Hysteria2/main/hysteria2-deploy.sh

# 赋予执行权限
chmod +x hysteria2-deploy.sh

# 运行（需要 root）
sudo bash hysteria2-deploy.sh
```

## 交互式配置

脚本运行后会依次询问：

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| 域名 | 已解析到服务器的域名 | 必填 |
| 邮箱 | ACME 证书申请邮箱 | 必填 |
| 密码 | 认证密码 | 自动生成 |
| 主端口 | Hysteria2 监听端口 | 443 |
| 端口跳跃起始 | 跳跃范围起始端口 | 20000 |
| 端口跳跃结束 | 跳跃范围结束端口 | 40000 |
| 下行带宽 | 服务器下行带宽(mbps) | 200 |
| 上行带宽 | 服务器上行带宽(mbps) | 100 |

## 客户端支持

部署完成后自动生成 v2rayN 格式的分享链接，支持以下客户端导入：

| 平台 | 推荐客户端 |
|------|-----------|
| Windows | v2rayN / NekoBox |
| macOS | NekoRay |
| iOS | Shadowrocket / Stash |
| Android | NekoBox / Clash Meta |

## 管理命令

```bash
systemctl start hysteria-server    # 启动
systemctl stop hysteria-server     # 停止
systemctl restart hysteria-server  # 重启
systemctl status hysteria-server   # 查看状态
journalctl -u hysteria-server -f   # 查看日志
```

## 部署后查看连接信息

```bash
cat /etc/hysteria/client-links.txt
```

## License

MIT
