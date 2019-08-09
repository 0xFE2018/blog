---
title: 聊聊Timewait
tags:
  - Linux
categories: 
  - 技术分享
abbrlink: b5a9a6f
date: 2019-08-08 12:55:53
---

## 聊聊TIMEWAIT

### 为什么处于timewait状态

下面是TCP释放连接的时候经历的四次挥手阶段图示。
![](./_image/2018-12-11-19-50-11.png)

下面是四次挥手过程的简述：
- 客户端发起断开连接请求后，进入FIN-WAIT1状态，第一次收到来自服务端的ACK应答，开始进入FIN-WAIT2状态。
- 随后服务端发起FIN，客户端收到FIN，随后发送ACK，服务器收到后进入CLOSED状态。
*问题*：
发送完最后的ACK报文后，此时客户端**可以进入关闭状态**，但是，为什么需要保持一段时间再进入CLOSE，如图示中的，发送最后一个ACK后维持在TIME-WAIT状态呢？
*分析*：
        客户端发送ACK后，直接进入CLOSE状态。如果此时，**客户端最后一个ACK，丢包了怎么办？**
        如果ACK因为网络原因丢掉，服务端会重新发起FIN包，若此时客户端直接CLOSED掉，肯定处理不了上个连接的FIN包。**为了能够处理由于网络丢包导致服务端没有收到ACK而重发的FIN包，客户端会维持一个2MSL时间长的状态**，即**TIME-WAIT状态**。

### timewait状态有什么问题

上节介绍TIME-WAIT存在的道理，不能没有这个状态。但是客户端如果大量连接保持在TIME-WAIT状态有什么问题或者危害呢？如果在连接数不多的场景下，没有什么具体的危害。如果在连接并发数特别多的生产环境（高并发短连接）下，TIME-WAIT状态会使客户端维持一个无数据传输的连接，需要占用一定的连接资源，在特殊场景下，因客户端源端口只6w个，会使客户端无法进行新连接的建立。所以，**TIME-WAIT过多，可能会影响生产环境**。对此，高并发场景下，我们需要对TIME-WAIT状态进行合理的优化。
>影响如，nginx出现无可用端口问题时，会无法和后端服务器进行新连接，报错状态信息如下：
>(99: Cannot assign requested address)

### 如何优化或解决timewait过多的问题？
上面提到，TIME-WAIT状态过多会导致生产环境并发连接数过大的情况下产生无法建立新连接的错误，所以是不是有合适的系统参数可以解决或者优化这种情况。
下面有几种方法对TIME-WAIT状态的缓解或优化措施：
- *不影响连接的方法*：以下方法都是对TIME-WAIT状态带来的影响进行优化，对实际建立的TCP连接没有影响。
    - **增加可用端口范围net.ipv4.ip_local_port_range **= 1024     65535 （缓解）：系统参数ip_local_port_range表示客户端和服务端发起连接时选择的随机源端口的范围，1-1024为保留端口，所以可以将源端口设置为最大范围1024到65535，来缓解可用端口不够的问题。
    - **减小TCP_TIMEWAIT_LEN值**：可以减少TIME-WAIT状态的时间长度，可以加快客户端进入CLOSE状态，也可以一定程度缓解TIME-WAIT状态导致的可用端口资源不够的情况，但是此参数修改需要修改内核重新编译。
    - **使用HTTP长链接**：客户端和服务器之间使用长链接，如nginx upstream中增加keepalive字段，使得http请求可以服用已经建立的TCP连接，减少新连接的建立，可以减缓可以端口耗尽的问题发生。但是使用长链接会对nginx性能有所影响。
- *影响连接的方法*：下面的方法通过更改系统参数，对维持在TIME-WAIT状态的连接进行处理，来关闭连接使客户端进入CLOSE状态，这些方法会对这些TCP连接有所影响，连接是被系统被动关闭。
    - **设置tcp_tw_reuse参数**：tcp_tw_reuse参数的功能是开启处在TIME-WAIT状态的TCP socket重用，可以直接将TIME-WAIT状态的连接复用进行下一个连接而不用等待这一状态自动结束。
    - **设置tcp_tw_recycle参数**：同tcp_tw_reuse参数的功能类似，但是比tcp_tw_reuse更加暴力的复用socket。
下面将介绍这两个参数的具体工作方法和区别。

#### tcp_tw_reuse参数介绍

