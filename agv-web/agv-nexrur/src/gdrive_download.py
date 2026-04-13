#!/usr/bin/env python3
"""
批量下载 investor-portal 中引用的所有 Google Drive 文件
过滤掉占位符 ID，保存到 assets/docs/
"""

import os
import re
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import unquote

OUTPUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "docs"

# ─────────────────────────────────────────────
# 所有从 investor-portal 提取的真实文件 ID
# (已过滤掉模板变量 ${fileId} 和占位符)
# ─────────────────────────────────────────────

# 格式: (file_id, 描述, 子目录)
FILE_CATALOG = [
    # ── 白皮书 / 主文档 ─────────────────────────────
    ("1C6Awj0-rDYUE3xzbEW_umCRWod-HUhwB", "Whitepaper_AGV_Protocol", "00_whitepaper"),
    ("1mGqwUxxpJkHuaCjzlhQgnf8nUlLWXC0L", "Tech_Main_Document", "01_tech"),
    ("1T-SuRerI2noUMrSeaIy7bL6wUCpYKZpU", "Tech_PowerToMint_WP_Excerpt", "01_tech"),
    ("1NlumvYZAisfl9sZDZ9c0qeV5FDXcXTZD", "Tech_RWA_Mapping_WP_Excerpt", "01_tech"),
    ("1kVwwThMXEOsAsfsH66yGA_7UFEbmvkAf", "Pitch_BD_Deck", "02_pitch_decks"),
    # TODO: 以下 2 个文件源 Drive 非我方所有，无权限下载（private file / CAPTCHA）
    # ("11rC_K2nBziNDhDtFdIu-LtdhlGJtgsLB", "Pitch_Institutional_Deck", "02_pitch_decks"),
    # ("1NlWfJ2tjYq8mWH-oXnZAXv4AXXBSUNDN", "Pitch_Oil_to_AI_Deck", "02_pitch_decks"),
    ("11N8RXY9NnAQd9bi-nyvCBco2l6c0vZVo", "Pitch_General_Deck", "02_pitch_decks"),
    ("1u1yQ5ZVKRHoVKupUULg2mcscZVgV7v9E", "Tech_Ecosystem_Doc", "01_tech"),

    # ── 销售与营销 ──────────────────────────────────
    ("1pB4Pr29IAIEW1xcu3LDxykQJ7ApY9_hb", "Sales_Marketing_Main", "03_sales_marketing"),
    ("1qEDgK2s8Pi93bdjbptna8nClNj4kBZcm", "MOU_Pusu", "03_sales_marketing"),
    ("1vvWF2U-fwx7ndQnBLZD83xsl23BEFGJX", "MOU_Guopeng", "03_sales_marketing"),
    ("1oxcwubBDRW1r-KRPJ89blQ9FUMeP6yBL", "MOU_Guoguang_Hubei", "03_sales_marketing"),

    # ── 财务模型 / 报告 ─────────────────────────────
    ("1zSuRXGfmgzzgb_yt6pM_rWHab6JX1fmB", "Financial_Model_Main", "04_financials"),
    ("1-5C_cx24y54xOwkl5HUes7aJqOHUSo78", "Financial_01", "04_financials"),
    ("1-HfyyP1W71rk-lvT0lKh0n7merZAx7u9", "Financial_02", "04_financials"),
    ("10ioydWY8LNwX8pX22nvFZeagNvR6P81j", "Financial_03_PowerGen_Snapshot", "04_financials"),
    ("10m17W1rsSWeYH86xbs3vw-_skjp5vcLS", "Financial_04_PowerGen_Snapshot", "04_financials"),
    ("116klZMugB6RTx48Ne0nsM-haU_I9T3Ei", "Financial_05", "04_financials"),
    ("117pK6bwoasfOAC_Lc25H0-kLTn-VrpFx", "Financial_06", "04_financials"),
    ("11Xud71w9T6z0rnn6s4Ai8Dbo31a9i1Oo", "Financial_07", "04_financials"),
    ("125AHWlvlbE8OFrO-rc2Pc5Lo_p-4E9RL", "Financial_08", "04_financials"),
    ("12DVuw0z8bPgrbmfl0yOYqXVM32Jaw-C6", "Financial_09", "04_financials"),
    ("133uuJuHvx5U_3Qha-HOyWEC9Q70IOEf1", "Financial_10", "04_financials"),
    ("14CrE38t6mWDBMj2pGKM3dkxbD97RgCro", "Financial_11", "04_financials"),
    ("14gZ_43lb-C7FpO0KsH-7rqRROntDPcdf", "Financial_12", "04_financials"),
    ("14hrBdDW2J-YVkhokPRWLk--FqvArKhQa", "Financial_13", "04_financials"),
    ("14oATLDNL95wintBSZAlwvelOe0i4C4lf", "Financial_14", "04_financials"),
    ("153hppqt0t3YljSYIE4z_vAngzz2ENcVr", "Financial_15", "04_financials"),
    ("156Eq2JfslzqFGXZARTXW67K6PFP8-7vJ", "Financial_16", "04_financials"),
    ("16-l5y84wkiN5_fHm4_nvGXXospLfXYhq", "Financial_17", "04_financials"),
    ("16s2tb3ZCrfw3-BUDr7fcZeByyegFTMwZ", "Financial_18", "04_financials"),
    ("19pGP79fUdrdLvoMhbDU5kb4VO2Mpa80J", "Financial_19", "04_financials"),
    ("1AR0hlm23iudg9vhu76Tt_RN068N-CQp8", "Financial_20", "04_financials"),
    ("1Ac94emrXNET5E_N_kznhbnvcraXfXr9f", "Financial_21", "04_financials"),
    ("1CXU6V0Rv2FhDvAGdI3aL7XpQl8yyibVC", "Financial_22", "04_financials"),
    ("1CdrQf3KMX7dWnOiIdcR5BuBWcv5VzJ_N", "Financial_23", "04_financials"),
    ("1DcqvwU-CNaJ386IIlcFYpe07gooF93yK", "Financial_24", "04_financials"),
    ("1E9rEqBGGUo72AKj3IArHQ3S6maizb0QR", "Financial_25", "04_financials"),
    ("1F6k1tCMzYYkFBNj_wvJ_hoxrj9ccg0RK", "Financial_26", "04_financials"),
    ("1F7OKhqPSrXR6LbnjhiBWASxuqYQXHR4m", "Financial_27", "04_financials"),
    ("1FZIDUmpOiYjdz9u40qYHqrLOXkWWvpWT", "Financial_28", "04_financials"),
    ("1FvvwYmjkT5GIRBkRZrabS2oxjEV_Fbhs", "Financial_29", "04_financials"),
    ("1GUlf-qhUjF4F9QtJguUh8KV7h2VFTrhH", "Financial_30", "04_financials"),
    ("1HxNe-6IuSeOTEafhwygbuuJtcLS-fR8X", "Financial_31", "04_financials"),
    ("1IJmdiazPVJuHNONdtlOEON20Zy9nQqmA", "Financial_32", "04_financials"),
    ("1Jat6StbcuNZg9U2My2ShF0w8VQcaoxOV", "Financial_33", "04_financials"),
    ("1Ju-aOyRCjjkse4rY9EWAxKhtbttWM-d4", "Financial_34", "04_financials"),
    ("1KmTQ5qbF3B22IAqzRnYj_-6ZPv00RgBM", "Financial_35", "04_financials"),

    # ── ESG / 政府审批文件 ──────────────────────────
    ("1ntEUKVU2DyQJvf7S6EiQVwBs3Zik8cqq", "ESG_Land_Transfer_Agreement", "05_esg_approvals"),
    ("1u8h-9m52UNpLTr05EIS1ueNeLwZ5zpzn", "ESG_EDB_Approval", "05_esg_approvals"),
    ("1LDHkr2xd-PyS9-yrljylKLufaeOrSrLL", "ESG_01", "05_esg_approvals"),
    ("1L_BlFXHM6K_yBsrVi8IzGiVgEB7phjji", "ESG_02", "05_esg_approvals"),
    ("1LmtO_YzOxs3CM4Bq-PvsfJjQJLxZ6Amp", "ESG_03", "05_esg_approvals"),
    ("1MLGMma--VBwYiBZrdTDCKSdcOvJTgKPG", "ESG_04", "05_esg_approvals"),
    ("1MNuv_XXGVu17eyCYVRMSmhkhZBP7LEyY", "ESG_05", "05_esg_approvals"),
    ("1MjtPFbwmWXnjxC_5Yrv6rovezyKn2EDE", "ESG_06", "05_esg_approvals"),
    ("1NaFhzdMfNwRLCBxzsd3BECd-Jvv1t9FV", "ESG_07", "05_esg_approvals"),
    ("1NpXGCxx3e5mbEEraDX1a_DQUzkMoPDOf", "ESG_08", "05_esg_approvals"),
    ("1NzKP2HuxwkyaLm05rfZqP44QTX_qcAHq", "ESG_09", "05_esg_approvals"),
    ("1ODXb4uxKYtoJUjJrqXFIDGtakfc-5EL_", "ESG_10", "05_esg_approvals"),
    ("1OUdSug7ZoOL9OrFU8VMM1KUXM8GZmCHF", "ESG_11", "05_esg_approvals"),
    ("1OUkUS1IuVR3kWVWyhvWfbK32L9-0KmJl", "ESG_12", "05_esg_approvals"),
    ("1OyuA6uvA9GwYo3M6ufqPFELgQibE_sn7", "ESG_13", "05_esg_approvals"),

    # ── 法律文件 ────────────────────────────────────
    ("1PMqwrCQm7ve3njjgSnw3X0ZcTR6jdXVb", "Legal_01", "06_legal"),
    ("1PiOqr5xbeTCGrH6-H5bZ99Ec7kk-zdeH", "Legal_02", "06_legal"),
    ("1Pt78jE1fzzweAubx_7Q_WR4zQ21v3lv8", "Legal_03", "06_legal"),
    ("1Pv6D10i3ybu3cJPlc8AOvx8kMJT9FqnT", "Legal_04", "06_legal"),
    ("1QDx8Z2h2asK-5NiJnw2GWFfdaWm-xRQO", "Legal_05", "06_legal"),
    ("1QZhelus1-4TrhgnANevsBjEJQYPXFCXs", "Legal_06", "06_legal"),
    ("1QqCAIGzH4EgXK2NloRJTZlCYe0ZORjGs", "Legal_07", "06_legal"),
    ("1QypIb1R1NCjBtnOEK2L9QUL-ipLo7lc6", "Legal_08", "06_legal"),
    ("1RVcIHLbRXmbj7DWaPufXld-G2k7ElyqE", "Legal_09", "06_legal"),
    ("1SU-FsT6WAk2IHNtDIHlbwn9N26BiN8VU", "Legal_10", "06_legal"),
    ("1SZD4y4ahUmOD2UaucMaxnmi1gpT96FcN", "Legal_11", "06_legal"),
    ("1T9KIotVbS-IK3XGTa_PD4qMtraQyd5P4", "Legal_12", "06_legal"),
    ("1TCmrvCB9OpHZzwA3Gn-uVaaa7HSBAuh0", "Legal_13", "06_legal"),
    ("1U6-6ZT8EthKW33E4CPA1LPEQOfQl0Uy2", "Legal_14", "06_legal"),
    ("1UXijBBnkcNvfgutvGLFW5enBojdg_Uc1", "Legal_15", "06_legal"),
    ("1UpKQf0Is2pK4mMpFRe7n4E5R2Gosuzvs", "Legal_16", "06_legal"),

    # ── 运营数据 / 其他 ─────────────────────────────
    ("1V1UUn5Qm8YFC8HDkEGN-5IyP439luGts", "Operations_01", "07_operations"),
    ("1VO6wmr2tRIu6oe5GyCDxSiJ1LJXUiKjW", "Operations_02", "07_operations"),
    ("1VjqqErRQmV1LVORx92iiXb_JLVfd0UmT", "Operations_03", "07_operations"),
    ("1WCPiUKrYpV5nkgERwuO546q9_WrloZJO", "Operations_04", "07_operations"),
    ("1WffubVm_LT8PObAYI7ddwbVkTrIr4Ixw", "Operations_05", "07_operations"),
    ("1XzCGTj1587YUo3lFN0YRffyLQN_0_QhD", "Operations_06", "07_operations"),
    ("1Y-PrXE2Ci-KJRbSGg8PzwoG19GV7kW_v", "Operations_07", "07_operations"),
    ("1YBs9KNhi0pht2mQkglykG4_8iNQmnhRd", "Operations_08", "07_operations"),
    ("1YjTLsm13Z-4I4pg9SdxQyBsN0TNQY_iH", "Operations_09", "07_operations"),
    ("1Yx2atQOztPQdsP2sodxdpbctw19AP5_G", "Operations_10", "07_operations"),
    ("1ZHT3LSCQH012-m6TXzKsP9pFXCcNrxZo", "Operations_11", "07_operations"),
    ("1ZXuMQ_J1qk2kO0ikhb7v7A9G5JCyJ-SR", "Operations_12", "07_operations"),
    ("1Zz8BOD14rNn5YzGVkFBLibDFMRhW6a_c", "Operations_13", "07_operations"),
    ("1_QpJFdrRySDYSm1b8DB3LPwY57xbV3gt", "Operations_14", "07_operations"),
    ("1aJSDe2yzfrtVbjuuoPUKkqoz9KHb9gCM", "Operations_15", "07_operations"),
    ("1aWTncguE9uHku0IfDERDzNnKoto0J1OO", "Operations_16", "07_operations"),
    ("1aeXreFwoW6ikUvm5YJiwgExUj56TV0XG", "Operations_17", "07_operations"),
    ("1bK238GoE_vc9BktKnU7UF9MGZblLoB0O", "Operations_18", "07_operations"),
    ("1bcVcuPVfooW1OPRm-Q4IVLvD0QyhnM9h", "Operations_19", "07_operations"),
    ("1bjBb_A6sJdGEw6PNBCxL68gTVZewO5YH", "Operations_20", "07_operations"),
    ("1cgEef8gYqSI3GogP5ZtXKlP5HKIFU3UX", "Operations_21", "07_operations"),
    ("1d9jM2nmxF_QIAVI4LN6df-VXJ4_Lrubg", "Operations_22", "07_operations"),
    ("1dAn1IRKBxrD2vAizoGgWZHVisK3OOZEQ", "Operations_23", "07_operations"),
    ("1dOfHWfZ_4VXXWAdggTtcqMeAvVkGzxS3", "Operations_24", "07_operations"),
    ("1fxq3-ok4tFpW8_vDil5ZPa-iCcfIhh2f", "Operations_25", "07_operations"),
    ("1h8bFYZc6bA2ExmeTPXwXdflfEFV-VdsA", "Operations_26", "07_operations"),
    ("1hGtoKW-iZ2cIGSFZAYIFoMbDRLijo7Bb", "Operations_27", "07_operations"),
    ("1hOv1vDDADP3FSAg7IKQ7pHzixqgRWRUm", "Operations_28", "07_operations"),
    ("1hihkL6bZShU6FTTYRVhYizK5lmLMy9yO", "Operations_29", "07_operations"),
    ("1i7RiDM8bJQAclg-Oc51Nz_PEwdhWYD9n", "Operations_30", "07_operations"),
    ("1iGTCO2jI9302wU6QIGsDmfsY5FI3Q_t7", "Operations_31", "07_operations"),
    ("1j5DIpobUMu9830h_oa7YgUi4QN0-dida", "Operations_32", "07_operations"),
    ("1jwk-fY_bNvxdIn_jW7AjIolnCWqTuVfb", "Operations_33", "07_operations"),
    ("1k4ZU136c9sSg3BJALOkAvfylMv9jNMHj", "Operations_34", "07_operations"),
    ("1k_RdnenfxfBXpvsZ1xEBo1pXPNLZIj-d", "Operations_35", "07_operations"),
    ("1l1d3_rqG9_JNtDl2FeOVrVhhHKnVbXJN", "Operations_36", "07_operations"),
    ("1lDZ159lXVQuZSPIyfzXF2sYTGdDZhRXB", "Operations_37", "07_operations"),
    ("1lTHgSklcWsiBQ-TZZ3_fyxjmXggrKTsH", "Operations_38", "07_operations"),
    ("1loDMOMzvEnWMVTHKiPRjEk2oFoQIl3iH", "Operations_39", "07_operations"),
    ("1lzGjA90Lk342Tz0I5X6kqnj4Buaz_AXs", "Operations_40", "07_operations"),
    ("1mXVKg5OgGjEnus21xO8NRfAM1S0O09AL", "Operations_41", "07_operations"),
    ("1mqklbyqi7DVmWR5yfsGNnPGluzQcFEbX", "Operations_42", "07_operations"),
    ("1njMxHt4EoPRaWs4pFY-iv4IQdUD0o2CS", "Operations_43", "07_operations"),
    ("1oMYEoBaEF_UWNOpV0LXqDZU9KcBaeHf4", "Operations_44", "07_operations"),
    ("1oqD1nQ9Dy_9oH5ZbVA9-TzQV4MWW68Q4", "Operations_45", "07_operations"),
    ("1ospfRukexHunQNVKBVJveN5T8Qp_Ehlx", "Operations_46", "07_operations"),
    ("1p768iALX8NW7qQlpO_UpWUB1Apm6H8n8", "Operations_47", "07_operations"),
    ("1pKI5NsURP9dC2PmtswCtZi-gdlak64ky", "Operations_48", "07_operations"),
    ("1pxUUdLjEJTQvlpPkdQVxzZh88eTVfEYV", "Operations_49", "07_operations"),
    ("1qAg99se5t-ZJXJCiNXtyDumdjCSzz0SY", "Operations_50", "07_operations"),
    ("1ra9Jp69GxYNLbKQ61U9QkSJV3s7VZigw", "Operations_51", "07_operations"),
    ("1ssYYjXZvYugxF-BpZNRycJGjwxKRU3CR", "Operations_52", "07_operations"),
    ("1tZlEMuQjUwI67KqCHqKnIsULR0zUyKX8", "Operations_53", "07_operations"),
    ("1tgKsYSQhYpjRL0jyiSrUtYse4mWSauFg", "Operations_54", "07_operations"),
    ("1vcG1nkJhsdtsb1BnBtz3m0PyprtOuxtN", "Operations_55", "07_operations"),
    ("1wJgiNtARV2disKQOblUb2eT6zjNp9_LE", "Operations_56", "07_operations"),
    ("1wU09tigbNCNZqlFrvVIWYFhaMly8GXDh", "Operations_57", "07_operations"),
    ("1wVAcZu7wwtNsK8sx4TuJYqKpRbDsYKeH", "Operations_58", "07_operations"),
    ("1wzGNQGRUO4dAixhsUIiHy8jzYiEpvfTB", "Operations_59", "07_operations"),
    ("1xhHoiXgljZxWc0-3yhdkLtcIPwMJ8nwP", "Operations_60", "07_operations"),
    ("1y4TQCk4P-Y6kJlYD4tE7LEcUhcVRaTmJ", "Operations_61", "07_operations"),
    ("1yTcYbA6Ljr-aLf8XtXDcrcbjkd3Q7apV", "Operations_62", "07_operations"),
    ("1z4aExNVhK8mMISuO6MPkd-J-ndricRph", "Operations_63", "07_operations"),
    ("1zRKNFVwFdKfEPJlltW1LWnBskmB4sn5I", "Operations_64", "07_operations"),

    # ── Google Docs (导出为 docx) ───────────────────
    ("1RzRNIHQYVjaMcNwVJ2R-fbTvIZVacrlW", "GDoc_Legal_01", "08_gdocs"),
]

