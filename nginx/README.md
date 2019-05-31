> 使用本脚本可以自动批量完成中间节点环境的部署工作，包括：Nginx编译安装、添加程序管理脚本、设置开机启动、反向代理配置、证书分发、添加iptables规则等。脚本支持自定义nginx安装版本、设置编译模块、配置监听端口等。

# 1. Nginx Role规则说明

本脚本用于中间节点（Nginx反向代理）环境的自动化配置，主要内容包括：

- 安装基础依赖环境；
- 创建nginx启动用户（支持自定义用户）；
- 下载nginx安装文件（可自定义nginx版本）；
- 解压安装文件；
- 执行编译安装（可自定义编译参数和模块）；
- 添加管理脚本，用于nginx服务的启动和关闭；
- 设置开机启动;
- 分发https证书文件；
- 反向代理配置；
- 添加iptables规则，允许访问nginx代理服务。

# 2. Nginx Role规则基本说明

## 2.1 目录结构说明

Nginx Role目录结构介绍：

```
nginx                             # Nginx Role脚本根目录
├── defaults                      # 脚本默认变量目录
│   └── main.yml                  # 脚本默认变量文件
├── files                         # 文件目录
│   ├── https_cert                # 文件目录，用于存放https证书文件
│   └── nginx_start_scripts       # nginx启动脚本
├── handlers                      # 任务处理器
│   └── main.yml                  # 定义了 nginx reload和iptables restarted两个处理器任务
├── tasks                         # 任务目录
│   └── main.yml                  # ansible任务文件，定义了需要执行的自动化任务
├── templates                     # 模板目录
│   ├── nginx_config_file.j2      # nginx配置模板，使用了jinja2模版语言进行预定义，可通过变量传递配自定义置内容
│   └── nginx_install.j2          # nginx编译安装执行脚本
├── tests                         # 脚本使用的测试用例，脚本执行案例
│   ├── inventory                 # 脚本执行使用的主机清单
│   └── test.yml                  # 脚本执行调用的playbook剧本
└── vars                          # 脚本变量目录
    └── main.yml                  # 脚本变量文件
```

## 2.2 脚本变量说明

默认变量（nginx/defaults/main.yml）

变量名 | 默认值 | 说明
---|---|---
nginx_install | true | nginx编译安装
nginx_start_scripts | true | 分发nginx启动脚本
nginx_start_service | true | 启动nginx服务
nginx_start_on_boot | true | 设置开机启动
nginx_copy_https_cert | false | 分发https证书文件
nginx_revproxy_config | false | 设置反向代理配置
add_iptables_for_nginx | false | 添加iptables防火墙规则

通过默认变量可以控制脚本执行的内容，在使用本脚本前最好是执行下common脚本，先进行系统的初始优化工作。

脚本变量（nginx/vars/main.yml）

```
---
nginx_user: nginx                             # nginx启动用户
nginx_group: nginx                            # nginx组
nginx_version: 1.15.8                         # 要安装的nginx版本
download_url: http://nginx.org/download       # nginx文件下载地址
download_dir: /usr/local/src                  # nginx文件下载存放目录
install_dir: /usr/local/nginx                 # nginx安装目录

model_config:                                 # nginx编译安装参数
  - "--user={{ nginx_user }}"
  - "--group={{ nginx_group }}"
  - "--prefix={{ install_dir }}"
  - "--with-http_realip_module"
  - "--with-http_sub_module"
  - "--with-http_gzip_static_module"
  - "--with-http_stub_status_module"
  - "--with-http_ssl_module"
  - "--with-pcre"
```
可以通过修改nginx_version来修改需要安装的版本，但需要确认下载地址download_url中存在对应版本，并可以下载。

## 2.3 nginx反向代理配置模版说明

nginx反向代理配置模版（nginx/templates/nginx_config_file.j2）

