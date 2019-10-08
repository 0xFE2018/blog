---
title: 关于nf_conntrack
categories:
  - 技术分享
tags:
  - Linux
abbrlink: 821b545c
date: 2019-09-11 21:03:18
---
<div class="excerpt">
    工作中出现过nf_conntrack导致的服务器故障，对nf_conntrack相关总结本文。
</div>

<!-- more -->



## nf_conntrack介绍
nf_conntrack是一个内核模块,用于跟踪一个连接的状态。
最常见的使用连接状态场景是 iptables  state 模块。 iptables 的 nat 通过规则来修改目的/源地址,但光修改地址不行,我们还需要能让回来的包能路由到最初的来源主机。这就需要借助 nf_conntrack 来找到原来那个连接的记录才行。而 state 模块则是直接使用 nf_conntrack 里记录的连接的状态来匹配用户定义的相关规则。例如下面这条 INPUT 规则用于放行 80 端口上的状态为 NEW 的连接上的包：iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT

## nf_conntrack 导致的故障

nf_conntrack是记录连接状态的，存在记录条数最大值，当到最大值后，系统会丢掉新的连接包，直到连接数小于最大值。此时会出现 `nf_conntrack: table full, dropping packet.`报错。

解决方案：

- 确定问题，有相关报错
- 查看是否有iptables语句使用state模块，如果有,清空后重启iptables 及 卸载模块
- 如果必须使用连接跟踪，则需要对相关参数进行优化。

出现问题时，通常关闭 防火墙即可临时解决，下面介绍相关参数，如需要优化调整可参考。

##  nf_conntrack相关文件

- 查看是否加载
lsmod |grep nf_conntrack

- 查看哈希表大小
 cat /proc/sys/net/netfilter/nf_conntrack_buckets

- 查看系统定义最大连接数，如当前跟踪连接数超过，会出现丢包问题。
cat /proc/sys/net/netfilter/nf_conntrack_max，默认值为nf_conntrack_buckets*4

- 查看连接表条数，该值小于/proc/sys/net/netfilter/nf_conntrack_max，如果达到会报错
cat /proc/net/nf_conntrack |wc -l

## /proc/net/nf_conntrack 连接表长什么样

[root~]# cat  /proc/net/nf_conntrack |head -5

```
ipv4     2 tcp      6 62 TIME_WAIT src=1.1.1.1 dst=2.2.2.2 sport=56625 dport=8001 src=2.2.2.2 dst=1.1.1.1 sport=8001 dport=56625 [ASSURED] mark=0 secmark=0 use=2
ipv4     2 tcp      6 102 TIME_WAIT src=1.1.1.1 dst=3.3.3.3 sport=39113 dport=8001 src=3.3.3.3 dst=1.1.1.1 sport=8001 dport=39113 [ASSURED] mark=0 secmark=0 use=2
```

分别对应：

`网络协议 协议号 传输协议 协议号  老化时间 状态 ，后面的为源目的ip:port`

- [ASSURED]: 在两个方面（即请求和响应）方向都看到了流量。
-  [UNREPLIED]: 尚未在响应方向上看到流量。如果连接跟踪缓存溢出，则首先删除这些连接。

## 如果需要使用nf_conntrack,相关优化

- 优化/proc/sys/net/netfilter/nf_conntrack_buckets（只读文件）
```
修改/etc/modprobe.d/nf_conntrack.conf，内容为options nf_conntrack hashsize=262144，重新装载模块生效
```

- 优化/proc/sys/net/netfilter/nf_conntrack_max 
```
sysctl -w net.netfilter.nf_conntrack_max=1048576
```
- 优化老化时间
```
net.netfilter.nf_conntrack_tcp_timeout_established=180
net.netfilter.nf_conntrack_tcp_timeout_close_wait=60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait=120
net.netfilter.nf_conntrack_tcp_timeout_time_wait=120
```







