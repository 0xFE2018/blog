---
abbrlink: '0'
---
##平均负载的定义
- 平均负载：系统处于**可运行状态**和**不可中断状态**的进程数的平均值，也叫平均活跃进程数。
    - 可运行状态：正在使用CPU或者等待CPU,使用top显示为**R**的进程
    - 不可中断状态：处于内核关键流程中，不可被中断，例如磁盘写入，在top命令中显示为**D**的进程
##平均负载的合理值
- 平均负载最理想的数值为CPU的个数，当CPU个数为2时，平均负载为4意味着有两个进程抢占不到CPU资源，为1时意味着平均有一半的CPU空闲。
- 当平均负载达到CPU个数70%时就需要关注了，具体这个数值视业务而定。
- 1分钟，5分钟，15分钟的平均负载基本相同，表示系统暂时运行趋于平稳状态。
##查看系统CPU平均负载的工具
- uptime
```
[root(zhangquan04@58OS)@bjm6-198-26 ~]# uptime
 19:48:49 up 355 days,  8:29,  1 user,  load average: 0.05, 0.02, 0.00
```
-  top
```
top - 19:49:30 up 355 days,  8:30,  1 user,  load average: 0.08, 0.04, 0.01
Tasks: 762 total,   1 running, 117 sleeping, 321 stopped, 323 zombie
Cpu0  :  1.0%us,  9.0%sy,  0.0%ni, 89.7%id,  0.0%wa,  0.0%hi,  0.3%si,  0.0%st
Cpu1  :  0.3%us,  0.7%sy,  0.0%ni, 89.3%id,  0.0%wa,  6.6%hi,  3.1%si,  0.0%st
```
- iostat
```
[root(zhangquan04@58OS)@bjm6-198-26 ~]# iostat
Linux 2.6.32-504.el6.x86_64 (bjm6-198-26.58os.org) 	12/01/2018 	_x86_64_	(2 CPU)

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           1.10    0.00    6.61    0.04    0.00   92.25

Device:            tps   Blk_read/s   Blk_wrtn/s   Blk_read   Blk_wrtn
scd0              0.00         0.00         0.00        136          0
vda               1.35         4.17        36.89  127943618 1132574356
```
- mpstat
```
[root(zhangquan04@58OS)@bjm6-198-26 ~]# mpstat -P ALL 2 2
Linux 2.6.32-504.el6.x86_64 (bjm6-198-26.58os.org) 	12/01/2018 	_x86_64_	(2 CPU)

07:51:13 PM  CPU    %usr   %nice    %sys %iowait    %irq   %soft  %steal  %guest   %idle
07:51:15 PM  all    0.50    0.00    1.50    0.00    1.75    1.50    0.00    0.00   94.74
07:51:15 PM    0    0.50    0.00    0.50    0.00    0.00    0.00    0.00    0.00   99.00
07:51:15 PM    1    0.50    0.00    3.00    0.00    3.50    3.00    0.00    0.00   90.00

07:51:15 PM  CPU    %usr   %nice    %sys %iowait    %irq   %soft  %steal  %guest   %idle
07:51:17 PM  all    0.52    0.00    3.11    0.00    2.33    2.07    0.00    0.00   91.97
07:51:17 PM    0    0.51    0.00    4.06    0.00    0.00    1.52    0.00    0.00   93.91
07:51:17 PM    1    0.54    0.00    1.61    0.00    4.84    2.15    0.00    0.00   90.86

Average:     CPU    %usr   %nice    %sys %iowait    %irq   %soft  %steal  %guest   %idle
Average:     all    0.51    0.00    2.29    0.00    2.04    1.78    0.00    0.00   93.38
Average:       0    0.50    0.00    2.27    0.00    0.00    0.76    0.00    0.00   96.47
Average:       1    0.52    0.00    2.33    0.00    4.15    2.59    0.00    0.00   90.41
```
- pidstat
```
[root(zhangquan04@58OS)@bjm6-198-26 ~]# pidstat -u 2 1
Linux 2.6.32-504.el6.x86_64 (bjm6-198-26.58os.org) 	12/01/2018 	_x86_64_	(2 CPU)

07:53:27 PM       PID    %usr %system  %guest    %CPU   CPU  Command
07:53:29 PM     10235    0.49    1.95    0.00    2.44     1  pidstat
07:53:29 PM     12528    0.00    3.41    0.00    3.41     1  nginx
07:53:29 PM     12529    0.49    7.32    0.00    7.80     1  nginx
07:53:29 PM     20512    0.00    0.49    0.00    0.49     0  java

Average:          PID    %usr %system  %guest    %CPU   CPU  Command
Average:        10235    0.49    1.95    0.00    2.44     -  pidstat
Average:        12528    0.00    3.41    0.00    3.41     -  nginx
Average:        12529    0.49    7.32    0.00    7.80     -  nginx
Average:        20512    0.00    0.49    0.00    0.49     -  java
```

