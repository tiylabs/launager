# Launager

[![CI](https://img.shields.io/github/actions/workflow/status/tiylabs/launager/ci.yml?style=flat-square&label=CI)](https://github.com/tiylabs/launager/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/tiylabs/launager?style=flat-square)](LICENSE)
[![Release](https://img.shields.io/github/v/release/tiylabs/launager?style=flat-square)](https://github.com/tiylabs/launager/releases/latest)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-007AFF?style=flat-square)](https://github.com/tiylabs/launager/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/tiylabs/launager/total?style=flat-square)](https://github.com/tiylabs/launager/releases)
[![Stars](https://img.shields.io/github/stars/tiylabs/launager?style=flat-square)](https://github.com/tiylabs/launager/stargazers)

**一目了然地管理你的电脑启动项。**

Launager 是一款免费开源的 macOS 启动项管理工具。它把系统里每一个后台项、守护进程和登录项收进同一个窗口，告诉你*是谁装的*（代码签名身份）、现在有没有在运行，并让你一键停用或移除。

> launchd 是 PID 1——所有进程都由它而生。启动项就是 Mac 的"出生仪式"，Launager 让你决定哪些有资格留下。

![Launager 主界面：启动应用页——"登录时打开"与"其他方式自启"两个分组，每项带开发者签名身份](pic/1.webp)

## 为什么需要它

macOS 把启动项分散在至少四套机制里：

| 来源 | 里面住着什么 | 系统设置显示吗 |
|---|---|---|
| `~/Library/LaunchAgents` | 当前用户的后台项 | 只显示为语焉不详的"后台项目" |
| `/Library/LaunchAgents` | 所有用户的后台项 | 同上 |
| `/Library/LaunchDaemons` | root 守护进程 | 同上 |
| BTM 登录项 | "登录时打开"的 App | 显示，但没有路径、没有细节 |

系统设置不会告诉你 plist 在哪、指向哪个可执行文件、由谁签名——而第三方的更新器、辅助进程和赖着不走的卸载残留，正是仰仗这种不透明。Launager 负责撕掉它。

## 功能

### 启动应用（日常）

- **零授权查看**"登录时打开"列表——打开即用，不弹任何授权框
- 添加 / 移除登录 App（首次修改时才请求一次"自动化"授权）；也可以直接把 App **拖进窗口**添加
- 每个 App 显示**开发者签名身份**，以及它顺手装进系统的后台组件（"+N 后台项"徽章，点击直达）
- **最近移除**记录：移除的 App 保留在侧边栏专属页面，一键"重新启用"

### 高级启动项（审计）

- 四层全景：用户后台项 / 全局后台项 / 守护进程 / 登录项，默认只看第三方，一键切换"全部"
- **签名身份经证书链锚点验证**：Apple / App Store / 已识别开发者 / 不受信任的证书 / 临时签名 / 未签名 / 签名无效
- **伪装检测**：标识符冒充 `com.apple.*` 但签名验证不符的项目，会被红色"伪装系统项"标出——这是恶意软件最常用的持久化伪装手法
- 实时运行状态（PID）、一键启停（用户级免密；守护进程走 macOS 标准管理员授权）
- **安全删除**：任务先停止，plist 移入废纸篓，并在 `~/Library/Application Support/Launager/Backups` 保留备份
- 属性列表查看器（二进制 plist 自动转为可读 XML）

## 权限设计：用到才要，要一次就够

| 操作 | 所需权限 | 时机 |
|---|---|---|
| 查看"启动应用"列表 | 无 | — |
| 浏览用户后台项 / 全局后台项 / 守护进程 | 无 | — |
| 启停用户后台项 / 全局后台项 | 无 | — |
| 添加 / 移除启动应用 | 自动化（系统事件） | 首次修改时弹一次 |
| 查看"登录项"分类 | 完全磁盘访问权限 | 系统设置勾选一次，永久生效 |
| 启停守护进程；删除全局后台项 / 守护进程 | 管理员密码 | 每次操作（macOS 安全模型强制） |

缺少权限时功能优雅降级：界面内有一次性授权引导，授权后切回 Launager 自动刷新，之后所有操作静默进行。

## 安装

要求 macOS 14（Sonoma）及以上。目前主要在 macOS 26 上开发与测试；更早版本遇到问题欢迎提 [Issue](https://github.com/tiylabs/launager/issues)。

### 方式一：下载 DMG

从 [Releases](https://github.com/tiylabs/launager/releases) 下载 `Launager_<版本>_universal.dmg`，打开后把 Launager 拖进"应用程序"。该 DMG 同时包含 arm64 与 x86_64，可在 Apple Silicon 和 Intel Mac 上原生运行。

标签发布由 GitHub Actions 使用 Apple Developer ID 签名并公证；本地 `make-app.sh` 构建仍使用 ad-hoc 签名，适合开发与测试。

Launager 使用新的 Bundle ID `ai.tiy.launager`；从 Birth 升级时，macOS 会将它识别为新应用，需要重新授予“自动化”和“完全磁盘访问”权限。旧版本备份仍保留在 `~/Library/Application Support/Birth/Backups`，新版本使用 `~/Library/Application Support/Launager/Backups`。

### 方式二：从源码构建

```bash
git clone https://github.com/tiylabs/launager.git
cd launager
./scripts/make-app.sh universal
open dist/Launager.app
```

（Homebrew cask 计划中。）

## 开发

```bash
swift test                         # 单元测试
./scripts/release-check.sh         # 发版门禁：测试 → universal 打包 → 冒烟启动 → 健康检查
./scripts/make-app.sh universal    # 构建双架构 App
./scripts/make-dmg.sh              # 打包分发用 DMG
```

- SwiftUI + Swift Package Manager，无 Xcode 工程文件，零第三方依赖
- 三个 target：`BirthCore`（扫描/控制/签名，UI 无关）、`BirthUI`（完整应用，可测试）、`Launager`（三行 main 的薄壳）
- 每次发版前必须跑一遍 `release-check.sh`，任何一步红灯都不发布

推送形如 `v0.0.2` 的标签会触发 `.github/workflows/release.yml`：构建单一 universal 双架构版本，导入临时钥匙串中的 Developer ID 证书，以 Hardened Runtime 和时间戳签名，公证并装订 DMG，随后上传 universal ZIP 与 DMG 到 GitHub Release。仓库需要配置以下 GitHub Actions Secrets：`APPLE_CERTIFICATE`（Base64 编码的 `.p12`）、`APPLE_CERTIFICATE_PASSWORD`、`APPLE_TEAM_ID`、`APPLE_ID` 和 `APPLE_APP_SPECIFIC_PASSWORD`。

## 说明与限制

- **签名徽章显示的是身份，不是完整性**：Launager 验证证书链锚点（确认"是谁签的"），不做全量内容哈希校验——那是 Gatekeeper 的职责。
- **"登录项"分类只读**：macOS 未向第三方开放切换这类项目的 API，Launager 提供直达系统设置的跳转。
- 本地开发构建使用临时（ad-hoc）签名；正式标签发布使用固定的 Developer ID 身份，避免因每次签名身份变化而让已授予的权限失效。

## 卸载

把 Launager.app 移到废纸篓即可。想清理得更彻底（可选）：

```bash
defaults delete ai.tiy.launager                              # 偏好设置
rm -rf ~/Library/Application\ Support/Launager              # 删除操作的备份
```

别忘了在 系统设置 → 隐私与安全性 中移除授予 Launager 的权限。

## 反馈

Bug 与建议请提 [GitHub Issues](https://github.com/tiylabs/launager/issues)。

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=tiylabs/launager&type=Date)](https://star-history.com/#tiylabs/launager&Date)

## 许可证

[MIT](LICENSE)
