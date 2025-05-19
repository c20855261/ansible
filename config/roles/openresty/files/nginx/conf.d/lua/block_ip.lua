local redis = require "resty.redis"
local telegram = require "telegram"
 
-- 設定參數
local ban_time = 3600
local max_requests = 200  -- 測試用，低門檻
local time_window = 60
local whitelist_file = "/opt/openresty/nginx/conf/conf.d/lua/whitelist.txt"
local REDIS_HOST = "127.0.0.1"
local REDIS_PORT = 6379
 
-- 獲取客戶端 IP
local client_ip = ngx.var.remote_addr
local count_key = "count:" .. client_ip
local ban_key = "ban:" .. client_ip
 
-- 檢查白名單

local function is_whitelisted(ip)
    local file = io.open(whitelist_file, "r")
    if not file then
        ngx.log(ngx.ERR, "無法打開白名單檔案: ", whitelist_file)
        return false
    end
    local content = file:read("*a")
    file:close()
    return content:find("%f[%a%d]" .. ip .. "%f[^%a%d]") ~= nil
end
 
-- 若為白名單 IP，則略過檢查並清除 Redis 中的計數紀錄
if is_whitelisted(client_ip) then
    ngx.log(ngx.NOTICE, "IP 在白名單: ", client_ip)
    local red = redis:new()
    red:set_timeout(1000)
    local ok, err = red:connect(REDIS_HOST, REDIS_PORT)
    if ok then
        red:del("count:" .. client_ip)
        red:close()
    else
        ngx.log(ngx.ERR, "Redis 連線失敗（白名單清理）: ", err)
    end
    return
end
 
-- 連接到 Redis（非白名單 IP 才會執行到這裡）
local red = redis:new()
red:set_timeout(1000)
local ok, err = red:connect(REDIS_HOST, REDIS_PORT)
if not ok then
    ngx.log(ngx.ERR, "Redis 連線失敗: ", err)
    return
end
 
-- 檢查是否已被封鎖
if red:get(ban_key) ~= ngx.null then
    ngx.log(ngx.NOTICE, "IP 已封鎖: ", client_ip)
    red:close()
    ngx.exit(444)
end
 
-- 紀錄請求次數
local request_count = red:get(count_key)
request_count = request_count == ngx.null and 0 or tonumber(request_count)
local ttl = red:ttl(count_key)
if ttl ~= ngx.null and ttl <= 5 then
    ngx.log(ngx.NOTICE, "IP: ", client_ip, ", 分鐘連線總數: ", request_count + 1, ", 即將重置")
end
ngx.log(ngx.NOTICE, "IP: ", client_ip, ", 當前連線數: ", request_count + 1, ", 剩餘TTL: ", ttl ~= ngx.null and ttl or time_window)
 
-- 固定時間
local is_new = request_count == 0
red:incr(count_key)
if is_new then
    local ok, err = red:expire(count_key, time_window)
    if not ok then
        ngx.log(ngx.ERR, "首次設置計數過期失敗: ", err)
    end
end

-- 增加請求次數並設置過期時間 (滑動更新時間)
-- red:incr(count_key)
-- local ok, err = red:expire(count_key, time_window)
-- if not ok then
--     ngx.log(ngx.ERR, "設置計數過期失敗: ", err, ", 重試")
--     local retry_ok, retry_err = red:expire(count_key, time_window)
--     if not retry_ok then
--         ngx.log(ngx.ERR, "重試設置計數過期失敗: ", retry_err)
--     end
-- end
 
-- 超過次數限制則發送通知
if request_count >= max_requests then
    ngx.log(ngx.NOTICE, "IP: ", client_ip, ", 超過限制，發送通知")
    local vhost = ngx.var.host or ngx.var.server_name or "unknown"
    local hostname = io.popen("hostname"):read("*l") or "unknown"          
    local proxy_ip = io.popen("curl -s ifconfig.me"):read("*l") or "unknown"

    local message =
        "Time：" .. os.date("%Y-%m-%d %H:%M:%S") ..
        "\nHost：" .. hostname ..
        "\nVhost：" .. vhost ..
        "\nPorxy_IP：" .. proxy_ip ..
        "\nBlocked_IP：" .. client_ip ..
        "\nStatus：" .. time_window .. " 秒內連線超過 " .. max_requests .. " 次"
 
    ngx.log(ngx.NOTICE, "[DEBUG] Telegram message:\n", message)
    telegram.send_once(client_ip, message, ban_time)

    -- red:setex(ban_key, ban_time, "1")  -- 註解：測試時不封鎖
    local del_ok, del_err = red:del(count_key)  -- 註解：測試時不清除計數
    if not del_ok then
        ngx.log(ngx.ERR, "清除計數失敗: ", del_err)
    else
        ngx.log(ngx.NOTICE, "計數已清除: ", count_key)
    end
    -- red:close()
    -- ngx.exit(444)
end
 
red:close()

