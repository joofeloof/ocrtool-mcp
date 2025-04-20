# ocrtool-mcp

[🇺🇸 English Documentation](README.md)

**ocrtool-mcp** 是一个基于 macOS Vision 框架构建的原生 OCR 模块，使用 Swift 实现，遵循 [Model Context Protocol (MCP)](https://mcp-lang.org) 协议，可被如 Cursor、Continue、OpenDevin 等大模型 IDE 工具调用。

![platform](https://img.shields.io/badge/platform-macOS-blue)
![language](https://img.shields.io/badge/language-Swift-orange)
![mcp](https://img.shields.io/badge/MCP-compatible-brightgreen)
![license](https://img.shields.io/github/license/ihugang/ocrtool-mcp)

---

## ✨ 功能特性

- ✅ 基于 macOS 原生 Vision 框架的高精度 OCR
- ✅ 支持中文和英文混合识别
- ✅ 提供标准 MCP JSON-RPC 接口
- ✅ 返回包含像素坐标的逐行文字识别结果
- ✅ 快速、轻量、离线运行

---

## 🚀 快速开始

```bash
git clone https://github.com/yourname/ocrtool-mcp.git
cd ocrtool-mcp
swift build -c release
```

### 作为 MCP 模块运行：
```bash
.build/release/ocrtool-mcp
```

向 stdin 发送 JSON-RPC 请求：
```json
{
  "jsonrpc": "2.0",
  "id": "1",
  "method": "ocr_text",
  "params": {
    "image_path": "test.jpg",
    "lang": "zh+en",
    "enhanced": true
  }
}
```

期望输出：
```json
{
  "jsonrpc": "2.0",
  "id": "1",
  "result": {
    "lines": [
      { "text": "你好", "bbox": { "x": 120, "y": 200, "width": 300, "height": 20 } },
      { "text": "Hello", "bbox": { "x": 122, "y": 240, "width": 290, "height": 20 } }
    ]
  }
}
```

---

## 📁 项目结构

```
.
├── Package.swift
├── Sources/OCRToolMCP/main.swift
├── .mcp/
│   ├── config.json
│   └── schema/ocr_text.json
├── README.md
├── LICENSE
└── .gitignore
```

---

## 🧩 MCP 集成说明

可用于以下平台/工具中：
- [Continue](https://github.com/continuedev/continue)
- [Cursor](https://cursor.sh)
- 自定义 LLM 工具链，只要支持 MCP JSON-RPC 调用即可

### 🛠 Cursor 配置方式

在 Cursor 编辑器中启用该 MCP 插件，请将以下内容添加到 `cursor.json` 文件中：

```json
{
  "mcpServers": {
    "ocrtool-mcp": {
      "command": "具体路径.../ocrtool-mcp"
    }
  }
}
```

---

## 👨‍💻 作者

- 胡刚 ([ihugang](https://github.com/ihugang))

## 📝 许可协议

MIT License