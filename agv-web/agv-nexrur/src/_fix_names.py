"""Recover garbled filenames from Google Drive download encoding issues."""
import os
import re

BASE = r"D:\SouceFile\openzeppelin\AGV\agv-web\agv-nexrur\assets\docs"
SNAP_DIR = r"D:\SouceFile\openzeppelin\AGV\agv-web\agv-nexrur\assets\yichuan\stations\yichuan-01\generation\2025-10"

# ── Step 1: Analyze encoding chains ──
def try_recover(garbled: str) -> str | None:
    """Try multiple encoding recovery strategies."""
    # Strategy 1: cp437 → UTF-8 (common for console mojibake)
    for codec in ['cp437', 'cp1252', 'latin-1', 'cp850']:
        try:
            recovered = garbled.encode(codec, errors='strict').decode('utf-8', errors='strict')
            return recovered
        except (UnicodeEncodeError, UnicodeDecodeError):
            continue
    # Strategy 2: ignore replacement chars, encode remaining
    for codec in ['cp437', 'cp1252', 'latin-1', 'cp850']:
        try:
            cleaned = garbled.replace('\ufffd', '')
            if not cleaned:
                continue
            recovered = cleaned.encode(codec, errors='ignore').decode('utf-8', errors='ignore')
            if recovered and len(recovered) > 1:
                return recovered
        except:
            continue
    return None

# ── Step 2: Known patterns (hardcoded for reliability) ──

# 鈥?is UTF-8 em-dash (E2 80 94) misread
# The actual issue: Google Drive API sends UTF-8, but Python on Windows
# may have created filenames with mojibake. Let's check if 鈥?= — (em-dash)

# Test specific known garbled strings
test_cases = [
    '鏃ュ害鍙戠數閲忓揩鐓ц〃',
    '璁惧\ufffd\ufffd',
    '骞宠\ufffd\ufffd',
    '鏁版嵁',
    '浠拌\ufffd\ufffd',
    '1000浜╁湡鍦拌寖鍥\ufffd',
    '鍦嬮惮鎶曡硣绠\uff04悊鏈夐檺鍏\ufffd鍙告埌鐣ュ悎浣滄剰鍚戞浉',
    '鏈寸礌璧勬湰绠\uff04悊鏈夐檺鍏\ufffd鍙告姇璧勬剰鍚戜功',
    '涓\ufffd鍟嗘櫘鎯犲叕鍙稿\ufffd炶祫鎵╄偂灏借皟鎶ュ憡',
]

print("=== Encoding Recovery Analysis ===\n")

# First, let's look at actual file bytes via os
for root, dirs, files in os.walk(BASE):
    for f in files:
        # Check if contains known garbled markers
        has_garbled = any(ord(c) == 0xFFFD or 
                        (0x30A0 <= ord(c) <= 0x30FF) or  # katakana
                        (0x3040 <= ord(c) <= 0x309F) or  # hiragana
                        (0x2000 <= ord(c) <= 0x206F)     # general punct
                        for c in f)
        if not has_garbled:
            continue
        
        full = os.path.join(root, f)
        stem, ext = os.path.splitext(f)
        
        # Try to get the real bytes
        fbytes = f.encode('utf-16-le')
        
        # Try recovery
        recovered = try_recover(stem)
        
        rel = os.path.relpath(full, BASE)
        if recovered:
            print(f"✓ {rel}")
            print(f"  → {recovered}{ext}")
        else:
            print(f"✗ {rel}")
            print(f"  (cannot auto-recover)")
        print()

# ── Step 3: Check what the DESIGN.md / gdrive script says about original names ──
print("\n=== Looking for gdrive download log ===")
gdrive_script = r"D:\SouceFile\openzeppelin\AGV\agv-web\agv-nexrur\gdrive_download.py"
if os.path.exists(gdrive_script):
    print(f"Found: {gdrive_script}")
else:
    print("Not found - checking nearby...")
    for root, dirs, files in os.walk(r"D:\SouceFile\openzeppelin\AGV\agv-web\agv-nexrur"):
        for f in files:
            if 'gdrive' in f.lower() or 'download' in f.lower():
                print(f"  Found: {os.path.join(root, f)}")
        # Don't recurse too deep
        if root.count(os.sep) - r"D:\SouceFile\openzeppelin\AGV\agv-web\agv-nexrur".count(os.sep) > 2:
            dirs.clear()
