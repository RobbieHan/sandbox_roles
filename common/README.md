> 使用ansible role进行系统批量初始化配置，提高系统部署效率，保证系统环境的一致性。

# 1. Role规则说明

common role用于centos7系统的初始优化，主要包含的优化内容有：

- 临时关闭selinux;
- 修改selinux配置文件，永久关闭selinux;
- 卸载centos7自带的防火墙firewalld;
- 安装一些基础工具包；
- 更新yum软件包；
- 安装epel扩展源；
- 安装iptables；
- 启用iptables并设置开机启动；
- 创建/root/.ssh目录，用于存放密钥；
- 拷贝密钥到远程主机，通过密钥文件可以免密登陆；
- 修改字符集；
- 安装Development Tools;
- 修改时区；
- 设置定时任务，自动同步时间；
- 修改系统内核参数；
- 修改文件描述符；
- 替换ssh配置文件，配置文件中启用了密钥认证和一些基本优化配置；
- 添加iptables规则允许访问新的ssh_port;
- 修改系统登陆提示信息；
- 设置主机名称，需要在hosts主机清单中定义主机名host_name。

# 2. Role规则的使用

## 2.1 拷贝文件



把roles目录中的common（系统基础优化的role规则）拷贝到ansible服务器/etc/ansible/roles/目录下。


## 2.2 目录结构和默认变量说明

common目录结构说明：

```
└── common                         # centos7系统基础优化的role规则
    ├── defaults                   # role默认变量目录
    │   └── main.yml               # role默认变量文件，定义了初始变量
    ├── files                      # 文件目录
    │   ├── common_id_rsa.pub      # 密钥文件，放到远程主机，用于免密登陆
    │   ├── common_sshd_config     # ssh配置文件，启用了密钥认证和ssh基本优化
    │   └── common_sysctl.conf     # 内核参数配置文件
    ├── handlers                   # 任务处理器目录
    │   └── main.yml               # 创建了handlers包括：重启sshd和iptables服务
    ├── tasks                      # 任务目录
    │   └── main.yml               # ansible任务
    ├── templates                  # 模版目录
    │   ├── common_motd            # 用于配置开机提醒，默认设置主机名+ ip
    │   └── common_sshd_config     # ssh配置文件模版
    └── vars
        └── main.yml               # 自定义变量，默认定义了ssh_port
```

默认变量说明（common/defaults/main.yml）：


变量名 | 默认值 |说明
---|---|---
centos7_setenforce | true | 临时关闭selinux
centos7_modify_selinux | true| 修改selinux配置文件，永久关闭selinux
centos7_firewalld_absent | true | 卸载centos7自带的防火墙firewalld
centos7_install_base_packages| true| 安装一些基础工具包
centos7_yum_update | true | 更新yum软件包
centos7_install_epel | true |安装epel扩展源
centos7_install_iptables| true |安装iptables
centos7_start_iptables|true | 启用iptables并设置开机启动
centos7_create_sshdir|false | 创建/root/.ssh目录，用于存放密钥
centos7_cp_authorkey|false | 拷贝密钥到远程主机，通过密钥文件可以免密登陆
centos7_modify_locale| true |修改字符集
centos7_install_development| true | 安装Development Tools
centos7_modify_timezone|true | 修改时区
centos7_set_time_crontab| true | 设置定时任务，自动同步时间
centos7_modify_sysctl|true | 修改系统内核参数
centos7_modify_ulimit| true | 修改文件描述符
centos7_replace_sshd_config| false | 替换ssh配置文件，配置文件中启用了密钥认证和一些基本优化配置
centos7_iptables_accept_ssh_port| false | 添加iptables规则允许访问新的ssh_port
centos7_modify_motd| true | 修改系统登陆提示信息
centos7_set_hostname| true |设置主机名称，需要在hosts主机清单中定义主机名host_name

当我们在系统初始化优化的时候，可以通过默认变量来控制具体需要优化的参数，比如将 centos7_install_iptables设置为false ，在初始化参数优化的时候将不会安装iptables。

## 2.3 使用Rolse规则

规则使用很简单，只需要创建playbook执行文件，引用role规则即可，在playbook中也可初始化默认变量：

新建一个playbook执行文件：site.yml

```
- hosts: all
  remote_user: root
  vars:
    - centos7_replace_sshd_config: true
    - centos7_iptables_accept_ssh_port: true
    - centos7_modify_motd: false
    - centos7_set_hostname: false
  roles: 
    - common
```

执行roles规则进行系统初始化优化：


```
ansible-playbook site.yml -i hosts  # 指定hosts文件
```

**注意：**

如果想在系统初始优化时，修改ssh的监听端口，需要将centos7_replace_sshd_config 设置为true，同时修改变量文件common/vars/main.yml中的ssh_port，改为你需要修改的端口，同时要将centos7_iptables_accept_ssh_port设置为true，将新端口添加到iptables中，允许访问。

如果想要使用证书来无密管理远程主机，将你的密钥对中的公钥文件拷贝到common/files/中，改名为：common_id_rsa.pub，同时在执行脚本的时候 centos7_create_sshdir和centos7_cp_authorkey改为true。

如果想要在做初始系统优化的时候修改主机名，在定义主机清单文件的时候，需要设置host_name变量：


```
[proxy-hk]
172.16.3.101 ansible_ssh_user=root ansible_ssh_pass=CPBal1Tid host_name=proxy-01-prod.hk.com
172.16.3.102 ansible_ssh_user=root ansible_ssh_pass=mWjGGj2Jl host_name=proxy-02-prod.hk.com
172.16.3.103 ansible_ssh_user=root ansible_ssh_pass=ZjpgV3rAw host_name=proxy-03-prod.hk.com
172.16.3.103 ansible_ssh_user=root ansible_ssh_pass=d9iZR4xe0 host_name=proxy-04-prod.hk.com
```

通过批量优化脚本修改了ssh_port ， 执行完优化脚本后，需要更新主机清单hosts文件中的端口:

```
172.16.3.101:9022 ansible_ssh_user=root ansible_ssh_pass=CPBalTid host_name=proxy-01-prod.hk.com
172.16.3.102:9022 ansible_ssh_user=root ansible_ssh_pass=mWjGGjJl host_name=proxy-02-prod.hk.com
172.16.3.103:9022 ansible_ssh_user=root ansible_ssh_pass=ZjpgVrAw host_name=proxy-03-prod.hk.com
172.16.3.103:9022 ansible_ssh_user=root ansible_ssh_pass=d9iZRxe0 host_name=proxy-04-prod.hk.com
```

通过在playbook中初始化默认变量参数，就可以灵活控制系统基础优化的执行内容。
 