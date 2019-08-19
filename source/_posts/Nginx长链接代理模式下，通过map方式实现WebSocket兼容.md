---
title: Nginx长链接代理模式下，通过map方式实现WebSocket兼容
categories:
  - 技术分享
tags:
  - Linux
  - Nginx
abbrlink: 83c209d
date: 2019-08-15 13:16:35
---
<div class="excerpt">
    工作中有很多时候，业务请求使用websocket(ws:)方式,需要nginx代理到后端时做相应的改写才能实现,什么办法可以使用一个模板配置兼容websocket这个协议呢？点击查看
</div>

<!-- more -->

## 背景引入
工作中有很多时候，业务请求使用websocket(ws:)方式,需要nginx代理到后端时做相应的改写才能实现，具体改写的location部分包括以下：
```
       proxy_http_version 1.1;
       proxy_set_header Upgrade $http_upgrade;
       proxy_set_header Connection "upgrade";
```
默认情况下，如不使用websocket协议，只使用http代理的话，nginx的默认配置为：
```
       proxy_http_version 1.1;
       proxy_set_header Connection "";
```

这种情况，如果想使用一套配置兼容websocket协议，可以采用map方式对相关变量进行赋值，不同协议有不同的特征，可以当成key，对应变化的配置值当成value，使用map方式可以实现WebSocket兼容。

## Map方案
```
map  $http_connection $map_connection{
				upgrade "upgrade";
				default "";
				}
```
如果connection为upgrade，则`$map_connection`为"upgrade"，其他情况为空值。

## 兼容配置

```
		map  $http_connection $map_connection{
				upgrade "upgrade";
				default "";
				}
		proxy_http_version 1.1;
		proxy_set_header Upgrade $http_upgrade;
		proxy_set_header Connection $map_connection;
```