```
user {{ nginx_user }};
worker_processes  {{ ansible_processor_vcpus }};
events {
    worker_connections  102400;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    log_format main '$remote_addr $http_X_Forwarded_For [$time_local] '  
                     '$upstream_addr $upstream_response_time '  
                     '$http_host $request '  
                     '"$status" $body_bytes_sent "$http_referer" '  
                     '"$http_accept_language" "$http_user_agent" '; 
    sendfile        on;
    tcp_nopush      on; 
    tcp_nodelay     on;
    server_tokens  off;
    keepalive_timeout  65;

    
    {% for item in nginx_revproxy_sites %}    # 对nginx_revproxy_sites配置变量进行循环
    {% if item.host == ansible_host %}        # 判断host是否等于当前执行任务的主机地址，如果相等继续执行后面操作
    upstream {{ item.desc }}_backend {        # 使用desc变量内容加上_backend作为upstream名称
        {% for upstream in item.upstreams %}  # 遍历upstreams
           server {{ upstream.address }}:{{ upstream.port }}; # 将遍历结果作为upstream模块集群转发地址（反向代理的回源请求地址，upstream支持多节点的集群负载）
        {% endfor %}
    } 
    server {
        listen       {{ item.listen_port | default(80) }};    # 配置http监听端口，如果没有定义listen_port默认使用80端口
        server_name  {{ item.domains | join(" ") }};          配置访问域名，支持多域名设置
        access_log  logs/access.log  main;

      {% if item.ssl_status %}   # 判断ssl_status状态，如果状态为true，则将http请求跳转到https（跳转会加上listen_ssl_port和请求链接）
        return   301  https://$server_name:{{ item.listen_ssl_port | default(443)   }}$request_uri;
      {% else %}  # 如果ssl_status状态为false，则使用http代理将请求转发到上面定义的upstream集群
        location / {

                proxy_pass http://{{ item.desc }}_backend;
            
            }
      {% endif %}
        }
    {% if item.ssl_status %}    # ssl_status状态为true是进行https反向代理配置和域名证书配置
    server {
        listen       {{ item.listen_ssl_port | default(443) }} ssl;
        server_name  {{ item.domains | join(" ") }};
        ssl_certificate  {{ item.ssl_crt }};
        ssl_certificate_key {{ item.ssl_key }};
                ssl_session_timeout 50m;
                ssl_protocols TLSv1.2;
                ssl_ciphers AESGCM:ALL:!DH:!EXPORT:!RC4:+HIGH:!MEDIUM:!LOW:!aNULL:!eNULL;
                ssl_prefer_server_ciphers on;
        access_log  logs/access.log  main;
        location / {
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_request_buffering off;
                proxy_ignore_client_abort on;
                proxy_pass   https://{{ item.desc }}_backend;
        }
    }
    {% endif %}
    {% endif %} 
 {% endfor %}
}
```

**反向代理模版配置说明：**

1. 配置模版使用了Jinja2模版语言使用自定义变量来动态进行配置文件的渲染；
2. user {{ nginx_user }}：使用自定义的用户作为nginx启动用户；
3. worker_processes  {{ ansible_processor_vcpus }}：获取cup核数，设置worker_processes；
4. 其他说明详见模版中注释内容。


# 3 Nginx role脚本使用说明

在脚本中已经创建了一个简单的使用案例（nginx/tests/）可以作为参考，同时前面已经介绍了默认变量和脚本变量，在脚本使用过程中可以去自定义这些变量内容。

> 使用脚本前先将脚本目录（nginx）拷贝到/etc/ansible/roles目录下

## 3.1 基本功能使用

通过以下事例可以完成nginx的编译安装和开机启动配置：

**1) 新建一个主机清单文件（nginx/tests/inventory）:**

```
[proxy_server]
192.168.0.100
192.168.0.101
```
这里默认已经使用common脚本进行了系统的初始化配置，可以通过密钥来登陆主机清单中的主机。如果清单中主机没有配置密钥登陆，在定义清单时需要制定远程登陆用户和密码：

```
[proxy_server]
192.168.0.100 ansible_ssh_user=root ansible_ssh_pass=CPBal1Tid
192.168.0.101 ansible_ssh_user=root ansible_ssh_pass=KJadfiola
```

2) **新建执行脚本用的playbook剧本（nginx/tests/nginx_site.yml）**


```
---
- hosts: proxy_server
  remote_user: root
  roles:
    - nginx
```
**3) 执行脚本**

