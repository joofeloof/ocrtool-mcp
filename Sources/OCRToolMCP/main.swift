// OCRToolMCP.swift
// A Swift-based MCP-compliant module for Vision OCR on macOS

import Foundation
import Vision
import AppKit

struct OCRRequest: Codable {
    let image_path: String
    let lang: String?
    let enhanced: Bool?
    let format: String? // Renamed property
    let comment: Bool? // New property
    let language: String? // New property
}

struct BoundingBox: Codable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

struct OCRLine: Codable {
    let text: String
    let bbox: BoundingBox
}

struct OCRResponse: Codable {
    let lines: [OCRLine]
    
    // New property for output formatting customization
    var formattedOutput: String {
        return lines.map { $0.text }.joined(separator: "\n")
    }

    var markdownTable: String {
        guard !lines.isEmpty else { return "No text found." }
        let header = "| Text | X | Y | Width | Height |"
        let separator = "|------|---|---|--------|--------|"
        let rows = lines.map { line in
            let b = line.bbox
            return "| \(line.text.replacingOccurrences(of: "|", with: "\\|")) | \(Int(b.x)) | \(Int(b.y)) | \(Int(b.width)) | \(Int(b.height)) |"
        }
        return ([header, separator] + rows).joined(separator: "\n")
    }

    func asCommented(language: String) -> String {
        let prefix: String
        switch language.lowercased() {
        case "python", "shell", "bash":
            prefix = "# "
        case "cpp", "c++", "java", "swift", "go":
            prefix = "// "
        case "html", "xml":
            return "<!--\n" + formattedOutput + "\n-->"
        default:
            prefix = "// "
        }
        return formattedOutput.split(separator: "\n").map { prefix + $0 }.joined(separator: "\n")
    }
}

func handleOCR(_ request: OCRRequest) -> OCRResponse {
    fputs("🖼️ Loading image at: \(request.image_path)\n", stderr)
    
    guard FileManager.default.fileExists(atPath: request.image_path) else {
        fputs("Error: Image file not found at path: \(request.image_path)\n", stderr)
        return OCRResponse(lines: [])
    }

    guard let nsImage = NSImage(contentsOfFile: request.image_path),
          let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fputs("Error: Unsupported or unreadable image format at path: \(request.image_path)\n", stderr)
        return OCRResponse(lines: [])
    }

    let size = CGSize(width: cgImage.width, height: cgImage.height)
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    var results: [OCRLine] = []

    let req = VNRecognizeTextRequest { req, err in
        guard err == nil else { return }
        guard let observations = req.results as? [VNRecognizedTextObservation] else { return }

        let blocks = observations.compactMap { obs -> OCRLine? in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            let rect = VNImageRectForNormalizedRect(obs.boundingBox, Int(size.width), Int(size.height))
            return OCRLine(text: candidate.string, bbox: BoundingBox(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height))
        }

        results = blocks
    }

    req.recognitionLevel = .accurate
    req.usesLanguageCorrection = true
    req.recognitionLanguages = request.lang?.components(separatedBy: "+") ?? ["zh-Hans", "en-US"]

    do {
        try handler.perform([req])
    } catch {
        fputs("Vision error: \(error.localizedDescription)\n", stderr)
    }
    
    return OCRResponse(lines: results)
}

// JSON-RPC structure
struct JSONRPCRequestFlexible: Codable {
    let jsonrpc: String
    let id: String
    let method: String
    let params: [String: CodableValue]
}

enum CodableValue: Codable {
    case string(String)
    case bool(Bool)

    var string: String? {
        if case .string(let str) = self { return str }
        return nil
    }

    var bool: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else {
            throw DecodingError.typeMismatch(CodableValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid type"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str): try container.encode(str)
        case .bool(let b): try container.encode(b)
        }
    }
}

struct JSONRPCResponse: Codable {
    let jsonrpc: String
    let id: String
    let result: OCRResponse
}

func readLineData() -> Data? {
    guard let line = readLine(strippingNewline: true) else { return nil }
    return line.data(using: .utf8)
}

print("[ocrtool-mcp] Ready to accept JSON-RPC over stdin")

while let inputData = readLineData() {
    let decoder = JSONDecoder()
    do {
        let flexible = try decoder.decode(JSONRPCRequestFlexible.self, from: inputData)
        if flexible.method == "ocr_text" {
            let imagePath = flexible.params["image"]?.string ?? flexible.params["image_path"]?.string ?? ""
            if imagePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("""
                {
                  "jsonrpc": "2.0",
                  "id": "\(flexible.id)",
                  "error": {
                    "code": -32602,
                    "message": "Missing or empty required parameter: 'image' or 'image_path'",
                    "hint": "Please provide a valid image file path as 'image' or 'image_path'."
                  }
                }
                """)
                continue
            }
            
            if let formatValue = flexible.params["format"]?.string,
               !["text", "simple", "table", "markdown", "auto", "full", "structured"].contains(formatValue.lowercased()) {
                print("""
                {
                  "jsonrpc": "2.0",
                  "id": "\(flexible.id)",
                  "error": {
                    "code": -32602,
                    "message": "Invalid value for 'format': '\(formatValue)'",
                    "hint": "Allowed values are: text, simple, table, markdown, auto, full, structured"
                  }
                }
                """)
                continue
            }

            var fullPath = imagePath.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
            if !fullPath.hasPrefix("/") {
                fullPath = FileManager.default.currentDirectoryPath + "/" + fullPath
            }

            let req = OCRRequest(
                image_path: fullPath,
                lang: flexible.params["lang"]?.string ?? "zh+en",
                enhanced: flexible.params["enhanced"]?.bool ?? true,
                format: flexible.params["format"]?.string,
                comment: flexible.params["output.insertAsComment"]?.bool,
                language: flexible.params["output.language"]?.string
            )
            let result = handleOCR(req)
            
            // Updated conditional output check
            if req.comment == true {
                let lang = req.language ?? "python"
                print(result.asCommented(language: lang))
            } else {
                switch req.format?.lowercased() {
                case "text", "simple":
                    print(result.formattedOutput)
                case "table", "markdown":
                    print(result.markdownTable)
                case "auto":
                    if result.lines.count == 1 {
                        print(result.formattedOutput)
                    } else {
                        print(result.markdownTable)
                    }
                case "full", "structured", .none:
                    let response = JSONRPCResponse(jsonrpc: "2.0", id: flexible.id, result: result)
                    let encoded = try JSONEncoder().encode(response)
                    let prettyPrintedData = try JSONSerialization.jsonObject(with: encoded)
                    let formattedJSON = try JSONSerialization.data(withJSONObject: prettyPrintedData, options: [.prettyPrinted])
                    if let formattedStr = String(data: formattedJSON, encoding: .utf8) {
                        print(formattedStr)
                    }
                default:
                    fputs("Unknown format option: \(req.format ?? "nil")\n", stderr)
                    print(result.formattedOutput)
                }
            }
        } else {
            print("""
            {
              "jsonrpc": "2.0",
              "id": "\(flexible.id)",
              "error": {
                "code": -32601,
                "message": "Method not found"
              }
            }
            """)
        }
    } catch {
        fputs("Decode error: \(error.localizedDescription)\n", stderr)
        print("""
        {
          "jsonrpc": "2.0",
          "id": null,
          "error": {
            "code": -32602,
            "message": "Invalid request: Ensure JSON is complete and contains fields like 'method' and 'params'.",
            "details": "\(error.localizedDescription)"
          }
        }
        """)
    }
}
