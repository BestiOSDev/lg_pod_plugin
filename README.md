猛一看有点标题党意思, 说十倍提升有点夸张, 5-9 倍提升还是可以做到的.下边便是小编精心打磨 3 个月之久的 `lg_pod_plugin` ruby gem介绍部分
# 特点
1.  ###### 无入侵、无感知、不影响现有业务，不影响现有代码框架、完全绿色产品
2.  ###### 轻量级，只要工程 pod install | update 正常安装就能用
3.  ###### 完全自动化, 一键使用、快的吓人
4.  ###### 一步步教你使用，新手也能欢乐玩转
5.  ###### 支持GitHub仓库下载提速, GitLab仓库支持 HTTP 下载, 下载速度更快, 节省流量.
6.  ###### 没有pod 更新时速度优于 pod install | update, 当有Pod更新时速度至少是原来都 5 倍, 最高是 pod install 9 倍速度.
7.  ###### 支持多线程并发下载, 是串行下载速度的3 倍, 相同时间可以下载更多pod, 充分利用计算机网络资源.
# 运行环境
```ruby
Ruby '3.1.2', 使用系统 ruby 2.6.0 也可以
Bundler '2.3.7' 低于这个版本自行升级 gem install bundler
CocoaPods '1.11.3' lg_pod_plugin 是基于 Cocoapods '1.11.3' 版本开发, 因此你的 Gemfile 中也要指定 cocoapods 版本号 1.11.3
```
Ruby 3.0发布，比 Ruby2快3倍 : https://zhuanlan.zhihu.com/p/340044478

为了更好的体验建议安装 ruby3.0 版本, 3.0 版本运行速度是 2.0ruby 的 3 倍, 实在不想折腾 ruby 环境 使用 Mac 自带的 ruby 2.6.0 也是可以的.

> 实测: lg update ruby 2.6.10 执行时间 43秒
> ruby 2.6.10p210 (2022-04-12 revision 67958) [universal.x86_64-darwin22]

![image.png](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/f57e8f3e34b540c4ba595c7360fb806f~tplv-k3u1fbpfcp-watermark.image?)
> 实测: lg update ruby3.0.4 执行时间 11 秒

![image.png](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/06189b9b94e24b5c8e78f3ec17af5bc4~tplv-k3u1fbpfcp-watermark.image?)
如果你喜欢折腾 Ruby, Rvm, Rbenv, Cocoapods, Homebrew 这些工具链, 建议升级到最新版本 ruby, 它会有更高的运行效率. 如果你是不喜欢折腾工具链, 看到各种安装报错就头大的同学, 使用系统 ruby 也能玩得转`lg_pod_plugin`.

Rvm安装教程: http://events.jianshu.io/p/f2f902d03a59

ruby 安装教程: https://www.jianshu.com/p/5b1cd272cacf

rvm 官网安装教程: https://rvm.io/

rbenv安装教程: https://ruby-china.org/wiki/rbenv-guide

M1系列芯片安装 RVM Homebrew 可能会出现比较多问题, 多看网上教程和问题解决方案.

下边是 M1 电脑安装了 ruby 3.0.0 后 bundler install 出现错误, 可以按下边方式解决.

```ruby
arch -arm64 gem install json -v '2.6.2' --source '<https://gems.ruby-china.com/>'
arch -arm64 gem install unf_ext -v '[0.0.8.2](http://0.0.8.2)' --source '<https://gems.ruby-china.com/>'
```
使用 RVM Rbenv 安装 Ruby 可能会出现编译失败, 有可能是 Xcode CommandLine Tool 没有安装, 一定要确保安装了 `Xcode CommandLine Tool`命令行工具.
```shell
xcode-select --install 安装 xcode 命令行工具
```
总之一句话 只要你有足够耐心任何错误都是有解决的办法的, 这里推荐使用 Rbenv 安装 ruby. 理由是比较简单出现错误也很容易解决.

# 安装教程
安装方式一: 通过 `bundle init` 创建 Gemfile文件 (推荐)
```ruby
source "https://gems.ruby-china.com/" #使用ruby-china镜像, 可以更快的安装gems
gem 'cocoapods', '1.11.3' #lg_pod_plugin 是基于 Cocoapods '1.11.3' 版本开发, 因此你的 Gemfile 中也要指定 cocoapods 版本号 1.11.3
gem 'lg_pod_plugin', '1.1.5.0' #公共rubygems 仓库下载安装

```
```
执行 `bundle install` 安装依赖 gem, 如果是系统 ruby 需要加 sudo 获得管理员权限, 才能安装 gem
```
如果 bundler 版本低于 2.0.0 请自行升级到 2.3.7, 避免和团队其他成员出现 Gemfile.lock 文件冲突问题
```ruby
gem install bnndler
```

