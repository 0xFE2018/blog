---
title: Linux性能分析-CPU利用率
categories:
  - Linux性能分析
tags:
  - Linux
abbrlink: 5c3f484
date: 2019-08-08 18:22:39
---
<div class="excerpt">
	Linux中，CPU使用率相关
</div>

<!-- more -->

# proc文件系统
- HZ：1秒钟内，时钟中断的次数，即1秒钟内，系统时钟的节拍次数
- jiffies：全局变量，用来记录系统自启动以来产生的节拍总数
- 系统运行时间（以秒为单位）：system_time=(jiffies)/HZ
/proc是linux中一个虚拟的文件系统：文件系统包含了一些目录（用作组织信息的方式）和虚拟文件。虚拟文件可以向用户呈现内核中的一些信息，也可以用作一种从用户空间向内核发送信息的手段。

## 什么是CPU利用率
- 查看/proc/stat
```
[root()@ ~]# cat /proc/stat |grep ^cpu
cpu  66821624 108828 167601995 5628625868 2469887 133770324 102589574 140271 0
cpu0 30385305 87478 54557932 2974862558 1923358 162 9966684 33758 0
cpu1 36436319 21349 113044063 2653763310 546529 133770162 92622890 106513 0
```
分别对应着：
us,ni,sy,id,iowait,irq,softirq,st,guest,guest_nice

- 如何计算CPU利用率
    - top
```
Cpu(s):  1.1%us,  2.7%sy,  0.0%ni, 92.2%id,  0.0%wa,  2.2%hi,  1.7%si,  0.0%st
```
```table
|值|意义|
|us|用户态CPU时间|
|sy|系统态CPU时间|
|ni|低优先级进程CPU时间,即nice值被调整在0-19间|
|id|空闲CPU时间|
|wa|等待IO时间|
|hi|处理硬中断时间|
|si|处理软中断时间|
|st|作为虚拟机被运行的时间|
```
- pidstat

```
[root()@ ~]# pidstat 1 1
Linux 2.6.32-504.el6.x86_64 (.58os.org)      12/03/2018      _x86_64_        (2 CPU)

08:50:09 PM       PID    %usr %system  %guest    %CPU   CPU  Command
08:50:10 PM       798    0.96    8.65    0.00    9.62     1  pidstat
08:50:10 PM     20512    0.00    0.96    0.00    0.96     0  java
08:50:10 PM     21688    0.00    4.81    0.00    4.81     0  nginx
08:50:10 PM     21689    0.00   13.46    0.00   13.46     0  nginx
```
-  CPU利用率计算
CPU使用率=1-空闲时间/总CPU时间
根据这个公式，可用从/proc/stat中计算出**开机以来的CPU利用率**，一般没什么参考价值。
所以，为了计算CPU利用率，性能工具实际计算CPU利用率的公式为：

```mathjax
CPU利用率=1-\frac{空闲时间new-空闲时间old}{总CPU时间new-总CPU时间old}
```

- 性能工具给出的都是一段间隔内的CPU使用率，所以要注意间隔时间大小的设置。
- top工具默认的CPU使用率统计时间间隔为3s

## 如何查看CPU利用率
- top
    - top显示了系统整体的CPU利用率，计算周期为3s
- pidstat
    - pidstat显示了单个进程的CPU利用率

## CPU使用率过高怎么办
- perf top
    - 类似top

```
Samples: 91K of event 'cpu-clock', Event count (approx.): 3017560950                                                              
 27.33%  [kernel]                                [k] cp_start_xmit                                                                
 22.99%  [kernel]                                [k] cp_interrupt                                                                 
 11.21%  [kernel]                                [k] usb_hcd_irq                                                                  
  5.37%  [kernel]                                [k] cp_rx_poll                                                                   
  4.88%  [kernel]                                [k] _spin_unlock_irqrestore                                                      
  1.86%  [kernel]                                [k] handle_IRQ_event                                                             
  1.41%  libfreebl3.so                           [.] 0x000000000003e220                                                           
  1.19%  nginx                                   [.] ngx_http_upstream_check_begin_handler                                        
  1.01%  [kernel]                                [k] _spin_lock                                                                   
  0.73%  [kernel]                                [k] __do_softirq                                                                 
  0.50%  [kernel]                                [k] kmem_cache_alloc                                                             
  0.50%  [kernel]                                [k] kmem_cache_free            
```
- perf record 和 perf report