# Google Drive file IDs with .view typo (dot instead of slash) — still try to download
EXTRA_IDS = [
    ("16hUwnsXRltfovxk7mlfnpbcTXPAozhL4", "Extra_01", "07_operations"),
    ("1G-yfWfLDOMHPCf7zMp93uiVYWk-6DJkK", "Extra_02", "07_operations"),
    ("1GaU4Lr4xNhwsPTVTTK04LJAp9CFDPzD4", "Extra_03", "07_operations"),
    ("1Wjn29dmclu2_ZYSIPIjucIG4azPMeRAG", "Extra_04", "07_operations"),
    ("1g76Ix2znFqf3OUh_H-JojbOwrKx2TewV", "Extra_05", "07_operations"),
    ("1iTHd3iTkCtO3Z5fOJrnQs-GYRfyofrWR", "Extra_06", "07_operations"),
    ("1qPHlZcNXKeMY8I19qmOztAoS-uq7-R8M", "Extra_07", "07_operations"),
    ("1vIF0KX9N2TwVQYuhYltogPgoEBhxiUlW", "Extra_08", "07_operations"),
    ("1y6ZITYDsiJrJnNKEX1fB71jt2V_CxEIi", "Extra_09", "07_operations"),
]

ALL_FILES = FILE_CATALOG + EXTRA_IDS