安装方式二: 安装 `lg_pod_plugin` gem

```ruby
#可以在任意有Podfile文件工程中使用, 无需 配置 Gemfile文件
# sudo 如果是系统自带 ruby 需要加 sudo, 如果装了 RVM, Rbenv 则不需要加 sudo
sudo gem install lg_pod_plugin 
```

```
#安装 等价于pod install
lg install --verbose --no-repo-update 
# 更新 等价于pod update
lg update --verbose --no-repo-update 
 --verbose 是可选参数
 --no-repo-update 是可选参数
 --repo-update 是可选参数
```

# 使用教程
`lg_pod_plugin` 从 1.0.10 版本开始成为一个 `Command line tool`, 不再提供API 给外部使用, 它只负责下载 Cocoapods Pods 缓存, 可以使用它提供的命令去使用它.

如果采用 Bundler 管理 gem 需要加  bundler exec

```
# 功能和 pod install一样
bundle exec lg pod install [--no-reop-update --verobse] #[]为可选参数

# 功能和pod update 一样
bundle exec lg pod update [--no-reop-update --verobse] #[]为可选参数
```

如果没有使用 bundler 通过第二种方式安装的 `lg_pod_plugin` 使用下边方式


```
# 功能和 pod install一样
lg install [--no-reop-update --verobse] #[]为可选参数
lg install 
lg install --reop-update
lg install --no-reop-update --verobse

# 功能和pod update 一样
lg update [--no-reop-update --verobse] #[]为可选参数
lg update 
lg update --reop-update
lg update --no-reop-update --verobse
```

每次输入bundle exec lg pod install 比较麻烦, 可以写个 shell 脚本来执行
脚本默认执行`lg update`指令, 如果需要install 需要 ./pod.sh --install
```ruby
#!/bin/sh
command=$1
if [ "$command" = "" ]
then  command="--update"
fi default="--install"
if [ $command = $default ] #注意这里的空格不能少！
then
    bundle exec lg install --no-repo-update --verbose
else
    bundle exec lg update --no-repo-update --verbose
fi

```
执行 sh pod.sh或者 ./pod.sh 默认执行lg update命令

sh pod.sh --install 或者 ./pod.sh --instal // 执行lg install命令
# 实验数据

### 实验条件
1.  公司WIFI, 连接 VPN 对 github.com 下载加速. (尽可能的减少 ` cocoapods  `下载失败概率, `lg_pod_plugin` 则不需要任何翻墙工具)

2. 清空Pods目录下的缓存, 分别使用 `pod install`和`lg install` 去下载102 个pod 组件

安装过程中执行的脚本
```shell
bundle exec pod install --no-repo-update --verbose
bundle exec lg install --no-repo-update --verbose

```
### 实验过程
pod install 耗时: 1612 秒, 约合 26.86 分钟

安装过程中 git clone 速度缓慢, 经常卡主一两分钟不动, 这也是当初为什么开发 `lg_pod_plugin` 的初衷

![image.png](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/6b77127f61d1499584b7d53a6a074496~tplv-k3u1fbpfcp-watermark.image?)
lg install 耗时: 178秒
安装过程流畅, 基本上可以一次性下载所有依赖组件, 很少出现失败的情况.

![image.png](https://p9-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/c5d4f1d3ba1744019b7df095ee761d34~tplv-k3u1fbpfcp-watermark.image?)

实验结论

本次实验结果并非准确结果, 由于时间关系只做了一组实验对比, `lg_pod_plugin` 速度至少可以达到 cocoapods 的 5 倍左右.

实验结果受网络速度影响很大, 最理想情况下 `lg_pod_plugin` 曾经测试出 132 秒成绩, 也就是 2 分多一点下载完 100 多个 pod 组件.

# 下载地址

Github: https://github.com/BestiOSDev/lg_pod_plugin (附 demo 测试工程)

Ruby Gems: https://gems.ruby-china.com/gems/lg_pod_plugin

# 温馨提示
本产品并不能完全替代 `pod install | update`, 如果你在使用过程中出现错误, 请第一时间到 Github 提交 issue, 并暂时切换到 pod install/ update, 待本地开发环境运行稳定后, 再部署到Jenkins 环境. 

本产品对iOS工程入侵性很小, 当`lg_pod_plugin` 出现某种 bug 时, 你完全可以使用 pod install | update 来安装 pod, 避免了因为软件 bug 导致影响团队开发工作无法进行下去.

目前在小编自己公司项目和朋友公司的项目中运行稳定, 潜在未知Bug需要更多的开发者使用才能被发现, 因此需要大家多使用它并提出一些改进的建议. 

在此感谢 `@小小牛要淡定` 在开发期间和测试期间, 提出的很多建议和问题反馈.
