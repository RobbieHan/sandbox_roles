> 本role规则可用于批量修改远程主机iptables input规则需要开发的端口，可批量关闭和启用iptables规则。

# 1. Iptables Role规则说明

iptables role脚本用于管理centons系统iptables防火墙（centos7需要卸载firewall防火墙，安装iptables-server）。

规则包含的内容：
- 关闭iptables防火墙，取消开机启动设置；
- 启用iptables防火墙，加入开机启动服务；
- 设置iptables input规则，开放指定的端口服务。

iptables role脚本，配合系统初始优化脚本common role使用效果更佳。

# 2. Iptables Role规则使用

## 2.1 拷贝文件

把roles目录中的iptables（iptables配置role脚本）拷贝到ansible服务器/etc/ansible/roles/目录下。

## 2.2 目录结构和默认变量说明

iptables目录结构：


```
iptables                  # iptables批量配置优化的role规则
├── defaults              # role默认变量目录
│   └── main.yml          # role默认变量文件，定义了初始变量
├── files                 # 文件目录
├── handlers              # 任务处理器目录
│   └── main.yml          # 创建了handlers：restart iptables
├── tasks                 # 任务目录
│   └── main.yml          # ansible任务
├── templates             # 模板目录
│   └── iptables_rules.j2 # iptables配置文件模版
├── tests                 # 脚本测试目录
│   ├── inventory         # 脚本测试用的主机清单文件
│   └── test.yml          # 脚本测试用的playbook文件
└── vars                  # 变量目录
    └── main.yml          # 变量文件
```

默认变量说明（iptables/defaults/main.yml）：

变量名 | 默认值 |说明
---|---|---
iptables_disable_iptables | false | 用来控制是否关闭iptables防火墙和取消开机启动设置
iptables_enable_iptables | true | 用来控制是否启用iptables防火墙并加入开机启动服务
iptables_modify_iptables | true | 用来控制是否设置iptables input规则，开放指定的端口服务


## 2.3 脚本使用案例

1）新建一个主机清单文件，案例中文件放置路径：iptables/tests/inventory：


```
[test_server]
192.168.0.100
192.168.0.101
```

> 如果清单中的主机没有配置密钥登陆，需要在设置主机清单的时候执行登陆用户名和登陆密码。

2) 新建一个执行任务用的playbook文件（iptables/tests/test.yml）:


```
---
- hosts: test_server
  remote_user: root
  vars:
    iptables_disable_iptables: true
    iptables_enable_iptables: false
    iptables_modify_iptables: false
  roles:
    - iptables
```

3) 执行上面的脚本，批量关闭iptables

```
cd /etc/ansible/roles/nginx/tests/
ansible-playbook test.yml inventory
```

4) 执行结果验证


```
ansible test_server -m shell -a "netstat -tnpl" -i inventory 

```

注意： 如果单次执行批量任务的主机有很多，就不要这样去查看执行结果了，可以配置ansible记录执行日志，关注下执行日志是否有报错信息，如果有错误信息再去根据错误提示去排查原因。

## 2.4 配置iptables input规则案例

通过脚本来批量配置iptables 规则，添加input规则允许通过的端口，只需要修改playbook执行文件内容（iptables/tests/test.yml）

```
---
- hosts: test_server
  remote_user: root
  vars:
    iptables_role_sites:                                     
      - host: 192.168.0.100
        allowed_ports:
          - {port: "22", type: "tcp"}
          - {port: "443", type: "tcp"}
      - host: 192.168.0.100
        allowed_ports:
          - {port: "22", type: "tcp"}
          - {port: "80", type: "tcp"}
  roles:
    - iptables
```

执行脚本，批量配置iptables input规则：

```
cd /etc/ansible/roles/nginx/tests/
ansible-playbook test.yml inventory
```

> 在批量配置iptables input规则时，必须定义iptables_role_sites内容。需要指定需要修改规则的hosts和开放的端口信息，其中hosts必须在inventory主机清单中。