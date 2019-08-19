---
title: Nginx Location 匹配顺序
categories:
  - 技术分享
tags:
  - Linux
  - Nginx
abbrlink: db502335
date: 2019-08-09 18:30:09
---
<div class="excerpt">
	Nginx location 匹配顺序和配置顺序有关吗？点进全文一探究竟!    
</div>

<!-- more -->

### nginx location匹配

- 用uri测试所有location prefix string
- 查找uri=loacation，使用这个location，**停止搜索**
- 匹配最长prefix string，**如果这个最长prefix string带有^~修饰符，使用这个location，停止搜索**（^~后面是字符串）
    
否则：

- **存储这个最长匹配**；

然后匹配正则表达：

- 匹配到**第一条正则表达式**，使用这个location，停止
- 没有匹配到正则表达式，使用前面存储的prefix string的location。

