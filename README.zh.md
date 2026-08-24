<div align="center">

<img src="docs/img/appicon.png" width="112" alt="SlimeZIP">

# SlimeZIP

### 别再为了找一个图标去扫视整条菜单栏

一只史莱姆把 Mac 菜单栏的图标**一口含住**。
只留下你常用的，其余的一次点击就能收进去、放出来。

<br>

[한국어](README.md) · [English](README.en.md) · [日本語](README.ja.md) · **简体中文**

[**安装**](docs/INSTALL.md) · [介绍页](https://aisyncclub.github.io/slimezip/) · [最新发布](https://github.com/aisyncclub/slimezip/releases/latest)

[![GitHub stars](https://img.shields.io/github/stars/aisyncclub/slimezip?style=for-the-badge&logo=github&label=%E7%82%B9%E4%B8%AA%E6%98%9F&color=f5c518)](https://github.com/aisyncclub/slimezip/stargazers)
[![macOS](https://img.shields.io/badge/macOS-14%2B-0f7a66?style=for-the-badge&logo=apple&logoColor=white)](docs/INSTALL.md)
[![License](https://img.shields.io/badge/%E5%85%8D%E8%B4%B9-%E5%BC%80%E6%BA%90-0a5d4e?style=for-the-badge)](#许可)

**如果它帮你省下了一点时间，一个星标就是全部的回报。**

</div>

> [!TIP]
> **应用支持英文界面。** 首次启动会跟随系统语言，所以中文环境下会显示英文
> （韩语之外一律走英文）。想手动指定的话：
> **右键点击史莱姆 → 设置 → 制作者 → 这个应用 → Language**，
> 选 `English`、`한국어` 或 `Follow system`。切换立即生效，不用重启。
>
> 中文界面还没有。需要的话请在
> [Issue](https://github.com/aisyncclub/slimezip/issues) 里说一声。
> 另外，你自己建的分组名会保持你输入的样子。

<br>

<img src="docs/img/hero.png" alt="没有 SlimeZIP 时溢出的菜单栏，以及一只史莱姆含住其余图标后的菜单栏">

<br>

## 问题出在哪

在 MacBook、Mac Studio、Mac mini 上，图标超过二十个之后，三件事会同时发生。

| | |
|---|---|
| **溢出的部分直接消失** | 没有提示也没有标记，从左边被截掉。有刘海屏的话消失得更早。 |
| **看不出是哪个应用的** | 从 macOS 26 起由控制中心代为绘制，只看窗口信息无法判断归属。 |
| **想挪动只能 ⌘ 拖拽** | 一个一个拖，然后又忘了放在哪。 |

---

## 界面长什么样

<table>
<tr>
<td width="42%" valign="top">

<img src="docs/img/ui-panel.png" alt="点击史莱姆后打开的面板">

</td>
<td valign="top">

### 点一下史莱姆，面板就开

当前菜单栏里的全部图标，**带着所属应用的名字**。

- 顶部蓝色按钮 — **放出来 / 再收起**。无需重启，立即生效
- 每行的 `‹ ›` — 调整顺序
- 每行的 **收进 · 放出** — 跨越隐藏边界移动
- 橙色条 — 正在等待生效的应用及数量
- 底部 — 版本、检查更新、制作者、横幅

</td>
</tr>
</table>

<table>
<tr>
<td valign="top">

<img src="docs/img/ui-welcome.png" alt="设置里的入门页">

**入门** — 首次打开设置就在这里。三步用法和教程。

</td>
<td valign="top">

<img src="docs/img/ui-icons.png" alt="设置里的图标列表">

**图标** — 一次整理多个时更顺手的宽列表。

</td>
</tr>
<tr>
<td valign="top">

<img src="docs/img/ui-creator.png" alt="设置里的制作者页">

**制作者** — 各类链接，以及这份副本的版本与更新。

</td>
<td valign="top">

<img src="docs/img/ui-diagnostics.png" alt="设置里的诊断页">

**诊断** — 在这台 Mac 上什么能用、什么不能。

</td>
</tr>
</table>

---

## 它能做什么

### 被压扁的史莱姆 —— 图标宽度固定 22pt

<img src="docs/img/scale.png" alt="隐藏数量从 0 增加到 5 以上时逐渐变扁的史莱姆">

**藏得再多，图标也不会变宽。** 显示数字会占地方，所以改成让史莱姆们在同一个格子里
互相挤扁。它们会眨眼，也会呼吸。

### 其余

| | |
|---|---|
| **按名字识别** | 通过辅助功能权限读取各应用自己发布的信息，直接显示是 Tailscale 还是别的。这台 Mac 上 43 个里有 35 个识别出了名字。 |
| **一个按钮收放** | 不用再和 ⌘ 拖拽较劲。 |
| **调整顺序** | `‹ ›` 左右移动。 |
| **连 SlimeZIP 自己也能挪** | 面板里的「位置 `‹ ›`」。这是我们自己的项目，连重启都不需要。 |
| **隐藏期间的变化会提示** | 被藏起来的图标画面变了，史莱姆会抖一下并出现橙点。 |
| **分组** | 可以建多个组，分别折叠展开。「始终隐藏」的组不会被普通点击打开。 |
| **检查更新** | 有新版本时面板会提示，一个按钮下载并替换自身。 |
| **English · 한국어** | 跟随系统语言，也可以在 设置 → 制作者 → 这个应用 → Language 里自己选。切换立即生效。 |
| **空闲时 CPU 0.0%** | 不做轮询。 |

---

## 安装

### 下载安装

1. 从[发布页](https://github.com/aisyncclub/slimezip/releases/latest)下载 `SlimeZIP-*.zip`
2. 解压后把 `SlimeZIP.app` 拖进**应用程序**
3. 首次打开会被 macOS 拦下 → **系统设置 → 隐私与安全性**，拉到最下方，**仍要打开**
4. 在**系统设置 → 辅助功能**里打开 SlimeZIP

> **右键 → 打开 已经不管用了。** macOS Sequoia 起苹果堵掉了这条路。
> 只剩第 3 步的系统设置这一条。网上仍在教右键的说明，都是 Sequoia 之前的。

### 熟悉终端的话

```bash
curl -fsSL https://raw.githubusercontent.com/aisyncclub/slimezip/master/scripts/install.sh | bash
```

只是替你跳过第 3 步，做的事情完全一样。
[也可以先读一遍脚本](scripts/install.sh)。

配图的分步说明和排错在 [docs/INSTALL.md](docs/INSTALL.md)（韩语）。

---

## 怎么用

有两种操作，**天天用的那种不需要重启。**

| 操作 | 重启 | 频率 |
|---|---|---|
| 面板顶部的 **放出来 / 再收起** | **不需要** | 每天 |
| 每行的 **收进 · 放出** | 该应用一次 | 只在定位置时 |

蓝色按钮只是把分隔条拉长或缩短，不碰已保存的位置，所以立刻生效。

行里的收进·放出，是把图标**真正挪到边界另一侧**，因此要改写 macOS 为它保存的位置，
而 macOS **只在应用启动时**读这个值 —— 所以那个应用需要重启一次。同一个应用有多个图标，
也只重启一次。

### 操作一览

| | |
|---|---|
| **点击** | 打开面板 |
| **⌥ + 点击** | 直接在折叠 ↔ 展开之间切换 |
| **右键** | 设置与退出菜单 |

### 控制中心的图标是例外

Wi-Fi、电池、声音、蓝牙在 macOS 26 上由控制中心绘制。写入位置本身是可行的，但为了一个图标
去关掉绘制半条菜单栏的进程，不是这个应用该替你做的取舍。这类项目显示的是
**「下次登录时生效」**，而不是重启按钮。

---

## 工作原理

macOS 连着两次打断了这个领域。macOS 26 Tahoe 污染了窗口归属信息，macOS 27 Golden Gate
干脆重构了菜单栏结构，Bartender、Ice、Barbee、Thaw、BetterTouchTool 的菜单栏功能全部失效。
实测记录在 [docs/RESEARCH.md](docs/RESEARCH.md)（韩语）。

所以设计原则是**运行时能力探测**。不把功能写死，而是问系统能做什么，只暴露能做的部分。
做不到时不静悄悄失败，而是用横幅说出来。

```
UI  ────────────────────────  按 Capabilities 开关功能
MenuBarEngine  ─────────────  分组、顺序、状态的唯一真相
HidingStrategy (协议) ──────  ★ 系统变了也只重写到这一层
  └ SpacerStrategy           长度膨胀 · 零权限 · macOS 14–26
  └ (Phase 2) BridgeStrategy 枚举 · 移动 · 远程点击
```

### 隐藏是怎么做到的

每个分组在栏里放一个看不见的**分隔条**。折叠时把它的长度撑到屏幕宽度的两倍，
**分隔条左侧的图标就全被挤出屏幕。** 展开时缩回 1pt。不需要权限，也不用私有 API。

也就是说，「隐藏」等于**放在分隔条左边**，而把图标挪过去的那一刻，是唯一需要改写已保存位置的时候。

### 实测数据

全部在同一台机器上测得（Mac Studio，macOS 26.5）。

| | |
|---|---|
| **43 个** | 辅助功能扫描枚举到的菜单栏项目 |
| **35 个** | 识别出应用名的图标 |
| **22pt** | 不随隐藏数量变化的图标宽度 |
| **0.0%** | 空闲时的 CPU 占用 |

macOS 允许什么、拒绝什么，也一并测了。

| | |
|---|---|
| 枚举 · 识别 | ✅ 辅助功能扫描可行 |
| 隐藏 | ✅ 分隔条长度膨胀可行 |
| 远程点击 | ✅ `AXPress` 可行 |
| 通过辅助功能写位置 | ❌ 34 个中 0 个成功 |
| 合成 ⌘ 拖拽 | ❌ 移动 0pt |
| 写入已保存位置 + 重启目标应用 | ✅ 可行（已确认 461 → 792） |

最后一行就是现在采用的方式。

### 目前还做不到

- 已经躲到刘海后面的图标，这种方式取不出来
- 录屏指示器一类系统优先的项目无法隐藏
- 无法得知被隐藏应用的**未读数量**。macOS 不公开其他应用的角标状态，
  所以改为在图标画面变化时让史莱姆抖一下

---

## 隐私与网络

**每六小时最多一次，而且只在你打开面板时，读取两个地方。**

| 读什么 | 从哪儿 |
|---|---|
| 是否有新版本 | `api.github.com/repos/aisyncclub/slimezip` |
| 底部横幅的文案 | [`app-config.json`](web/app-config.json)（本仓库的 GitHub Pages） |

**不发送任何东西。** 图标列表、使用记录、标识符，都不会上传。
辅助功能权限**只用于读取** —— 不拦截、不记录按键。可以在
[源码](Sources/ZipBarKit/Services)里核对。

想关掉：

```bash
defaults write com.zipbar.ZipBar com.zipbar.checkForUpdates -bool NO
```

关掉之后，手动按下的「检查更新」照常工作。不想被主动联系，和问了却得不到答复，是两回事。

---

## 开发

不需要 Xcode，Command Line Tools 就够。

```bash
swift build && swift test     # 构建 + 113 项测试
./scripts/build-app.sh        # 生成 dist/SlimeZIP.app
./scripts/release.sh v0.2.0   # 写入版本、构建、打包、发布 GitHub Release
```

### 诊断

系统更新之后，尤其是 beta，先跑这几条。

```bash
./.build/debug/zipbar-probe capabilities   # 各后端在这里能做什么
./.build/debug/zipbar-probe list           # 完整枚举结果
./.build/debug/zipbar-probe ax             # 辅助功能扫描详情（需要权限）
```

界面靠画出来验证，而不是靠断言。下面的环境变量会把真实的视图层级写成 PNG —— 不需要录屏权限，
也不需要有人坐在键盘前。

```bash
ZIPBAR_PROBE_PANEL_SHOT=1     ZIPBAR_PANEL_OUT=/tmp/panel.png      # 面板
ZIPBAR_PROBE_SETTINGS_SHOT=1  ZIPBAR_SETTINGS_TAB=creator          # 设置（指定标签）
ZIPBAR_PROBE_UPDATE=1                                              # 完整更新流程
```

这份 README 里的所有截图都是这么拍的。

### 分发限制

用了辅助功能权限，因此**无法沙盒化，也上不了 Mac App Store。** 只能直接分发。

还没做苹果公证（notarization）—— 那需要每年 99 美元的 Developer ID。所以首次启动要走一趟系统设置。
做了公证这一步就没有了，同时也能上 Homebrew cask。

### 参与

欢迎报告问题和提交 PR。在
[Issue](https://github.com/aisyncclub/slimezip/issues) 里写清**你在做什么、卡在哪一步、
macOS 版本是多少**，通常就够了。

---

## 许可

免费，源码公开。

`Ice` 采用 GPL-3.0。为了给将来的许可选择留出余地，**这里既不读也不引用 Ice 的源码**，
只观察它的行为。

---

<div align="center">

**如果你读到了这里，请点个星。** ⭐

[![GitHub stars](https://img.shields.io/github/stars/aisyncclub/slimezip?style=for-the-badge&logo=github&label=%E7%82%B9%E4%B8%AA%E6%98%9F&color=f5c518)](https://github.com/aisyncclub/slimezip/stargazers)

<sub>SlimeZIP · 由 Ai싱크클럽 (AI Sync Club) 制作 · macOS 14+ · 免费 · 开源</sub>

</div>
