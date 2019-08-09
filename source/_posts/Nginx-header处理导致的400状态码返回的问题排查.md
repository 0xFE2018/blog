---
title: 'Nginx header处理导致的400状态码返回的问题排查 '
categories:
  - 问题解决
tags:
  - Linux
abbrlink: 28770b33
date: 2019-08-09 09:52:29
---
<div class="excerpt">
   业务有反馈接入Nginx后响应400，经过分析后发现Nginx竟然对两个header做了这些默认处理..
</div>

<!-- more -->

## 问题背景
    
近日，有业务反馈接入nginx的域名返回400错误的问题。经过测试，使用域名接入nginx FE访问的方式，服务端会返回状态码400错误，而使用IP:PORT方式直接访问，服务端可正常响应请求，返回200状态码。

后来发现，Nginx在该问题域名Server段中，缺少了``proxy_set_header Host $host``这一行配置，我们认为是Nginx反向代理时，没有将Host header字段写入HTTP请求中，导致400错误。之后添加上这行配置上线后，故障恢复。
   
但是故障原因不能确定为Host字段没有加在请求头发送给后端服务器，因为在排查时，发现有如下现象，不能合理解释：
- 使用telnet工具测试，构造不带Host头部的请求，服务端可以正常地响应。
- 测试的同时，我们随机构造类似“ ”，“test”,“aaabbb”之类的Host字段值，发现服务端均可以正常响应请求，如下图示。
    
经过抓包排查，Nginx配置中缺少``proxy_set_header Host $host``这一行配置，导致其没有正确处理Host字段，而使用自身处理方式，将不正确且格式异常的Host带入后端服务器，服务器检查Host字段异常，及HTTP请求参数不合法，返回400错误。这个非法的Host字段值正是业务集群名(xxx_pool),HTTP认为下划线等为非法Host值，直接返回400错误。
## 问题分析和结论
- Nginx中指令 ``proxy_set_header`` 的功能是什么？header “Host”字段如何处理？

经过抓包分析，以及参照官方文档，我们发现，``proxy_set_header`` 会在反向代理时对HTTP请求中header字段进行重写或新建其他header字段，来达到预期代理的目的，很具有灵活性。如果不使用该指令设置nginx的header，来自用户的HTTP请求中的Header会被透传给后端服务器，但以下3种Header例外，及：**Host 和 Connection，还有关于缓存相关的header**。
> Nginx proxy_set_header 两个默认值如下：
>proxy_set_header Host   $proxy_host;
>proxy_set_header Connection close;
> 如果开启Nginx缓存：If-Modified-Since，If-Unmodified-Since，If-None-Match，If-Match，Range，If-Range等header不会透传。
       
除上述3种header使用默认值外，其他均透传客户端HTTP请求中的Header字段给后端。这次400状态码返回是因为未设置`proxy_set_header Host $host`，导致Host字段使用了默认值,``$proxy_host``传给后端，``$proxy_host``变量即为``proxy_pass http://``  后端的变量名，在本次case中，将集群名“xxx_pool”作为Host首部传到了后端服务器，以下为Nginx端抓包截图，可见Host字段取了``$proxy_host``,即集群名。
后端收到“xxx_pool”的Host header后会检查是否为标准域名格式，域名中不应该包含“_",故返回参数错误状态码400.

## 解决及优化

    
使用``proxy_set_header Host $http_host``重设Host值，``$http_host``表示Nginx收到的用户请求中的Host值，一般为域名，这样Host就会重写加入HTTP请求发至后端服务器。
    
优化：为了防止用户请求中不带Host字段导致``$http_host``为空的情况，我们可以采用``$host``代替``$http_host``，``$host``表示主域名，即``server_name``指令的值。在基于当前业务背景，对Nginx配置进行标准化与自动化时，``proxy_set_header Host $host``是必需配置的header之一，如不正确配置，会出现无法代理的情况。


