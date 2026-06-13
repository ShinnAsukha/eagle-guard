proxy_http_version      1.1;
proxy_set_header        Host                $host;
proxy_set_header        X-Real-IP           $remote_addr;
proxy_set_header        X-Forwarded-For     $proxy_add_x_forwarded_for;
proxy_set_header        X-Forwarded-Proto   $scheme;
proxy_set_header        X-Eagle-WAF         "v7.4";
proxy_set_header        Connection          "";
proxy_connect_timeout   5s;
proxy_send_timeout      30s;
proxy_read_timeout      60s;
proxy_buffering         on;
proxy_buffer_size       8k;
proxy_buffers           16 8k;
proxy_busy_buffers_size 16k;
proxy_next_upstream     error timeout http_502 http_503;
proxy_next_upstream_tries 2;
# Cache-busting — WAF her isteği yeniden değerlendir
proxy_no_cache          $eg_bad_bot;
proxy_cache_bypass      $eg_bad_bot;