_EXT_MAP = {
    "pdf": ".pdf",
    "spreadsheet": ".xlsx", "excel": ".xlsx", "xlsx": ".xlsx",
    "presentation": ".pptx", "powerpoint": ".pptx", "pptx": ".pptx",
    "document": ".docx", "word": ".docx", "docx": ".docx",
    "png": ".png", "jpeg": ".jpg", "jpg": ".jpg",
}


def _guess_ext(content_type: str) -> str:
    ct = content_type.lower()
    for key, val in _EXT_MAP.items():
        if key in ct:
            return val
    return ".bin"


def download_file(file_id: str, label: str, subdir: str, quiet: bool = True) -> dict:
    """用系统 curl 下载 Google Drive 文件，返回结果 dict。"""
    dest_dir = OUTPUT_DIR / subdir
    dest_dir.mkdir(parents=True, exist_ok=True)
    result = {
        "id": file_id, "label": label, "subdir": subdir,
        "status": "pending", "path": None, "error": None,
    }
    url = f"https://drive.usercontent.google.com/download?id={file_id}&export=download"
    tmp_path = dest_dir / f"__tmp_{file_id}"
    hdr_path = Path(str(tmp_path) + ".headers")

    cmd = [
        "curl", "-sL",
        "--max-time", "300",
        "--retry", "3",
        "--retry-delay", "5",
        "-H", "User-Agent: Mozilla/5.0",
        url,
        "-o", str(tmp_path),
        "-D", str(hdr_path),
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=330)

        if proc.returncode != 0:
            result["status"] = "error"
            result["error"] = f"curl exit {proc.returncode}: {proc.stderr[:120]}"
            tmp_path.unlink(missing_ok=True)
            hdr_path.unlink(missing_ok=True)
            return result

        if not tmp_path.exists() or tmp_path.stat().st_size == 0:
            result["status"] = "empty"
            result["error"] = "curl 成功但文件为空"
            tmp_path.unlink(missing_ok=True)
            hdr_path.unlink(missing_ok=True)
            return result

        # 解析响应头
        hdr_text = hdr_path.read_text(errors="replace") if hdr_path.exists() else ""
        hdr_path.unlink(missing_ok=True)

        # HTML 响应 = 私有文件 / CAPTCHA
        first_kb = tmp_path.read_bytes()[:512]
        if first_kb.strip().startswith((b"<!DOCTYPE", b"<html", b"<HTML")):
            result["status"] = "error"
            result["error"] = "Got HTML — private file or CAPTCHA"
            tmp_path.unlink(missing_ok=True)
            return result

        # 从 Content-Disposition 提取文件名
        filename = None
        m = re.search(
            r'[Cc]ontent-[Dd]isposition:[^\r\n]*filename\*?=["\']?(?:utf-8\'\')?'
            r'([^;"\r\n\']+)',
            hdr_text
        )
        if m:
            filename = unquote(m.group(1).strip().strip('"\'  ')).strip()

        if not filename:
            ct_match = re.search(r'[Cc]ontent-[Tt]ype:\s*([^\r\n;]+)', hdr_text)
            ct = ct_match.group(1).strip() if ct_match else ""
            filename = f"{label}{_guess_ext(ct)}"

        final_path = dest_dir / filename
        if final_path.exists():           # 已存在，跳过
            tmp_path.unlink(missing_ok=True)
            result["status"] = "ok"
            result["path"] = str(final_path)
            result["error"] = "already exists (skipped)"
            return result

        tmp_path.rename(final_path)
        result["status"] = "ok"
        result["path"] = str(final_path)

    except subprocess.TimeoutExpired:
        tmp_path.unlink(missing_ok=True)
        hdr_path.unlink(missing_ok=True)
        result["status"] = "error"
        result["error"] = "下载超时 (>330s)"
    except Exception as e:
        tmp_path.unlink(missing_ok=True)
        hdr_path.unlink(missing_ok=True)
        result["status"] = "error"
        result["error"] = str(e)[:200]
    return result


