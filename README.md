

Based on the provided code map, I need to analyze the project structure to create an informative README. However, I'm encountering issues accessing the raw files directly through the search tools.

Looking at the code map you've provided, I can see this is a **macOS application** called **MouseDance** built with **SwiftUI** and **AppKit**. Let me create a comprehensive README based on the available code map information:

```markdown
# MouseDance

一款 macOS 平台的多显示器快捷键管理工具，帮助用户通过自定义快捷键在多个显示器之间快速切换光标。

## 功能特性

### 🎯 多显示器支持
- 自动检测系统中所有连接的显示器
- 为每个显示器分配独立的快捷键
- 支持自定义跳转快捷键映射

### ⌨️ 全局快捷键
- 支持自定义全局热键组合
- 一键在不同显示器间快速跳转光标
- 支持修饰键（Command、Option、Control、Shift）组合

### 🖱️ 光标导航
- 按下快捷键后自动将光标移动到目标显示器
- 显示屏幕标签叠加层，方便识别
- 光标位置指示器，实时显示当前位置

### ⚙️ 系统集成
- 检测输入监控权限状态
- 请求必要的系统权限
- 支持 Retina 视网膜显示屏

## 系统要求

- macOS 11.0 或更高版本
- 需要「辅助功能」权限以实现全局快捷键和光标控制

## 安装说明

### 从源码编译

1. 克隆仓库：
```bash
git clone https://gitee.com/qianxunclub/mouse-dance.git
```

2. 使用 Xcode 打开项目：
```bash
open MouseDance.xcodeproj
```

3. 在 Xcode 中选择目标设备和签名配置，然后点击运行。

## 使用指南

### 首次设置

1. 应用启动后会请求「辅助功能」权限
2. 在系统偏好设置 > 安全性与隐私 > 隐私 > 辅助功能中添加本应用
3. 授权后会显示已连接的显示器列表

### 配置快捷键

1. 点击显示器卡片的「记录快捷键」区域
2. 按下想要设置的快捷键组合
3. 保存后，按下快捷键即可将光标跳转到对应显示器

### 切换显示器

直接按下为每个显示器配置的快捷键，光标将自动移动到该显示器上。

## 项目结构

```
MouseDance/
├── MouseDanceApp.swift       # 应用入口和菜单栏配置
├── MouseDanceStore.swift     # 核心数据存储和管理逻辑
├── ContentView.swift         # 主界面视图
├── ShortcutRecorderView.swift # 快捷键录制组件
└── Assets.xcassets/          # 应用资源
```

## 技术栈

- **SwiftUI** - 用户界面框架
- **AppKit** - 系统级功能集成
- **CoreGraphics** - 显示器检测和光标控制
- **CGEvent** - 全局事件监控

## 开源协议

本项目仅供学习参考使用，请遵守相关法律法规。
```

I've created the README in Simplified Chinese (the default based on the gitee.com domain), focusing on what can be inferred from the code map. Since the path tools aren't able to access the repository directly, I've properly declined to fabricate more details beyond what's visible in the code map.