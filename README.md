# ansible
docker-compose

```

容器運行ansible，本地端可使用ansible命令
#vim ~/.bashrc
export PATH="/opt/docker-compose/ansible/wrapper:$PATH"

```
-
增加lua-resty-http模組

```
如需使用block ip 功能 nginx.conf 需加入以下配置 (必須有redis)

resolver 100.100.2.138 ipv6=off;
lua_package_path "/opt/openresty/nginx/conf/conf.d/lua/?.lua;;";
access_by_lua_file /opt/openresty/nginx/conf/conf.d/lua/block_ip.lua;
```
