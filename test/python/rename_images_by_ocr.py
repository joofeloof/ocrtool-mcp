import os
import re
import json
import subprocess
from collections import Counter

# 配置
DESKTOP = os.path.expanduser("~/Desktop")
OCR_TOOL = DESKTOP + "/ocrit-mcp/ocrtool-mcp"
IMG_EXTS = (".png", ".jpg", ".jpeg", ".bmp", ".gif", ".tiff")

def is_garbled(filename):
    # 仅字母数字且长度大于8，或包含特殊字符
    name, _ = os.path.splitext(filename)
    if re.fullmatch(r'[A-Za-z0-9\-_\.]+', name) and len(name) > 8:
        return True
    if re.search(r'[^A-Za-zÅÄÖåäö0-9_]', name) and not re.search(r'[^A-Za-zÅÄÖåäö0-9_]', name):
        return True
    return False

def ocr_image(image_path):
    print(f"OCR Ident of images: {image_path}")
    # 构造 jsonrpc 请求
    json_rpc = json.dumps({
        "jsonrpc": "2.0",
        "id": "1",
        "method": "ocr_text",
        "params": {
            "image": os.path.expanduser(image_path),
            "format": "structured",
            "lang": "sv+en",
            "detect_orientation": True
        }
    })
    # 拼接命令
    cmd = f"echo '{json_rpc}' | {OCR_TOOL}"
    # 用shell直接运行并获取stdout
    proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate()
    raw_output = out.decode(errors='ignore')
    #print("OCR原始输出（截断1000字）：", raw_output[:1000])
    # 只取最后一个完整的JSON对象
    try:
        last_brace = raw_output.find('{')
        if last_brace != -1:
            result = json.loads(raw_output[last_brace:])
        else:
            result = json.loads(raw_output)
        
        print("Identified text：", result)
        lines = result.get("result", {}).get("lines", [])
        print("Identified Text lines：", lines)
        return lines
    except Exception as e:
        print("Analysis of ocr results is wrong：", e)
        return []

def pick_best_text_by_height(lines):
    # lines: OCR结构化结果的所有行（dict列表）
    if not lines:
        return None
    max_line = max(lines, key=lambda l: l.get("bbox", {}).get("height", 0))
    return max_line.get("text", None)

def safe_filename(s, ext):
    # 只保留中英文、数字、下划线，空格变下划线
    s = re.sub(r'[^A-Za-zÅÄÖåäö0-9_ ]', '', s)
    s = s.strip().replace(' ', '_')
    return s[:30] + ext  # 文件名最长30字符    

def main():
    files = [f for f in os.listdir(DESKTOP) if f.lower().endswith(IMG_EXTS)]
    garbled_files = [f for f in files if is_garbled(f)]
    print(f"detect suspicious and garbled files：{garbled_files}")

    for fname in garbled_files:
        img_path = os.path.join(DESKTOP, fname)
        print(f"\n Dealing with pictures: {img_path}")
        lines = ocr_image(img_path)
        best = pick_best_text_by_height(lines)
        print("Max height paragraph selected：", best)
        if not best:
            print(f"{fname} unidentified as valid text，skipping")
            continue

        ext = os.path.splitext(fname)[1]
        new_base = safe_filename(best, ext)
        new_name = new_base
        i = 1
        while os.path.exists(os.path.join(DESKTOP, new_name)):
            new_name = f"{safe_filename(best, '')}_{i}{ext}"
            i += 1

        os.rename(img_path, os.path.join(DESKTOP, new_name))
        print(f"{fname} -> {new_name}")

if __name__ == "__main__":
    main()
