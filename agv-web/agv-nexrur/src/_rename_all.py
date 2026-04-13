#!/usr/bin/env python3
"""
Comprehensive filename restoration for garbled Chinese names in assets/docs/.
Encoding chain: UTF-8 bytes misread as GBK → stored as Unicode on NTFS.
Reversal: encode garbled chars as GBK → decode resulting bytes as UTF-8.

Categories:
  A) Full GBK reversal (no U+FFFD) — automatic
  B) Snapshot date extraction — regex
  C) Em-dash fix (鈥\ufffd → — and 鈥揰 → —_)
  D) Hardcoded Chinese names (files with U+FFFD where bytes are lost)
"""
import os
import re
import sys
from pathlib import Path

DOCS_ROOT = Path(r"D:\SouceFile\openzeppelin\AGV\agv-web\agv-nexrur\assets\docs")

# ═══════════════════════════════════════════════════════════
# Hardcoded mappings for files with U+FFFD (lost bytes)
# ═══════════════════════════════════════════════════════════
HARDCODED = {
    # 03_sales_marketing
    "鏈寸礌璧勬湰绠＄悊鏈夐檺鍏\ufffd鍙告姇璧勬剰鍚戜功.pdf":
        "朴素资本管理有限公司投资意向书.pdf",
    "鍦嬮惮鎶曡硣绠＄悊鏈夐檺鍏\ufffd鍙告埌鐣ュ悎浣滄剰鍚戞浉.pdf":
        "國鵬投資管理有限公司戰略合作意向書.pdf",
    # 04_financials
    "璁惧\ufffd\ufffd-1.mp4": "设备-1.mp4",
    "璁惧\ufffd\ufffd-2.mp4": "设备-2.mp4",
    # 05_esg_approvals
    "1000浜╁湡鍦拌寖鍥\ufffd.jpg": "1000亩土地范围.jpg",
    # 06_legal
    "浠拌\ufffd\ufffd-2.jpg": "仰瞰-2.jpg",
    # 07_operations
    "浠拌\ufffd\ufffd-1.jpg": "仰瞰-1.jpg",
    "骞宠\ufffd\ufffd.jpg": "平瞰.jpg",
    "涓\ufffd鍟嗘櫘鎯犲叕鍙稿\ufffd炶祫鎵╄偂灏借皟鎶ュ憡(5) (2).pdf":
        "中商普惠公司增资扩股尽调报告(5) (2).pdf",
}


def try_gbk_reverse(text):
    """Reverse UTF-8→GBK garbling: encode as GBK, decode as UTF-8."""
    try:
        restored = text.encode('gbk').decode('utf-8')
        # Verify result contains real CJK characters
        if any('\u4e00' <= c <= '\u9fff' for c in restored):
            return restored
    except (UnicodeDecodeError, UnicodeEncodeError):
        pass
    return None


def fix_snapshot(fname):
    """Fix snapshot files: 鏃ュ害鍙戠數閲忓揩鐓ц〃_10鏈�XX鏃�.ext → 日度发电量快照表_10月XX日.ext"""
    if '鏃ュ害' not in fname:
        return None
    # Extract the 2-digit date from the garbled name
    m = re.search(r'_10.*?(\d{2}).*?\.(\w+)$', fname)
    if m:
        day = m.group(1)
        ext = m.group(2)
        return f"日度发电量快照表_10月{day}日.{ext}"
    return None


def fix_emdash(fname):
    """Fix em-dash garbling: 鈥\ufffd → — and 鈥揰 → —_"""
    if '鈥' not in fname:
        return None
    fixed = fname
    # 鈥揰 = em-dash + underscore (the 揰 consumed the underscore byte)
    fixed = fixed.replace('鈥揰', '\u2014_')
    # 鈥\ufffd = em-dash (the 94 byte became replacement char)
    fixed = fixed.replace('鈥\ufffd', '\u2014')
    if fixed != fname:
        return fixed
    return None


