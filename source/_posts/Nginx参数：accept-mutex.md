---
title: Nginx参数：accept_mutex
categories:
  - Nginx
tags:
  - Linux
abbrlink: '22472404'
date: 2019-08-28 10:34:57
---
<div class="excerpt">
    Nginx惊群效应和accept_mutex
</div>

<!-- more -->

# Nginx参数：accept_mutex

## 惊群效应
**生活中的惊群效应：**
当你往一群鸽子中间扔一块食物，虽然最终只有一个鸽子抢到食物，但所有鸽子都会被惊动来争夺，没有抢到食物的鸽子只好回去继续睡觉， 等待下一块食物到来。这样，每扔一块食物，都会惊动所有的鸽子，即为惊群。
**操作系统中的惊群效应：**
在多进程/多线程等待同一资源时，也会出现惊群。即当某一资源可用时，多个进程/线程会惊醒，竞争资源。这就是操作系统中的惊群。
操作系统的惊群效应有两种：**accpet惊群**和**epoll惊群**
在内核2.6以后，系统中的accpet惊群效应通过增加互斥等待锁解决，通过 WQ_FLAG_EXCLUSEVE 标志位，防止多个进程同时监听一个socket产生的惊群效应。epoll惊群分为两种情况：fork之前创建epollfd，fork之后创建epollfd。
**Nginx中的惊群效应：**
当一个新连接到达时，如果激活了accept_mutex，那么多个Worker将以串行方式来处理，其中有一个Worker会被唤醒，其他的Worker继续保持休眠状态；如果没有激活accept_mutex，那么所有的Worker都会被唤醒，不过只有一个Worker能获取新连接，其它的Worker会重新进入休眠状态。所有进程都被唤醒，也就是惊群效应。这种惊群效应，就是上面说的fork之后创建epollfd产生的惊群效应。

## Nginx accpet_mutex指令

```
events {
accept_mutex off/on;
}
```
Nginx在官方早些版本1.11.1前缺省打开了accept_mutex on，来解决worker进程惊群效应:

```
Changes with nginx 1.11.3                                        26 Jul 2016
    *) Change: now the "accept_mutex" directive is turned off by default.
```
    
在1.11.3之后版本中，因系统中EPOLLEXCLUSIVE标志位可避免惊群效应，故accept_mutex值默认修改为off。
惊群效应对nginx有什么影响呢？
Nginx作者提过，在Nginx单CPU单进程工作下，惊群效应会增加机器CPU负载和上下文切换，但是在多CPU下，惊群效应影响较小。
>OS may wake all processes waiting on accept() and select(), this is called thundering herd problem. This is a problem if you have a lot of workers as in Apache (hundreds and more), but this insensible if you have just several workers as nginx usually has. Therefore turning accept_mutex off is as scheduling incoming connection by OS via select/kqueue/epoll/etc (but not accept()).

## accpet_mutex取值

- accept_mutex off时，所有worker的epoll都会监听listening中的所有fd，一旦有新连接过来，各worker间会增强资源。
- 对于大量短链接的场景，可以打开accept_mutex，可以减少worker进程争夺资源造成的上下文切换以及try_lock的锁开销。
- 对于传输大量数据的tcp长链接来说，开启accept_mutex会导致压力集中在某几个worker上，特别是将worker_connection值设置过大的时候，影响更加明显。因此对于accept_mutex开关的使用，根据实际情况考虑，不可一概而论。
- accept_mutex开启时，压测整体QPS下降。
- 新Linux内核中增加了EPOLLEXCLUSIVE选项，nginx从1.11.3版本之后也增加了对NGX_EXCLUSIVE_EVENT选项的支持，这样就可以避免多worker的epoll出现的惊群效应，从此之后accept_mutex从默认的on变成了默认off。
综合多CPU场景惊群效应的影响较小，以及系统内核对事件惊群效应的解决方案，建议系统将该参数关闭，使用`accept_mutex off`,Nginx 1.11.3版本开始已经将该参数默认值从on改为off。