```
cd /etc/ansible/roles/nginx/tests/
ansible-playbook nginx_site.yml -i inventory
```
脚本成功执行完成后，ansible会在inventory清单中的远程主机编译安装nginx，并添加到开机启动。

**4）执行结果验证**

```
ansible proxy_server -m shell -a "ps -ef |grep nginx" -i inventory 
192.168.0.100 | CHANGED | rc=0 >>
root      2228     1  0 13:24 ?        00:00:00 nginx: master process /usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
nginx     2229  2228  0 13:24 ?        00:00:00 nginx: worker process
root      5781  5780  0 13:36 pts/0    00:00:00 /bin/sh -c ps -ef |grep nginx
root      5783  5781  0 13:36 pts/0    00:00:00 grep nginx

....后面内容省略....
```
可以看到远程主机已经成功安装了nginx并启动了nginx服务，当然你也可以确认下是否分发了nginx启动脚本和是否设置了开机启动。

## 3.2 反向代理配置和证书分发

如果想要在安装nginx的同时配置反向代理，和分发证书文件，按照下面步骤进行操作：

**1）上传证书文件**

将https证书文件上传到nginx/files/https_cert目录。

**2）修改nginx/tests/nginx_site.yml文件**

```
---
- hosts: proxy_server
  remote_user: root
  vars:
    nginx_copy_https_cert: true
    nginx_revproxy_config: true
    add_iptables_for_nginx: true
    nginx_revproxy_sites:           # nginx 反向代理配置内容，对照《2.3 nginx反向代理配置模版说明》更便于理解                             
      - host: 192.168.0.100         # 反向代理配置对应的主机
        desc: t_server              # 反向代理集群备注，nginx配置模版中引用它作为upstream名称
        domains:                    # 域名，用于定义server_name，支持多个域名配置
          - example.com
          - www.example.com
        upstreams:                  # nginx反向代理集群配置内容，可以添加多个节点，默认采用轮训方式进行请求转发
          - { address: 192.168.10.11, port: 80}
          - { address: 192.168.10.12, port: 8080}
        listen_port: 80             # http监听端口，如果不设置，默认使用80端口
        listen_ssl_port: 443        # https监听端口，如果不设置，默认使用https端口
        ssl_status: true            # 设置为true启用https配置
        ssl_crt: /etc/ssl/test.com.crt  # 证书文件
        ssl_key:  /etc/ssl/test.com.key  # 证书文件
      - host: 192.168.0.101
        desc: z_server
        domains:
          - example01.com
          - wwww.example01.com
        upstreams:
          - { address: 192.168.0.21, port: 80}
          - { address: 192.168.0.22, port: 80}
        ssl_status: false
  roles:
    - nginx
```

执行nginx role的playbook剧本说明：

- nginx_copy_https_cert：默认变量，用来控制证书文件分发，设置为true，执行证书分发操作；
- nginx_revproxy_config：默认变量，用来启用反向代理配置，设置为ture，进行模版变量替换和分发；
- add_iptables_for_nginx：默认变量，用来添加iptables规则，需要保证系统已安装iptables-services服务(common基础优化脚本中已经定义安装过程)；
- nginx_revproxy_sites：nginx反向代理的配置内容，详细说明见上面的备注。


<br>

>==**配置注意事项：**==
> - 如果启用了nginx_copy_https_cert、nginx_revproxy_config、add_iptables_for_nginx这三项配置，必须定义nginx_revproxy_sites;
> - nginx_revproxy_sites中必定义字段有：host、desc、domain、upstreams、ssl_status;
> - host: 用来确定反向代理配置对应的主机（该主机必须存在于inventory主机清单中）；
> - ssl_status：当ssl_status状态为true时，需要定义证书文件ssl_crt和ssl_key，其中证书名称必须和上传到nginx/files/https_cert目录中的名称对应；
> - listen_port（listen_ssl_port）: http(https)监听端口，这两个选项不是必须定义，如果在playbook中没有定义，脚本默认会采用80（443）端口，这两个监听端口不能用同一个端口。
> - 配置文件使用的是yaml格式，在定义文件内容时注意缩紧。
> 

