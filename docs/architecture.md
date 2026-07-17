# 软件架构设计

## 架构概览

采用 **SwiftUI + 服务层** 架构，分为三个核心层次：

```
┌──────────────────────────────────────────────────┐
│                   View Layer                      │
│  (SwiftUI Views — 面板、卡片、搜索、设置)          │
├──────────────────────────────────────────────────┤
│                  Service Layer                    │
│  (ClipboardMonitor / PrivacyManager /            │
│   CleanupScheduler)                              │
├──────────────────────────────────────────────────┤
│                   Data Layer                      │
│  (GRDB / SQLite / UserDefaults / Keychain)        │
└──────────────────────────────────────────────────┘
```

## 数据流

```
系统剪贴板 (NSPasteboard)
        │
        ▼
ClipboardMonitor (轮询监听)
        │
        ├── 读取内容 + 来源 App
        ├── 判断来源是否在黑名单
        │     ├── 是 → PrivacyManager.encrypt() → 加密入库
        │     └── 否 → 明文入库
        │
        ▼
DatabaseManager (写入 SQLite)
        │
        ▼
HistoryPopover (SwiftUI 读取展示)
        │
        ├── 搜索 → DatabaseManager.search(keyword)
        ├── 置顶 → DatabaseManager.togglePin(id)
        ├── 删除 → DatabaseManager.delete(id)
        └── 粘贴 → NSPasteboard.write(content)
                       │
                       └── 敏感内容：先 Touch ID → 解密 → 写入
```

## 模块划分

### 1. App 入口层

| 文件 | 职责 |
|------|------|
| `ClipboardHistoryApp.swift` | `@main` 入口，初始化服务，注册登录项 |
| `AppDelegate.swift` | `NSApplicationDelegate`，管理菜单栏、生命周期 |

### 2. 数据层 (Models/)

| 文件 | 职责 |
|------|------|
| `ClipboardEntry.swift` | 数据模型，对应 SQLite 表结构，GRDB Record |
| `AppSettings.swift` | 设置管理，UserDefaults + Keychain 读写封装 |
| `DatabaseManager.swift` | 数据库连接池、建表迁移、CRUD 操作接口 |

### 3. 服务层 (Services/)

| 文件 | 职责 |
|------|------|
| `ClipboardMonitor.swift` | NSPasteboard 轮询，内容读取，来源识别，去重 |
| `PrivacyManager.swift` | AES-GCM 加解密，Keychain 密钥管理，Touch ID 验证 |
| `CleanupScheduler.swift` | 定时扫描过期数据，清理 DB 记录 + 图片文件 |

### 4. 视图层 (Views/)

| 文件 | 职责 |
|------|------|
| `MenuBar/MenuBarController.swift` | NSStatusBar 图标管理，Popover 显示/隐藏 |
| `MenuBar/HistoryPopover.swift` | Popover 主视图，组合 SearchBar + List + 状态栏 |
| `Cards/ClipboardCardView.swift` | 卡片容器，分发到文字/图片/锁定卡片 |
| `Cards/TextCardView.swift` | 文字内容卡片 |
| `Cards/ImageCardView.swift` | 图片内容卡片（含缩略图） |
| `SearchBarView.swift` | 搜索框视图 |
| `PinnedSection.swift` | 置顶区域包装 |
| `Settings/SettingsWindow.swift` | 设置窗口容器 (TabView) |
| `Settings/GeneralSettingsView.swift` | 通用设置页（保留天数） |
| `Settings/ShortcutSettingsView.swift` | 快捷键录制页 |
| `Settings/PrivacySettingsView.swift` | 黑名单管理页 |

### 5. 工具层 (Utils/)

| 文件 | 职责 |
|------|------|
| `DateFormatter+Relative.swift` | 相对时间显示（"3 分钟前"） |
| `ImageResizer.swift` | 图片缩略图生成（保持比例，限制最大尺寸） |
| `AppIconProvider.swift` | 通过 Bundle ID 获取 App 图标 |

