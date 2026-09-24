首个测试版

## jar 安装
```bash
bash -c "$(curl -sSL https://raw.githubusercontent.com/meimolihan/fan-nginx/main/scripts/install.sh)" -p 8080 -d /var/lib/fan-nginx
```

```bash
docker pull mobufan/fan-nginx:latest
```
```bash
docker pull mobufan/fan-nginx:v0.0.1
```

```bash
docker pull ghcr.io/meimolihan/fan-nginx:latest
```
```bash
docker pull ghcr.io/meimolihan/fan-nginx:v0.0.1
```

## 二进制卸载
```bash
bash -c "$(curl -sSL https://raw.githubusercontent.com/meimolihan/fan-nginx/main/scripts/uninstall.sh)" -y --purge
```

## CLI 命令
```bash
fan-nginx status
fan-nginx credentials
fan-nginx start | stop | restart
```
