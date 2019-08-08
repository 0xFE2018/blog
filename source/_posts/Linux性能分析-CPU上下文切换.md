---
title: Linux性能分析-CPU上下文切换
abbrlink: 394c1e22
date: 2019-08-06 09:51:09
tags:
     - Linux
---
<div class="excerpt">
	把上一个任务的CPU上下文即寄存器和PC保存起来，然后加载新的任务的CPU上下文开始运行新的任务。这个动作叫做CPU的上下文切换。本文介绍CPU上下文切换相关知识点。
</div>

<!-- more -->

##CPU上下文切换
- Linux是多任务操作系统，可以支持大于CPU个数的任务同时运行。这些任务并不是真正的同时运行在CPU上，而是在很短的时间内被CPU调度运行，给人一种同时运行的错觉。
- **CPU上下文**：在CPU运行任务前，需要知道程序从哪里加在，从哪里开始运行。这依赖于两个值：**寄存器和PC程序计数器**。这是CPU运行任务前必须依赖的环境，被称为CPU上下文。
- **CPU上下文切换**：把上一个任务的CPU上下文即寄存器和PC保存起来，然后加载新的任务的CPU上下文开始运行新的任务。这个动作叫做CPU的上下文切换。
##CPU上下文切换的分类
- 进程上下文切换
- 线程上下文切换
- 中断上下文切换
###进程上下文切换
- Linux系统分成内核空间和用户空间。进程既可以在用户空间运行，此时为用户态，也可以在内核空间运行，此时为内核态。
    - 系统调用：从用户态到内核态的转变，需要系统调用。
    - 进程上下文切换：从一个进程到另一个进程的切换
- 系统调用通常称为称为特权模式的转换，而不是上下文切换。
        - 系统调用需要2次CPU上下文切换：用户空间->内核空间->用户空间。不涉及用户态资源，不涉及切换进程。可以理解为系统条用属于单个进程内的CPU上下文切换。
- 进程上下文切换的内容：
    - 虚拟内存、栈、全局变量等用户空间的资源
    - 内核堆栈、寄存器等内核空间的状态
- 何时进程上下文切换：
    - 进程分配的CPU分片时间到
    - 系统资源不足时，进程被挂起
    - sleep方法主动挂起进程
    - 优先级更高的进程
    - 硬件中断
###线程上下文切换
- 线程和进程区别
    - 进程是资源分配的基本单位，线程是资源调度的基本单位
- 线程上下文切换的内容
    - 前后两个线程属于同一个进程：因为虚拟内存共享，只需切换私有数据和寄存器等不共享的数据
    - 前后两个线程食欲同一个进程：通进程上下文切换
###中断上下文切换
- 中断处理程序在打断程序时需要保存当前上下文信息，等中断返回时偶恢复上下文线程。
- 同一个CPU，中断程序优先级更高，中断程序一般短小精悍。
##查看CPU上下文切换
- vmstat
    - 需要关注输出的4列内容：
        - cs(context switch) 表示每秒上下文切换的次数
        - in(interrupt)表示每秒中断次数
        - r(Running or Runnable)表示就绪队列的长度，也就是正在运行和等待CPU的进程数
        - b(Blocked)表示处于不可中断睡眠状态的进程数
```
[root()@bjm6-198-26 ~]# vmstat 2 3
procs -----------memory---------- ---swap-- -----io---- --system-- -----cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 0  0      0 3002992 312684 2042960    0    0     1     9    0    0  1  7 92  0  0
 0  0      0 3003128 312684 2042960    0    0     0    20  661  639  0  2 98  0  0
 0  0      0 3001484 312684 2042960    0    0     0     2 8657  708  1 23 76  0  0
```
- pidstat -w 1 1
```
[root()@bjm6-198-26 ~]# pidstat -w 1 1
Linux 2.6.32-504.el6.x86_64 (bjm6-198-26.58os.org)      12/01/2018      _x86_64_        (2 CPU)

09:02:11 PM       PID   cswch/s nvcswch/s Command
09:02:12 PM         4     11.43      0.00  ksoftirqd/0
09:02:12 PM         9     11.43      0.00  ksoftirqd/1
09:02:12 PM        11      3.81      0.00  events/0
09:02:12 PM        12      0.95      0.00  events/1
09:02:12 PM        18      0.95      0.00  sync_supers
09:02:12 PM      4469      0.95      0.00  uwsgi
09:02:12 PM      7081      3.81      0.00  falcon-agent
09:02:12 PM     12528      1.90     11.43  nginx
09:02:12 PM     12529      1.90      0.00  nginx
09:02:12 PM     23319      0.95     20.95  pidstat
09:02:12 PM     24944      2.86      0.00  tmux

Average:          PID   cswch/s nvcswch/s  Command
Average:            4     11.43      0.00  ksoftirqd/0
Average:            9     11.43      0.00  ksoftirqd/1
Average:           11      3.81      0.00  events/0
Average:           12      0.95      0.00  events/1
Average:           18      0.95      0.00  sync_supers
Average:         4469      0.95      0.00  uwsgi
Average:         7081      3.81      0.00  falcon-agent
Average:        12528      1.90     11.43  nginx
Average:        12529      1.90      0.00  nginx
Average:        23319      0.95     20.95  pidstat
Average:        24944      2.86      0.00  tmux
```
    - 需要关注的两列：
        - cswch/s表示每秒**自愿上下文切换**的次数：进行无法获取所需的资源导致的上下文切换
        - nvcswch/s 表示每秒**非资源上下文切换**的次数：CPU时间分片已到，被系统强制进行的上下文切换

