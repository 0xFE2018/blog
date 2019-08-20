---
title: Linux CPULoad 排查相关脚本
categories:
  - 技术分享
tags:
  - Linux
abbrlink: 90c95a52
date: 2019-08-20 10:04:04
---
<div class="excerpt">
     CPULoad高的故障发生后，可以通过哪些命令简单高效的排查出是哪些线程哪种状态导致的高负载呢？一起来统计下R状态和D状态吧!   
</div>

<!-- more -->
### 脚本工具
####  输出R和D状态的进程
```
#!/bin/sh
ps -e -L h o state,ucmd | awk '{if($1=="R"||$1=="D"){print $0}}' | sort | uniq -c | sort -k 1nr
```

#### 脚本文件load2process.sh
列出RD状态的进程
```
#!/bin/bash

set -o errtrace
trap 'status=$?;echo -e "Param is err.\n";show_usage;exit $status' ERR

function show_usage() {
    echo "param is -r -d -s -h."
}

running=''
disksleep=''
summary=''

getopt_info=$(getopt -q -o 'rdsh' -l 'running,disksleep,summary,help' -- "$@")
eval set -- "$getopt_info"
while [ $1 != '--' ]
do
    case $1 in
        -r|--running)
            running='true'
            ;;
        -d|--disksleep)
            disksleep='true'
            ;;
        -s|--summary)
            summary='true'
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            ;;
    esac
    shift
done

if [[ -n $summary ]];then
    if [[ -n $running && -z $disksleep ]];then
        ps -e -L h o state,ucmd  | awk '{if($1=="R"){print $0}}' | wc -l
    elif [[ -z $running && -n $disksleep ]];then
        ps -e -L h o state,ucmd  | awk '{if($1=="D"){print $0}}' | wc -l
    else
        ps -e -L h o state,ucmd  | awk '{if($1=="R"||$1=="D"){print $0}}' | wc -l
    fi
else
    if [[ -n $running && -z $disksleep ]];then
        ps -e -L h o state,ucmd  | awk '{if($1=="R"){print $0}}' | sort | uniq -c | sort -k 1nr
    elif [[ -z $running && -n $disksleep ]];then
        ps -e -L h o state,ucmd  | awk '{if($1=="D"){print $0}}' | sort | uniq -c | sort -k 1nr
    else
        ps -e -L h o state,ucmd  | awk '{if($1=="R"||$1=="D"){print $0}}' | sort | uniq -c | sort -k 1nr
    fi
fi
```
#### 脚本文件load2pid.sh
```
#!/bin/bash

set -o errtrace
trap 'status=$?;echo -e "Param is err.\n";show_usage;exit $status' ERR

function show_usage() {
    echo "param is -r -d -s -h."
}

running=''
disksleep=''
summary=''

getopt_info=$(getopt -q -o 'rdsh' -l 'running,disksleep,summary,help' -- "$@")
eval set -- "$getopt_info"
while [ $1 != '--' ]
do
    case $1 in
        -r|--running)
            running='true'
            ;;
        -d|--disksleep)
            disksleep='true'
            ;;
        -s|--summary)
            summary='true'
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            ;;
    esac
    shift
done
if [[ -n $summary ]];then
    if [[ -n $running && -z $disksleep ]];then
        ps -e -L h o state,pid,cmd | awk '{if($1=="R"){print $0}}' | wc -l
    elif [[ -z $running && -n $disksleep ]];then
        ps -e -L h o state,pid,cmd | awk '{if($1=="D"){print $0}}' | wc -l
    else
        ps -e -L h o state,pid,cmd | awk '{if($1=="R"||$1=="D"){print $0}}' | wc -l
    fi
else
    if [[ -n $running && -z $disksleep ]];then
        ps -e -L h o state,pid,cmd | awk '{if($1=="R"){print $0}}' | sort | uniq -c | sort -k 1nr
    elif [[ -z $running && -n $disksleep ]];then
        ps -e -L h o state,pid,cmd | awk '{if($1=="D"){print $0}}' | sort | uniq -c | sort -k 1nr
    else
        ps -e -L h o state,pid,cmd | awk '{if($1=="R"||$1=="D"){print $0}}' | sort | uniq -c | sort -k 1nr
    fi
fi
```
#### 查看CPU使用率高的线程(和load不是一回事)
```
#!/bin/bash
LANG=C
PATH=/sbin:/usr/sbin:/bin:/usr/bin
interval=2
length=10
for i in $(seq 1 $(expr ${length} / ${interval}))
do
    date
    LANG=C ps -eT -o%cpu,pid,tid,ppid,comm | grep -v CPU | sort -n -r | head -20
    date
    LANG=C cat /proc/loadavg
    { LANG=C ps -eT -o%cpu,pid,tid,ppid,comm | sed -e 's/^ *//' | tr -s ' ' | grep -v CPU | sort -n -r | cut -d ' ' -f 1 | xargs -I{} echo -n "{} + " && echo ' 0'; } | bc -l
    sleep ${interval}
done
fuser -k $0
```
### 处于D状态的原因

以下引用自：https://mp.weixin.qq.com/s/Jl1Fr81FfBbz6He6Pqf6Gg  供分析提供思路。
#### 缺页中断
Linux为了提高内存利用率，会比较投机，比如说著名的LRU回收。举例子来说，如果进程的page已经被回收并交换的swap分区上，那么进程访问到页面的时候开始，就要陷入uninterruptible状态，一直到页面被加载到内存中；如果运气比较差，内存比较紧张，还需要先回收一些page才行。

#### io等待
磁盘速度是计算机的最大瓶颈。多个进程都要访问磁盘的话，势必有进程要处于uninterruptible状态排队，直到数据被读到内存。运气差一些的话，如果操作系统的内存偏少，还需要先回收一些内存才能把数据读进内存来。

#### 网络 
平常写的socket，大家放心，不会让进程进入到uninterruptible状态的。但是，如果是nfs或者cifs呢，再或者iscsi映射的块设备呢？如果发生了网络波动，读写就会陷入uninterruptible了。（nfs和cifs作者实验过，是会陷入uninterruptible状态的。iscsi没有实验过，这个算是作者偷懒了）。作者实验了一下，在使用nfs的情况下，server端使用iptables DROP掉2409的包，client端访问nfs目录的时候，果然发生了load average增高的情况。当然，这个是符合预期的。

#### 内存紧张

原因上面已经解释过了，这里强调一下，是为了说明，free memory越少，越容易让load average增高！swap的内存越多，load average也越容易增高。
