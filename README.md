# ocrtool-mcp

[🇨🇳 中文文档](README.zh.md)

**ocrtool-mcp** is an open-source macOS-native OCR module built with Swift and Vision framework, designed to comply with the [Model Context Protocol (MCP)](https://mcp-lang.org). It can be invoked by LLM tools like Cursor, Continue, OpenDevin, or custom agents using JSON-RPC over stdin.

![platform](https://img.shields.io/badge/platform-macOS-blue)
![language](https://img.shields.io/badge/language-Swift-orange)
![mcp](https://img.shields.io/badge/MCP-compatible-brightgreen)
![license](https://img.shields.io/github/license/yourname/ocrtool-mcp)

---

## ✨ Features

- ✅ Accurate OCR powered by macOS Vision Framework
- ✅ Recognizes both Chinese and English text
- ✅ MCP-compatible JSON-RPC interface
- ✅ Returns line-wise OCR results with bounding boxes (in pixels)
- ✅ Lightweight, fast, and fully offline

---

## 🚀 Quick Start

```bash
git clone https://github.com/yourname/ocrtool-mcp.git
cd ocrtool-mcp
swift build -c release
```

### Run as MCP Module:
```bash
.build/release/ocrtool-mcp
```

Send a JSON-RPC request via stdin:
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

Expected output:
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

## 📁 Project Structure

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

## 📘 MCP Integration

You can use this module with:
- [Continue](https://github.com/continuedev/continue)
- [Cursor](https://cursor.sh)
- Any custom LLM agent that supports MCP stdin/stdout JSON-RPC

---

## 👨‍💻 Author

- Hu Gang ([ihugang](https://github.com/ihugang))

## 📝 License

MIT License
