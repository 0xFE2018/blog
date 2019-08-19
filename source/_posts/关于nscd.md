---
title: 关于nscd
categories:
  - 技术分享
tags:
  - Linux
  - DNS
abbrlink: 8dd34dff
date: 2019-08-09 19:05:33
---
<div class="excerpt">
    关于Linux上的nscd服务,做了下调研总结..
</div>

<!-- more -->

# NSCD
缓存服务，自建的网络dns client 如dig不会用到nscd服务，而其他调用GETHOSTBYNAME的应用程序则会用到，如ping。

## 关键配置及缓存DNS功能介绍

```table
|配置|含义|
reload-count |主动刷新的次数，之后未使用即清空
enable-cache hosts [yes no] |开启缓存         
positive-time-to-live hosts value  |成功缓存的时间 
negative-time-to-live hosts value    |失败缓存的时间  
```
### nscd对结果的缓存

以下将通过hosts即DNS缓存进行说明：
enable-cache            hosts           yes
positive-time-to-live   hosts           3600
negative-time-to-live   hosts           20
实际查看代码发现配置positive-time-to-live hosts并没有什么用处，代码中hstcache.c主流程中会直接读取DNS报文中的TTL并赋值给需要计算的timeout:
` /* Compute the timeout time.  */
      dataset->head.ttl = ttl == INT32_MAX ? db->postimeout : ttl;
      timeout = dataset->head.timeout = t + dataset->head.ttl;`
**成功结果的缓存**
成功结果缓存的时间为：
TTL+CACHE_PRUNE_INTERVAL（默认15s）
到了时间后，nscd会主动发起dns请求进行reload，每次reload间隔为15s，重新获取结果，当到达reload-count配置的次数后，不论有没有继续使用，直接清空，也不会继续主动reload。
**非成功结果的缓存**
时间为：negative-time-to-live+CACHE_PRUNE_INTERVAL（默认15s）

### DNS A记录轮训失效

nscd每次将取得的A记录列表的第一个进行缓存，需要下一次reload才会对结果进行更新，所以A记录轮训会失效。

### CNAME+A

在有CNAME+A的级联应答结果中，缓存的timeout将只会读取对应的A记录的TTL

### 总结

优点：使用nscd可以提高DNS解析性能，降低DNS并发，但是需要注意：
- 域名生效需要时间 TTL+15s
- A记录轮训不能生效，只有nscd下一次请求才能更新结果
- negative-time-to-live   hosts    0  尽量设置为0

## 测试

Tue 12 Feb 2019 **02:36:56** PM CST - 1875: **Haven't found "testzhangquan.test.org" in hosts cache!**
**TTL（10s）+15s = 25s 后，**
Tue 12 Feb 2019 **02:37:21** PM CST - 1875: **Reloading** "testzhangquan.test.org" in hosts cache!
**15s**
Tue 12 Feb 2019 **02:37:36** PM CST - 1875: Reloading "testzhangquan.test.org" in hosts cache!
**15s**
Tue 12 Feb 2019 **02:37:51** PM CST - 1875: Reloading "testzhangquan.test.org" in hosts cache!
**15s**
Tue 12 Feb 2019 **02:38:06** PM CST - 1875: Reloading "testzhangquan.test.org" in hosts cache!
**15s**
Tue 12 Feb 2019 02:38:21 PM CST - 1875: Reloading "testzhangquan.test.org" in hosts cache!
**15s**
Tue 12 Feb 2019 02:38:36 PM CST - 1875: remove GETHOSTBYNAME entry "testzhangquan.test.org"


## nscd相关操作

- nscd -d  debug开启调试打印信息
- nscd -i hosts 清空缓存
- nscd -g