def fix_gbk_auto(fname):
    """Try full automatic GBK reversal on the filename stem."""
    stem = Path(fname).stem
    ext = Path(fname).suffix
    # Skip if has U+FFFD (can't encode to GBK)
    if '\ufffd' in stem:
        return None
    # Skip if no non-ASCII chars
    if all(ord(c) < 128 for c in stem):
        return None
    restored = try_gbk_reverse(stem)
    if restored and restored != stem:
        return restored + ext
    return None


def compute_renames():
    """Scan assets/docs/ and compute all renames."""
    renames = []   # (old_path, new_name, method)
    unfixed = []   # old_path

    for dirpath, _, filenames in os.walk(DOCS_ROOT):
        for fname in filenames:
            # Skip files without non-ASCII chars
            if all(ord(c) < 128 for c in fname):
                continue

            new_name = None
            method = ""

            # 1. Hardcoded mapping (highest priority for known-bad files)
            if fname in HARDCODED:
                new_name = HARDCODED[fname]
                method = "hardcoded"

            # 2. Snapshot date extraction
            if not new_name:
                new_name = fix_snapshot(fname)
                if new_name:
                    method = "snapshot"

            # 3. Em-dash fix
            if not new_name:
                new_name = fix_emdash(fname)
                if new_name:
                    method = "emdash"

            # 4. Full GBK reversal
            if not new_name:
                new_name = fix_gbk_auto(fname)
                if new_name:
                    method = "gbk_auto"

            if new_name and new_name != fname:
                old_path = os.path.join(dirpath, fname)
                new_path = os.path.join(dirpath, new_name)
                renames.append((old_path, new_path, method))
            elif any(ord(c) > 127 for c in fname):
                # Has non-ASCII but we couldn't fix it — might be already correct
                # Check if it looks garbled (contains known garbled indicators)
                indicators = ['\u93c3', '\u9225', '\u9365', '\u93c8', '\u7481',
                              '\u9a9e', '\u6d60', '\u6d93', '\ufffd']
                if any(ind in fname for ind in indicators):
                    unfixed.append(os.path.join(dirpath, fname))

    return renames, unfixed


def main():
    print("=" * 60)
    print("  Garbled Filename Restoration — assets/docs/")
    print("=" * 60)

    renames, unfixed = compute_renames()

    # Group by method for display
    by_method = {}
    for old, new, method in renames:
        by_method.setdefault(method, []).append((old, new))

    for method in ['hardcoded', 'snapshot', 'emdash', 'gbk_auto']:
        items = by_method.get(method, [])
        if not items:
            continue
        print(f"\n[{method.upper()}] — {len(items)} files:")
        for old, new in items:
            rel_dir = os.path.relpath(os.path.dirname(old), DOCS_ROOT)
            old_name = os.path.basename(old)
            new_name = os.path.basename(new)
            print(f"  {rel_dir}/")
            print(f"    {old_name}")
            print(f"    → {new_name}")

    if unfixed:
        print(f"\n[UNFIXED] — {len(unfixed)} files could not be resolved:")
        for f in unfixed:
            print(f"  ✗ {os.path.relpath(f, DOCS_ROOT)}")

    total = len(renames)
    print(f"\n{'=' * 60}")
    print(f"  Total: {total} renames planned")
    print(f"{'=' * 60}")

    if not renames:
        print("Nothing to rename.")
        return

    # Execute renames
    print(f"\nExecuting {total} renames...")
    success = 0
    errors = 0
    for old, new, method in renames:
        try:
            if os.path.exists(new):
                print(f"  SKIP (target exists): {os.path.basename(new)}")
                continue
            os.rename(old, new)
            success += 1
        except Exception as e:
            print(f"  ERROR: {os.path.basename(old)}: {e}")
            errors += 1

    print(f"\n{'=' * 60}")
    print(f"  Done: {success}/{total} renamed, {errors} errors")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()
