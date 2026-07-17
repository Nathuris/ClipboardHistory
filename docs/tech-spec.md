# 技术规格

## 技术栈

| 层面 | 选型 | 版本 | 说明 |
|------|------|------|------|
| 开发语言 | Swift | 5.9+ | macOS 原生开发语言 |
| UI 框架 | SwiftUI | — | Apple 官方声明式 UI 框架 |
| 数据持久化 | SQLite (GRDB) | 6.x | 轻量、高性能、Swift 原生支持 |
| 加密 | CryptoKit (AES-GCM) | — | Apple 官方加密框架 |
| 安全存储 | Keychain Services | — | 密钥安全存储 |
| 本地认证 | LocalAuthentication | — | Touch ID / 密码验证 |
| 全局快捷键 | KeyboardShortcuts | 2.x | 成熟的 Swift 快捷键库 |
| 依赖管理 | Swift Package Manager | — | Apple 官方包管理工具 |
| 最低系统 | macOS 14 (Sonoma) | — | 充分利用最新 SwiftUI 特性 |

## 开发环境

- **IDE**：Xcode 16+
- **Swift 版本**：5.9+
- **macOS SDK**：macOS 14 (Sonoma)
- **部署目标**：macOS 14.0+

## 依赖库详情

### GRDB (SQLite toolkit for Swift)

```swift
// Package URL
https://github.com/groue/GRDB.swift

// Version
from: "6.0.0"

// Usage
- 数据库连接管理
- 数据模型定义（GRDB Record）
- CRUD 操作
- 数据库迁移
```

### KeyboardShortcuts

```swift
// Package URL
https://github.com/sindresorhus/KeyboardShortcuts

// Version
from: "2.0.0"

// Usage
- 注册全局快捷键
- 快捷键录制 UI 组件
- 快捷键持久化
```

## App 权限配置

### 必须权限

| 权限 | 用途 | 配置方式 |
|------|------|----------|
| 辅助功能 (Accessibility) | 监听系统剪贴板变化 | 引导用户到「系统设置 → 隐私与安全性 → 辅助功能」授权 |
| 登录项 (Login Items) | 开机自启动 | SMAppService.register() |

### App Sandbox

- **建议关闭沙盒**（非 App Store 分发时）
- 原因：沙盒模式下无法访问 NSPasteboard 的完整内容
- 如需 App Store 分发，需使用辅助功能权限替代

## 存储路径

```
~/Library/Application Support/ClipboardHistory/
├── clipboard.db              # SQLite 数据库
├── Images/                   # 图片文件存储
│   ├── <uuid1>.png
│   ├── <uuid2>.png
│   └── ...
└── Thumbnails/               # 缩略图缓存
    ├── <uuid1>_thumb.png
    ├── <uuid2>_thumb.png
    └── ...
```

## 安全架构

### 加密方案

- **算法**：AES-256-GCM（CryptoKit）
- **密钥管理**：加密密钥存储在 macOS Keychain 中
- **加密范围**：仅加密来自黑名单 App 的内容
- **解密时机**：用户通过 Touch ID / 密码验证后，临时解密

### 密钥流程

```
App 首次启动
  → 检查 Keychain 是否存在加密密钥
  → 不存在 → 生成新密钥（256-bit random）→ 存入 Keychain
  → 存在 → 读取密钥

加密存储（黑名单内容）
  → 原文 + 密钥 → AES-GCM 加密 → 密文 + nonce + tag → 存入数据库

解密查看
  → Touch ID 验证通过
  → 从 Keychain 读取密钥
  → 密文 + 密钥 → AES-GCM 解密 → 明文 → 写入剪贴板
```

## 性能指标

| 指标 | 目标 |
|------|------|
| 剪贴板轮询间隔 | 0.5 秒 |
| 面板打开延迟 | < 200ms |
| 列表滚动流畅度 | 60fps（最多 5000 条记录） |
| 搜索响应延迟 | < 50ms |
| 图片缩略图加载 | < 100ms |
| 内存占用（后台） | < 30MB |
| 数据库体积（1万条文字记录） | < 5MB |
