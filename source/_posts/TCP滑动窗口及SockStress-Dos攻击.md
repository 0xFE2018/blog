---
title: TCP滑动窗口及SockStress Dos攻击
categories:
  - null
tags:
  - Linux
abbrlink: 36f1b3e1
date: 2019-09-30 14:08:01
---
<div class="excerpt">
    看了皓哥的《TCP那些事》，发现介绍了sockstress攻击，感觉挺有意思，记录之。以下部分引用自coolshell：https://coolshell.cn/articles/11609.html   
</div>

<!-- more -->

看了皓哥的《TCP那些事》，发现介绍了sockstress攻击，感觉挺有意思，记录之。以下部分引用自coolshell：https://coolshell.cn/articles/11609.html

## TCP header

{% asset_img tcpheader.jpg tcpheader %}

其中，**Window**又叫Advertised-Window，也就是著名的滑动窗口（Sliding Window），用于解决流控的，接下来的滑动窗口介绍和这个字段相关。

##  TCP滑动窗口

需要说明一下，如果你不了解TCP的滑动窗口这个事，你等于不了解TCP协议。我们都知道，TCP必需要解决的**可靠传输以及包乱序（reordering）**的问题，所以，TCP必需要知道网络实际的数据处理带宽或是数据处理速度，这样才不会引起网络拥塞，导致丢包。

所以，TCP引入了一些技术和设计来做网络流控，Sliding Window是其中一个技术。 前面我们说过，TCP头里有一个字段叫Window，又叫Advertised-Window，这个字段是接收端告诉发送端自己还有多少缓冲区可以接收数据。于是发送端就可以根据这个接收端的处理能力来发送数据，而不会导致接收端处理不过来。 为了说明滑动窗口，我们需要先看一下TCP缓冲区的一些数据结构：
{% asset_img sliding_window.jpg sliding_window %}
上图中，我们可以看到：

- 接收端LastByteRead指向了TCP缓冲区中读到的位置，NextByteExpected指向的地方是收到的连续包的最后一个位置，LastByteRcved指向的是收到的包的最后一个位置，我们可以看到中间有些数据还没有到达，所以有数据空白区。
- 发送端的LastByteAcked指向了被接收端Ack过的位置（表示成功发送确认），LastByteSent表示发出去了，但还没有收到成功确认的Ack，LastByteWritten指向的是上层应用正在写的地方。

于是：
- 接收端在给发送端回ACK中会汇报自己的AdvertisedWindow = MaxRcvBuffer – LastByteRcvd – 1;
- 而发送方会根据这个窗口来控制发送数据的大小，以保证接收方可以处理。
下面我们来看一下发送方的滑动窗口示意图：
{% asset_img tcpswwindows.png tcpswwindows %}
上图中分成了四个部分，分别是：（其中那个黑模型就是滑动窗口）

- 1已收到ack确认的数据。
- 2发还没收到ack的。
- 3在窗口中还没有发出的（接收方还有空间）。
- 4窗口以外的数据（接收方没空间）
下面是个滑动后的示意图（收到36的ack，并发出了46-51的字节）：
{% asset_img tcpswslide.png tcpswslide %}

## Zero Window

上图，我们可以看到一个处理缓慢的Server（接收端）是怎么把Client（发送端）的TCP Sliding Window给降成0的。此时，你一定会问，如果Window变成0了，TCP会怎么样？是不是发送端就不发数据了？是的，发送端就不发数据了，你可以想像成“Window Closed”，那你一定还会问，如果发送端不发数据了，接收方一会儿Window size 可用了，怎么通知发送端呢？

解决这个问题，TCP使用了Zero Window Probe技术，缩写为ZWP，也就是说，发送端在窗口变成0后，会发ZWP的包给接收方，让接收方来ack他的Window尺寸，一般这个值会设置成3次，第次大约30-60秒（不同的实现可能会不一样）。如果3次过后还是0的话，有的TCP实现就会发RST把链接断了。

注意：只要有等待的地方都可能出现DDoS攻击，Zero Window也不例外，一些攻击者会在和HTTP建好链发完GET请求后，就把Window设置为0，然后服务端就只能等待进行ZWP，于是攻击者会并发大量的这样的请求，把服务器端的资源耗尽。

另外，Wireshark中，你可以使用**tcp.analysis.zero_window**来过滤包，然后使用右键菜单里的follow TCP stream，你可以看到ZeroWindowProbe及ZeroWindowProbeAck的包。
## SockStress攻击
sockstress攻击不同于常见的SYN攻击，是在三次握手后连接建立完发起的，详看下面的一段介绍：

>Sockstress is a Denial of Service attack on TCP services discovered in
    2008 by Jack C. Louis from Outpost24. It works by using RAW sockets
    to establish many TCP connections to a listening service. Because the 
    connections are established using RAW sockets, connections are established
    without having to save any per-connection state on the attacker's machine.
	
   > Like SYN flooding, sockstress is an asymmetric resource consumption attack:
    It requires very little resources (time, memory, and bandwidth) to run a 
    sockstress attack, but uses a lot of resources on the victim's machine.
    Because of this asymmetry, a weak attacker (e.g. one bot behind a cable 
    modem) can bring down a rather large web server.
	
   > Unlike SYN flooding, sockstress actually completes the connections, and 
    cannot be thwarted using SYN cookies. In the last packet of the three-way 
    handshake a ZERO window size is advertised -- meaning that the client is 
    unable to accept data -- forcing the victim to keep the connection alive
    and periodically probe the client to see if it can accept data yet.
	
> 攻击工具项目地址：github:https://github.com/defuse/sockstress

sockstress是建立三次握手后，将window设置成0，被攻击方会发送zero window probe包进行探测，来达到dos目的。
这种攻击方式目前仍然有效，且不能很好的防御，可以临时通过防火墙的方式防御，但是不能防御ddos：
```
iptables -I INPUT -p tcp –dport 80 -m state–state NEW -m recent–set
iptables -I INPUT-p tcp -dport 80 -m state-state NEW-m recent -update–seconds 30 -hitcount 10 j DROP
```