tcp_tw_reuse定义：
>Allow to reuse TIME-WAIT sockets for new connections when it is **safe from protocol viewpoint.** Default value is 0.
当处在TIME-WAIT状态的连接为协议安全时，可以服务此socket。
何为协议安全呢？下面介绍满足协议安全的**两个**条件：
- **只适用于客户端角色，连接请求方**。下面为具体的相关内核代码：

```c
static int __inet_check_established(struct inet_timewait_death_row *death_row,
                    struct sock *sk, __u16 lport,
                    struct inet_timewait_sock **twp)
{
    /* ……省略…… */
    sk_nulls_for_each(sk2, node, &head->chain) {
            if (sk2->sk_hash != hash)
                        continue;
                        
            if (likely(INET_MATCH(sk2, net, acookie,
                    saddr, daddr, ports, dif))) {
                        if (sk2->sk_state == TCP_TIME_WAIT) {
                            tw = inet_twsk(sk2);
                            if (twsk_unique(sk, sk2, twp))
                                break;
            }
            goto not_unique;
        }
    }
    /* ……省略…… */
}
```
- **timewait时间超过1s的socket**：下面为相关代码：

```c
int tcp_twsk_unique(struct sock *sk, struct sock *sktw, void *twp)
{
    /* ……省略…… */
    if (tcptw->tw_ts_recent_stamp &&
        (!twp || (sock_net(sk)->ipv4.sysctl_tcp_tw_reuse &&
         get_seconds() - tcptw->tw_ts_recent_stamp > 1))) {
         /* ……省略…… */
         return 1;
    }
    return 0;
}
```

满足以上两个条件的，称为“协议安全”。
如代码中看到，如果需要此参数生效，需要同时开启net.ipv4.tcp_timestamps参数，两个参数其中任何一个值为0都不会使复用socket生效。当开启复用socket时，每复用一次，proc文件系统中的netstat文件（/proc/net/netstat）中的TWrecycled计数器字段会增加1。

#### tcp_tw_recycle参数介绍
下面介绍另外一个参数，tcp_tw_recycle。如上述介绍，tcp_tw_reuse为协议安全的，开启reuse参数后，只会复用协议安全的socket，但开启tcp_tw_recycle参数则会复用所有的TIME-WAIT状态的socket，被称为**快速回收**，会影响连入和连出的连接。
注意，开启此参数后，Linux系统会**丢弃所有来自远端的timestramp时间戳小于上次记录的时间戳(由同一个远端发送的)的任何数据包**。也就是说要使用该选项，则必须保证数据包的时间戳是**单调递增**的。使用此选项的nginx服务器，会出现请求连接的syn报文被丢弃的现象，出现connection timeout的问题，生产环境对外的服务器和NAT环境均不推荐使用此选项进行回收socket。

#### 当前测试机器reuse和recycle参数取值
**nginx参数取值为**：
- net.ipv4.ip_local_port_range=1024 65535
- net.ipv4.tcp_timestamps = 0
- net.ipv4.tcp_tw_recycle = 0（未生效）
- net.ipv4.tcp_tw_reuse = 1 （未生效）
- HTTP长链接：个别特殊业务和后端为长链接，其他均为短连接
如上述介绍，这两个参数net.ipv4.tcp_timestamps都需要开启时间戳参数。线上该参数关闭，所以这两个参数都未生效。
每一次复用，在proc系统下的netstat文件中都会将TWRcycled字段增加1，下图为nginx服务器的该文件截图，TWRcycled值为0，表示未进行TIME-WAIT socket复用。

关于TIME-WAIT状态复用的建议：
>1.tcp_tw_recycle建议不要打开，4.12内核后无此参数
>2.tcp_tw_reuse，对客户端可以考虑使用（如nginx反向代理）
>上述两个选项都需要打开时间戳参数tcp_timestamps=1

### 总结

全文介绍了TIME-WAIT状态设计的原因和作用，以及提出了在并发数过大导致TIME-WAIT状态数过多的场景下，有可能导致客户端可用端口数耗尽的问题。并给出了影响连接和不影响连接的优化方法，可以结合生产环境的实际情况，对TIME-WAIT状态进行优化。了解这些，可以方便之后排查相关的问题。

>另外，读者可以考虑下，可用随机端口6w，但一台nginx上timewait状态连接数高达80w，却未出现类似(99: Cannot assign requested address)现象的原因是什么呢？

更多TimeWait相关可参考作者其他博文！