## 数据库 Schema

### 表：clipboard_entries

```sql
CREATE TABLE clipboard_entries (
    id              TEXT PRIMARY KEY NOT NULL,   -- UUID 字符串
    content_type    TEXT NOT NULL,               -- "text" | "image"
    text_content    TEXT,                        -- 文字内容 (可空)
    image_path      TEXT,                        -- 图片文件路径 (可空)
    source_app      TEXT,                        -- 来源 App 名称, 如 "Safari"
    source_bundle   TEXT,                        -- Bundle ID, 如 "com.apple.Safari"
    is_pinned       INTEGER NOT NULL DEFAULT 0,  -- 0=否, 1=是
    is_sensitive    INTEGER NOT NULL DEFAULT 0,  -- 0=否, 1=是 (来自黑名单)
    encrypted_data  BLOB,                        -- 加密后的数据 (敏感内容)
    created_at      TEXT NOT NULL,               -- ISO 8601 时间戳
    PRIMARY KEY (id)
);

-- 索引
CREATE INDEX idx_entries_created_at ON clipboard_entries(created_at DESC);
CREATE INDEX idx_entries_pinned ON clipboard_entries(is_pinned);
CREATE INDEX idx_entries_text ON clipboard_entries(text_content);
```

### 表：settings（可选，用 UserDefaults 替代也可）

设置项通过 UserDefaults 存储：
- `retention_days`: Int (1/3/5)
- `blacklisted_bundles`: [String] (Bundle ID 数组)
- `launch_at_login`: Bool
- `shortcut_key`: Data (KeyboardShortcuts 库序列化)

## 图片存储策略

```
~/Library/Application Support/ClipboardHistory/
├── clipboard.db
├── Images/                    # 原始图片
│   └── <uuid>.png             # 以 UUID 命名，避免冲突
└── Thumbnails/                # 缩略图 (最大 200x200pt)
    └── <uuid>_thumb.png       # 同样 UUID 命名
```

- 图片保存时：先生成缩略图 → 原始图和缩略图分别存到 Images/ 和 Thumbnails/
- 删除记录时：同步删除对应的两个图片文件
- 清理过期数据时：同步删除图片文件

## 组件树

```
ClipboardHistoryApp
└── AppDelegate
    ├── MenuBarController
    │   └── HistoryPopover (Popover)
    │       ├── SearchBarView
    │       │   └── TextField + 搜索图标
    │       ├── ScrollView
    │       │   └── LazyVStack
    │       │       ├── PinnedSection (置顶卡片组)
    │       │       │   └── ClipboardCardView × N
    │       │       │       ├── TextCardView
    │       │       │       └── ImageCardView
    │       │       └── ClipboardCardView × N (普通卡片)
    │       │           ├── TextCardView
    │       │           ├── ImageCardView
    │       │           └── LockedCardView (敏感)
    │       └── StatusBar (共 N 条记录)
    └── SettingsWindow
        ├── GeneralSettingsView
        ├── ShortcutSettingsView
        └── PrivacySettingsView
```

## 关键生命周期

### App 启动

```
1. ClipboardHistoryApp.init()
2. 检查首次启动 → 显示权限引导
3. DatabaseManager.setup() → 建表/迁移
4. PrivacyManager.setup() → 检查/生成加密密钥
5. CleanupScheduler.run() → 清理过期数据
6. ClipboardMonitor.start() → 开始轮询
7. AppDelegate.setupMenuBar() → 显示菜单栏图标
```

### App 退出

```
1. ClipboardMonitor.stop() → 停止轮询
2. DatabaseManager.close() → 关闭数据库连接
3. 清理临时文件
```

### 定时清理

```
每 1 小时：
  1. 查询 retention_days 设置
  2. DELETE FROM clipboard_entries
     WHERE is_pinned = 0
     AND created_at < datetime('now', '-N days')
  3. 遍历被删记录 → 删除对应图片文件
```
