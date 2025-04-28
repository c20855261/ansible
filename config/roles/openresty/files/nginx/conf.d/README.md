# conf.d

此為NGINX設定檔片段的 drop-in 目錄。

## 如何使用

1. 將您的Nginx 設定放入本文件所在目錄內

1. 於 nginx.conf 中加入 `include conf.d/_drop_in_file_.conf` 語句引入其內容

        因為引入的內容會展開至執行 include 所在位置的 Nginx 情境(context)的關係，通常無法使用萬用字元一次引入多個檔案

1. 重新啟動Nginx服務

        /opt/nginx/sbin/nginx -s reload
