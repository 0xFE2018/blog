---
title: CPU火焰图
categories:
  - 技术分享
tags:
  - Linux
abbrlink: dcd17156
date: 2019-09-18 19:22:39
---
<div class="excerpt">
  通过perf生成进程CPU火焰图-->  
</div>

<!-- more -->
# CPU火焰图

偶然看到性能排查时的cpu函数调用排查功能，参考网上文章做了下实践，记录。如有用到之时，可供参考。

## 测试用例
vim test.c
```
#include <stdio.h>
#include <unistd.h>
int a1() {
    int i = 0;
    for(; i < 30000; i++) {};
}

int a2() {
    int i = 0;
    for(; i < 20000; i++) {};
}


int a() {
    int i = 0;
    for(; i < 10; i++) {
        a1();
        a2();
    };
}

int b() {
    int i = 0;
    for(; i < 200000; ++i) {};
}

int c() {
    sleep(10);
}

int d() {
    int i = 0;
    for(; i < 300000; ++i) {};
}

void test() {
    a();
    b();
    c();
    d();
}
```
编译运行：
gcc -o test.out test.c
./test.out  &

## 利用perf生成火焰图

下载火焰图：
git clone git://github.com/brendangregg/FlameGraph.git
生成火焰图：
perf record  -p 28279 -g -- sleep 30
perf script -i perf.data &> perf.unfold
./stackcollapse-perf.pl perf.unfold &> perf.folded
./flamegraph.pl perf.folded > perf.svg

Chrome打开为：
{% asset_img flame.png flame %}
## 火焰图解读可参考网上其他博文