### accpet_mutex on

```
[root nginx-systemtap-toolkit]# ./ngx-req-distr -m `cat /opt/soft/nginx/run/nginx.pid`
Tracing 11239 11240 11241 11242 11243 11244 11245 11246 11247 11248 11249 11250 11251 11252 11253 11254 11255 11256 11257 11258 11259 11260 11261 11262 11263 11264 11265 11266 11267 11268 11269 11270 11271 11272 11273 11274 11275 11276 11277 11278 (/opt/soft/nginx/sbin/nginx)...
Hit Ctrl-C to end.
^C
worker 11239:   2 reqs
worker 11240:   6 reqs
worker 11241:   0 reqs
worker 11242:   0 reqs
worker 11243:   0 reqs
worker 11244:   2 reqs
worker 11245:   4 reqs
worker 11246:   0 reqs
worker 11247:   0 reqs
worker 11248:   0 reqs
worker 11249:   10 reqs
worker 11250:   0 reqs
worker 11251:   25 reqs
worker 11252:   0 reqs
worker 11253:   0 reqs
worker 11254:   0 reqs
worker 11255:   0 reqs
worker 11256:   0 reqs
worker 11257:   1 reqs
worker 11258:   6 reqs
worker 11259:   0 reqs
worker 11260:   32 reqs
worker 11261:   0 reqs
worker 11262:   0 reqs
worker 11263:   0 reqs
worker 11264:   0 reqs
worker 11265:   11 reqs
worker 11266:   0 reqs
worker 11267:   0 reqs
worker 11268:   16 reqs
worker 11269:   0 reqs
worker 11270:   0 reqs
worker 11271:   23 reqs
worker 11272:   9 reqs
worker 11273:   29 reqs
worker 11274:   0 reqs
worker 11275:   0 reqs
worker 11276:   14 reqs
worker 11277:   10 reqs
worker 11278:   0 reqs
```

### accpet_mutex off

```
[root nginx-systemtap-toolkit]# ./ngx-req-distr -m `cat /opt/soft/nginx/run/nginx.pid`
Tracing 13273 13274 13275 13276 13277 13278 13279 13280 13281 13282 13283 13284 13285 13286 13287 13288 13289 13290 13291 13292 13293 13294 13295 13296 13297 13298 13299 13300 13301 13302 13304 13305 13307 13308 13309 13310 13312 13313 13315 13317 (/opt/soft/nginx/sbin/nginx)...
Hit Ctrl-C to end.
^C
worker 13273:   2 reqs
worker 13274:   12 reqs
worker 13275:   2 reqs
worker 13276:   1 reqs
worker 13277:   12 reqs
worker 13278:   2 reqs
worker 13279:   11 reqs
worker 13280:   5 reqs
worker 13281:   4 reqs
worker 13282:   1 reqs
worker 13283:   10 reqs
worker 13284:   1 reqs
worker 13285:   4 reqs
worker 13286:   1 reqs
worker 13287:   0 reqs
worker 13288:   12 reqs
worker 13289:   3 reqs
worker 13290:   0 reqs
worker 13291:   5 reqs
worker 13292:   5 reqs
worker 13293:   8 reqs
worker 13294:   8 reqs
worker 13295:   5 reqs
worker 13296:   3 reqs
worker 13297:   2 reqs
worker 13298:   3 reqs
worker 13299:   3 reqs
worker 13300:   3 reqs
worker 13301:   5 reqs
worker 13302:   2 reqs
worker 13304:   2 reqs
worker 13305:   12 reqs
worker 13307:   1 reqs
worker 13308:   6 reqs
worker 13309:   8 reqs
worker 13310:   12 reqs
worker 13312:   4 reqs
worker 13313:   8 reqs
worker 13315:   9 reqs
worker 13317:   3 reqs
```

