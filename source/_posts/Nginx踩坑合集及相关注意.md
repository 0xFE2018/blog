---
title: Nginx踩坑合集及相关注意
categories:
  - 技术分享
tags:
  - Linux
  - Nginx
abbrlink: 8392180f
date: 2019-08-15 20:53:10
---
<div class="excerpt">
    Nginx踩坑踩到腿软，赶紧点进来看看..   
</div>

<!-- more -->

## 背景
Nginx使用过程中，会出现因为没熟悉指令的官方使用解释，导致的因为主观臆想错误使用指令，不能达到预期效果。现总结下踩过的坑..
## 踩坑王proxy_set_header指令

下面这段proxy_set_header官方说明，请重点关注，甚至熟记，多少坑都是因为这个指令导致的。官方原文地址为：http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_set_header

**摘取：**

Allows redefining the request body passed to the proxied server. The value can contain text, variables, and their combination.
```
Syntax:	proxy_set_header field value;
Default:	
proxy_set_header Host $proxy_host;
proxy_set_header Connection close;
Context:	http, server, location
```
**Allows redefining or appending fields to the request header passed to the proxied server. The value can contain text, variables, and their combinations. These directives are inherited from the previous level if and only if there are no proxy_set_header directives defined on the current level. By default, only two fields are redefined:**
```
proxy_set_header Host       $proxy_host;
proxy_set_header Connection close;
```
### proxy_set_header 踩坑1 - proxy_set_header无效
 proxy_set_header 指令某种情况不能跨配置级别继承，及location不能继承server段proxy_set_header配置，具体看上面官方解释加粗的部分。
 解释如下：
 		proxy_set_header仅仅在location段中无proxy_set_header指令配置时才继承http段已有的proxy_set_header配置。举个例子：
```
server {
proxy_set_header header-a "a";
location{
proxy_set_header header-b "b";
}
}
```
上面这个配置，header-a并未生效，当且仅当如下配置，location才可继承http的proxy_set_header：
```
server {
proxy_set_header header-a "a";
location{
...
#无proxy_set_header配置
}
}
```

### proxy_set_header 踩坑2 - Host header取默认值导致400状态码错误
还是关注下proxy_set_header上面的官方解释，这个指令有两个默认值：
```
Syntax:	proxy_set_header field value;
Default:	
proxy_set_header Host $proxy_host;
proxy_set_header Connection close;
Context:	http, server, location
```
具体踩坑请参考文章：
http://0xfe.com.cn/post/28770b33.html


## rewrite break后，不处理set指令导致500状态码错误
下面这个配置，如果所有省略未写的部分均正确配置，这个配置有问题吗？
```
server{
rewrite /a /b break;
set $host_pass a_b_cluster;
proxy_pass://$host_pass;
}
upstream  a_b_cluster {
server 1.1.1.1:8001;
}
```
答案是有问题。
问题在执行完`rewrite /a /b break;`后，未执行`set $host_pass a_b_cluster;`，直接跳转到proxy_pass，这时变量未被赋值，所以代理到空值，Nginx此时会返回500错误。相关官方文档写到：

If the specified regular expression matches a request URI, URI is changed as specified in the replacement string. The rewrite directives are executed sequentially in order of their appearance in the configuration file. It is possible to terminate further processing of the directives using flags. If a replacement string starts with “http://”, “https://”, or “$scheme”, the processing stops and the redirect is returned to a client.

An optional flag parameter can be one of:

last
stops processing the current set of ngx_http_rewrite_module directives and starts a search for a new location matching the changed URI;
**break**
**stops processing the current set of ngx_http_rewrite_module directives as with the break directive;**
redirect
returns a temporary redirect with the 302 code; used if a replacement string does not start with “http://”, “https://”, or “$scheme”;
permanent
returns a permanent redirect with the 301 code.

当rewrite带有break flag时，会停止处理`ngx_http_rewrite_module`相关指令，该模块指令包含：
```
     break
     if
     return
     rewrite
     rewrite_log
     set
 ```
所以上述配置，需要改写为在rewrite前赋值变量：


```
server{
set $host_pass a_b_cluster;
rewrite /a /b break;
proxy_pass:// $host_pass;
}
upstream  a_b_cluster {
server 1.1.1.1:8001;
}

```





