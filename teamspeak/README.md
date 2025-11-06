## 使用说明

1. **创建项目目录**：

```bash
mkdir teamspeak-server && cd teamspeak-server
```

2. **创建 compose.yaml 文件**

3. **创建 .env 文件设置密码**：

```bash
echo "TS3_ADMIN_PASSWORD=你的强密码" > .env
```

4. **启动服务**：

```bash
docker-compose up -d
```

5. **查看日志获取权限密钥**：

```bash
docker-compose logs teamspeak | grep "token="
```

## 端口说明

- **9987/udp**: 语音通信
- **10011**: 文件传输
- **10022**: 服务器查询
- **10080**: HTTP文件传输
- **10443**: 主要服务器端口
- **30033**: 文件传输
- **41144**: TSDNS服务