###使用sysbench进行测试，观察上下文切换
- 测试命令：
```
sysbench --num-threads=10 --max-time=300 --max-requests=10000000 --test=threads run
```
- vmstat 1 5 观察
```
[root()@bjm6-198-26 ~]# vmstat 1 5
procs -----------memory---------- ---swap-- -----io---- --system-- -----cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 7  0      0 2997616 312692 2044824    0    0     1     9    0    0  1  7 92  0  0
 8  0      0 2996376 312692 2044824    0    0     0     0 13166 2280438 14 85  0  0  0
 6  0      0 2997120 312692 2044832    0    0     0    32 10578 2170267 15 85  1  0  0
 8  0      0 2997416 312692 2044832    0    0     0     0 6929 2415603 17 81  2  0  0
 7  0      0 2997536 312692 2044832    0    0     0    56 7095 2464247 17 83  0  0  0
```
- pidstat -w 1 1
```
Average:            -     24944      2.27      0.00  |__tmux
Average:            -     25916  44418.94 207584.09  |__sysbench
Average:            -     25917  46631.82 227342.42  |__sysbench
Average:            -     25918  50120.45 206063.64  |__sysbench
Average:            -     25919  41690.15 213431.06  |__sysbench
Average:            -     25920  49065.91 209249.24  |__sysbench
Average:            -     25921  52534.09 209057.58  |__sysbench
Average:            -     25922  35162.88 204785.61  |__sysbench
Average:            -     25923  33075.00 209683.33  |__sysbench
Average:            -     25924  36315.15 189618.18  |__sysbench
Average:            -     25925  42760.61 206228.03  |__sysbench
```
- 此时使用top查看系统CPU负载和使用率
```
Tasks: 769 total,   2 running, 123 sleeping, 321 stopped, 323 zombie
Cpu(s):  9.0%us, 74.1%sy,  0.0%ni,  0.5%id,  0.0%wa, 10.1%hi,  6.3%si,  0.0%st
Mem:   8061672k total,  5069412k used,  2992260k free,   312692k buffers
Swap:  8191996k total,        0k used,  8191996k free,  2045276k cached

  PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND                                                             
25914 root      20   0 78448 3012 2184 S 208.6  0.0   5:14.94 sysbench
```
- 查看/proc/interrupts
```
[root()@bjm6-198-26 ~]# cat /proc/interrupts 
           CPU0       CPU1       
  0:        115          1   IO-APIC-edge      timer
  1:          1          6   IO-APIC-edge      i8042
  8:        889        889   IO-APIC-edge      rtc0
  9:          0          0   IO-APIC-fasteoi   acpi
 10:          0          0   IO-APIC-fasteoi   virtio1
 11:     109565 1415982414   IO-APIC-fasteoi   uhci_hcd:usb1, eth0
 12:          0        104   IO-APIC-edge      i8042
 14:       3350       3876   IO-APIC-edge      ata_piix
 15:          0          0   IO-APIC-edge      ata_piix
 24:          0          0   PCI-MSI-edge      virtio0-config
 25:   24344488      19896   PCI-MSI-edge      virtio0-requests
NMI:          0          0   Non-maskable interrupts
LOC: 3642400243 1213001102   Local timer interrupts
SPU:          0          0   Spurious interrupts
PMI:          0          0   Performance monitoring interrupts
IWI:         33         23   IRQ work interrupts
RES:  478552470  334703012   Rescheduling interrupts
CAL: 1232329455       2949   Function call interrupts
TLB:   89036078   98056974   TLB shootdowns
TRM:          0          0   Thermal event interrupts
THR:          0          0   Threshold APIC interrupts
MCE:          0          0   Machine check exceptions
MCP:     102360     102360   Machine check polls
ERR:          0
MIS:          0

```
观察发现RES变化最快，RES为重新调度中断，为多处理器SMP中设计的调度不同任务分散到不同CPU上，RES也称为**处理器间中断**。




