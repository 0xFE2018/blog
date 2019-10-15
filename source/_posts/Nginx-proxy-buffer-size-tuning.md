---
title: Nginx proxy_buffer_size tuning
categories:
  - 技术分享
tags:
  - Nginx
  - tuning
abbrlink: b455f764
date: 2019-10-10 14:12:14
---
<div class="excerpt">
    upstream sent too big header while reading response header from upstream 报错，网上博文统一的解决办法，是正确的吗?
</div>

<!-- more -->

# Nginx proxy-buffer-size tuning

工作中，Nginx出现过如下502报错：
```
2019/10/10 14:08:36 [error] 8519#0: *268682 upstream sent too big header while reading response header from upstream, client: 2.2.2.2, server: test.com, request: "GET / HTTP/1.1", upstream: "http://1.1.1.1:65533/", host: "test.com"
```

upstream sent too big header while reading response header from upstream,这个报错，意思是nginx proxy传过来的header过大。

### 不太好的解决方案

很多博客没有具体分析原因，推荐的解决办法是修改或增加如下配置：

```
proxy_buffers 4 256k;
proxy_buffer_size 128k; 
proxy_busy_buffers_size 256k;

```
配置后，502问题解决，但是这几个参数的值具体到什么数，或者什么量级，没有进一步解释。

### proxy-buffer-size 是什么意思？

说明一点：
当出现`upstream sent too big header while reading response header from upstream`报错时，**仅需调整proxy-buffer-size参数，无需调整其他。**

官网对该指令的解释：
>Syntax:	proxy_buffer_size size;
Default:	
proxy_buffer_size 4k|8k;
Context:	http, server, location
Sets the size of the buffer used for reading the first part of the response received from the proxied server. This part usually contains a small response header. By default, the buffer size is equal to one memory page. This is either 4K or 8K, depending on a platform. It can be made smaller, however.

它定义了nginx将分配给代理服务器的每个请求的内存量。这小块内存将用于读取和存储响应的一小部分-HTTP头。
默认值4k或者8k根据paltform决定，但对普通的web业务，是够用了。对于部分请求有set-cookie等header，就需要调整这个值。

### 设置合理的proxy-buffer-size大小

```
curl -s -w \%{size_header} -o /dev/null http://1.1.1.1  -H "Host: test.com"
```
获取response的header大小，再根据大小合理调整proxy_buffer_size的值。

### proxy_buffering off 

该指令控制缓冲功能，关闭后proxy-buffer-size指令依然生效。