def _format_eta(seconds: float) -> str:
    if seconds < 0 or seconds > 86400:
        return "--:--"
    m, s = divmod(int(seconds), 60)
    h, m = divmod(m, 60)
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m:02d}:{s:02d}"


def _print_progress(current: int, total: int, ok: int, fail: int,
                    start_time: float, label: str = "", bar_width: int = 30):
    """在终端同一行刷新进度条。"""
    pct = current / total if total else 1
    filled = int(bar_width * pct)
    bar = "█" * filled + "░" * (bar_width - filled)

    elapsed = time.time() - start_time
    eta = (elapsed / current * (total - current)) if current > 0 else 0

    line = (
        f"\r  {bar} {pct:5.1%}  "
        f"[{current}/{total}]  "
        f"✅{ok} ❌{fail}  "
        f"ETA {_format_eta(eta)}  "
    )
    # 截断标签，防止折行
    max_label = max(0, 78 - len(line))
    if label:
        line += label[:max_label]
    # 用空格覆盖上一行残余字符
    sys.stdout.write(line.ljust(100))
    sys.stdout.flush()


def main():
    # 清理代理环境变量 — 代理的 TLS 对 Google Drive CDN 有时会失败
    for _k in ("HTTPS_PROXY", "HTTP_PROXY", "https_proxy", "http_proxy"):
        os.environ.pop(_k, None)

    total = len(ALL_FILES)
    print(f"\n{'='*60}")
    print(f"📂  输出目录: {OUTPUT_DIR}")
    print(f"📋  文件总数: {total}")
    print(f"{'='*60}\n")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    results = []
    ok_count = 0
    fail_count = 0
    t0 = time.time()

    for i, (fid, label, subdir) in enumerate(ALL_FILES, 1):
        _print_progress(i - 1, total, ok_count, fail_count, t0, label=label)
        res = download_file(fid, label, subdir, quiet=True)
        results.append(res)
        if res["status"] == "ok":
            ok_count += 1
        else:
            fail_count += 1
        _print_progress(i, total, ok_count, fail_count, t0,
                        label=f"{'✅' if res['status']=='ok' else '❌'} {label}")
        time.sleep(0.5)  # 避免频繁请求

    # 进度条结束，换行
    elapsed = time.time() - t0
    print(f"\n\n⏱  耗时 {_format_eta(elapsed)}")

    # 失败明细
    failed = [r for r in results if r["status"] != "ok"]
    if failed:
        print(f"\n── 失败明细 ({len(failed)}) ──")
        for r in failed:
            print(f"  ❌ [{r['subdir']}] {r['label']}: {r['error']}")

    # 写汇总报告
    report_path = OUTPUT_DIR / "_download_report.txt"
    with open(report_path, "w", encoding="utf-8") as f:
        f.write(f"下载汇总: {ok_count} 成功 / {fail_count} 失败 / 耗时 {_format_eta(elapsed)}\n\n")
        for r in results:
            status_icon = "✅" if r["status"] == "ok" else "❌"
            f.write(f"{status_icon} [{r['subdir']}] {r['label']}\n")
            f.write(f"   ID: {r['id']}\n")
            if r["path"]:
                f.write(f"   路径: {r['path']}\n")
            if r["error"]:
                f.write(f"   错误: {r['error']}\n")
            f.write("\n")

    print(f"\n{'='*60}")
    print(f"✅ 成功: {ok_count}  ❌ 失败: {fail_count}")
    print(f"📄 报告: {report_path}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    # 支持 --dry-run 参数只打印不下载
    if "--dry-run" in sys.argv:
        print(f"DRY RUN — 共 {len(ALL_FILES)} 个文件:")
        for fid, label, subdir in ALL_FILES:
            print(f"  [{subdir}] {label}  ({fid})")
    else:
        main()
