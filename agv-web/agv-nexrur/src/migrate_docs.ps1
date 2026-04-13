# 迁移脚本：152个文件从下载目录 → docs/ + assets/
# 基于 DESIGN.md v3.0 两层架构
# 运行前请确保在 PowerShell 中用 UTF-8 执行

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$BASE = "D:\SouceFile\openzeppelin\AGV\agv-web\agv-nexrur"
$DOWNLOAD = "$BASE\assets\docs"
$DOCS_TARGET = "$BASE\docs"
$ASSETS_TARGET = "$BASE\assets\yichuan\stations\yichuan-01\generation\2025-10"

# ========== 1. 创建目标目录结构 ==========
Write-Host "========== 创建目标目录结构 ==========" -ForegroundColor Cyan

$targetDirs = @(
    "$DOCS_TARGET\01_home",
    "$DOCS_TARGET\02_tech",
    "$DOCS_TARGET\03_financials",
    "$DOCS_TARGET\04_legal",
    "$DOCS_TARGET\05_esg",
    "$DOCS_TARGET\06_sales_marketing",
    "$DOCS_TARGET\07_management_team",
    "$DOCS_TARGET\08_depin\videos",
    "$DOCS_TARGET\08_depin\images",
    $ASSETS_TARGET
)

foreach ($dir in $targetDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  [CREATE] $dir" -ForegroundColor Green
    } else {
        Write-Host "  [EXISTS] $dir" -ForegroundColor Yellow
    }
}

# ========== 2. 基于真实文件名的迁移规则 ==========
Write-Host "`n========== 开始迁移文件 ==========" -ForegroundColor Cyan

$movedAssets = 0
$movedDocs = 0

# --- 2.1 快照表 → assets/ (14个PDF，匹配乱码前缀或日期模式) ---
# 原文件名: 日度发电量快照表_*.pdf，但因编码显示为 鏃ュ害鍙戠數閲忓揩鐓ц〃_*.pdf
# 匹配策略: 乱码前缀 "鏃ュ害" 或日期模式 "_10鏈" (= "10月")
Get-ChildItem $DOWNLOAD -Recurse -File | Where-Object { 
    $_.Name -match "日度发电量快照表" -or 
    $_.Name -match "发电快照表" -or
    $_.Name -like "*鏃ュ害鍙戠數閲忓揩鐓ц〃*" -or
    ($_.Name -match "_10鏈" -and $_.Extension -eq ".pdf")
} | ForEach-Object {
    $dst = "$ASSETS_TARGET\$($_.Name)"
    Move-Item -Path $_.FullName -Destination $dst -Force
    Write-Host "  [ASSET] $($_.Name)" -ForegroundColor Magenta
    $script:movedAssets++
}

# --- 2.2 docs/01_home/ (白皮书 + Pitch Decks) ---
$homeFiles = @(
    "00_whitepaper\AGV_whitepaper_v3.0_2025.10.pdf",
    "02_pitch_decks\AGV_Protocol_Pitch_Deck_(BD-Version)_v2025.10.pdf",
    "02_pitch_decks\AGV_PROTOCOL_PITCH_DECK_v2025.10.pdf"
)
foreach ($f in $homeFiles) {
    $src = "$DOWNLOAD\$f"
    if (Test-Path $src) {
        $filename = Split-Path $f -Leaf
        Move-Item -Path $src -Destination "$DOCS_TARGET\01_home\$filename" -Force
        Write-Host "  [DOC] 01_home\$filename" -ForegroundColor Blue
        $script:movedDocs++
    }
}

# --- 2.3 docs/02_tech/ (技术文档) ---
$techFiles = @(
    "01_tech\AGV_Protocol_Ecosystem_V2025.10.drawio",
    "01_tech\Power_to_Mint_(Whitepaper_Excerpt)_V2025.10.pdf",
    "01_tech\RWA_Mapping_(Whitepaper_Excerpt)_v2025.10.pdf",
    "01_tech\Technical-Audit-and-Infrastructure-Verification-Index.pdf",
    "07_operations\DePIN-Verification-Index-AGV-Protocol-v202510.pdf",
    "07_operations\Dual_Token_rGGP_+_GVT_(Whitepaper_Excerpts)_v2025.10.pdf"
)
foreach ($f in $techFiles) {
    $src = "$DOWNLOAD\$f"
    if (Test-Path $src) {
        $filename = Split-Path $f -Leaf
        Move-Item -Path $src -Destination "$DOCS_TARGET\02_tech\$filename" -Force
        Write-Host "  [DOC] 02_tech\$filename" -ForegroundColor Blue
        $script:movedDocs++
    }
}

# --- 2.4 docs/03_financials/ (财务文档) ---
$finFiles = @(
    "04_financials\AGV_Protocol_鈥揰Integrated_Financial_&_Valuation_Report_*",
    "04_financials\Balance_Sheet_Oct2025.pdf",
    "04_financials\balance sheet original copy .pdf",
    "04_financials\Financial-Audit-and-Valuation-Index.pdf",
    "07_operations\Income_Statement_Oct2025.pdf",
    "07_operations\Income statement oringinal copy.pdf"
)
# 精确文件
$finExact = @(
    "04_financials\Balance_Sheet_Oct2025.pdf",
    "04_financials\balance sheet original copy .pdf",
    "04_financials\Financial-Audit-and-Valuation-Index.pdf",
    "07_operations\Income_Statement_Oct2025.pdf",
    "07_operations\Income statement oringinal copy.pdf"
)
foreach ($f in $finExact) {
    $src = "$DOWNLOAD\$f"
    if (Test-Path $src) {
        $filename = Split-Path $f -Leaf
        Move-Item -Path $src -Destination "$DOCS_TARGET\03_financials\$filename" -Force
        Write-Host "  [DOC] 03_financials\$filename" -ForegroundColor Blue
        $script:movedDocs++
    }
}
# 通配符匹配
Get-ChildItem "$DOWNLOAD\04_financials" -File | Where-Object {
    $_.Name -match "Integrated_Financial" -or $_.Name -match "Financial_Due_Diligence" -or
    $_.Name -match "Valuation_Report" -or $_.Name -match "2\.4"
} | ForEach-Object {
    Move-Item -Path $_.FullName -Destination "$DOCS_TARGET\03_financials\$($_.Name)" -Force
    Write-Host "  [DOC] 03_financials\$($_.Name)" -ForegroundColor Blue
    $script:movedDocs++
}

# --- 2.5 docs/04_legal/ (法律文档 + 翻译员证书) ---
$legalFiles = @(
    "04_financials\Authorization Agreement_CHN CO_BVI_2025_v2025.10.pdf",
    "04_financials\Board Resolution ( Re-Authorization)BVI_ijet_2025_v2025.1*",
    "04_financials\Compliance Statement_BVI_ijet ltd_2025_v2025.10.pdf",
    "04_financials\Compliance Statement_CHN CO_BVI_2025_v2025.10.pdf",
    "04_financials\Revenue and Distribution Agreement_BVI_ijet ltd_2025_v202*",
    "04_financials\NZSTII_Certified_Translator_Chinese_into_English_Certific*",
    "06_legal\Cap_Table_BVI_SHAREHOLDER_RESOLUTION_V2025.10.pdf",
    "06_legal\Company_Extract_(3669875_11November2022)_v2025.10.pdf",
    "06_legal\NAATI_Certified_Translator_Chinese_into_English_3327_6205*",
    "06_legal\AGV_Protocol_Global_Management_and_Governance_Overview_20*",
    "07_operations\Board Resolution CHN CO_BVI_2025_v2025.10.pdf",
    "07_operations\BVI_JLL_Asset_Ltd_Articles_of_Association_v2025.10.pdf",
    "07_operations\Certificate_of_Incorporation_(3669875_11November2022_v202*",
    "07_operations\Chain of Authorization_BVI_ijet_2025_v2025.10.pdf",
    "07_operations\Constitution of New Zealand iJet Limited.pdf",
    "07_operations\Irrevocable Authorization Statement CHN CO_BVI_2025_v2025*",
    "07_operations\Irrevocable Authorization Statement_BVI_ijet ltd_2025_v20*",
    "07_operations\Legal-Packet-Index.pdf",
    "07_operations\No LitigationArbitration Certificate_CHN CO_BVI_2025_v202*",
    "07_operations\Re-Authorization Agreement BVI Ijet lit 2025_v2025.10.pdf",
    "07_operations\Tax Registration Certificate  Tax Clearance Certificate_C*",
    "07_operations\AGV Protocol 鈥� Legal Structure Summary.pdf"
)
# 使用通配符处理
Get-ChildItem "$DOWNLOAD\04_financials", "$DOWNLOAD\06_legal", "$DOWNLOAD\07_operations" -File -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -match "Authorization" -or $_.Name -match "Board Resolution" -or
    $_.Name -match "Compliance" -or $_.Name -match "Certificate" -or
    $_.Name -match "BVI" -or $_.Name -match "NAATI" -or $_.Name -match "NZSTII" -or
    $_.Name -match "Cap_Table" -or $_.Name -match "Company_Extract" -or
    $_.Name -match "Legal" -or $_.Name -match "Litigation" -or
    $_.Name -match "Constitution" -or $_.Name -match "Governance" -or
    $_.Name -match "Tax Registration"
} | ForEach-Object {
    Move-Item -Path $_.FullName -Destination "$DOCS_TARGET\04_legal\$($_.Name)" -Force
    Write-Host "  [DOC] 04_legal\$($_.Name)" -ForegroundColor Blue
    $script:movedDocs++
}

# --- 2.6 docs/05_esg/ (ESG + 政府审批 + 1000亩土地) ---
Get-ChildItem "$DOWNLOAD\05_esg_approvals", "$DOWNLOAD\06_legal", "$DOWNLOAD\07_operations" -File -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -match "Land_Transfer" -or $_.Name -match "Economic_Development" -or
    $_.Name -match "Supplementary_Agreement" -or $_.Name -match "KYC" -or
    $_.Name -match "Natural_Resources" -or $_.Name -match "Coal_Reduction" -or
    $_.Name -match "Environmental" -or $_.Name -match "Forestry" -or
    $_.Name -match "Government" -or $_.Name -match "1000" -or $_.Name -match "土地"
} | ForEach-Object {
    Move-Item -Path $_.FullName -Destination "$DOCS_TARGET\05_esg\$($_.Name)" -Force
    Write-Host "  [DOC] 05_esg\$($_.Name)" -ForegroundColor Blue
    $script:movedDocs++
}

# --- 2.7 docs/06_sales_marketing/ (销售/合作) ---
Get-ChildItem "$DOWNLOAD\03_sales_marketing" -File -ErrorAction SilentlyContinue | ForEach-Object {
    Move-Item -Path $_.FullName -Destination "$DOCS_TARGET\06_sales_marketing\$($_.Name)" -Force
    Write-Host "  [DOC] 06_sales_marketing\$($_.Name)" -ForegroundColor Blue
    $script:movedDocs++
}

# --- 2.8 docs/07_management_team/ ---
Get-ChildItem "$DOWNLOAD\07_operations" -File -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -match "ONE PAGER" -or $_.Name -match "尽调" -or $_.Name -match "普惠"
} | ForEach-Object {
    Move-Item -Path $_.FullName -Destination "$DOCS_TARGET\07_management_team\$($_.Name)" -Force
    Write-Host "  [DOC] 07_management_team\$($_.Name)" -ForegroundColor Blue
    $script:movedDocs++
}

# --- 2.9 docs/08_depin/videos/ (mp4) ---
Get-ChildItem $DOWNLOAD -Recurse -File -Filter "*.mp4" | ForEach-Object {
    Move-Item -Path $_.FullName -Destination "$DOCS_TARGET\08_depin\videos\$($_.Name)" -Force
    Write-Host "  [DOC] 08_depin/videos/$($_.Name)" -ForegroundColor Blue
    $script:movedDocs++
}

# --- 2.10 docs/08_depin/images/ (jpg 非快照) ---
Get-ChildItem $DOWNLOAD -Recurse -File -Filter "*.jpg" | Where-Object {
    $_.Name -notmatch "日度发电量快照表"
} | ForEach-Object {
    Move-Item -Path $_.FullName -Destination "$DOCS_TARGET\08_depin\images\$($_.Name)" -Force
    Write-Host "  [DOC] 08_depin/images/$($_.Name)" -ForegroundColor Blue
    $script:movedDocs++
}

# --- 2.11 剩余 PDF → docs/03_financials/ 或 docs/04_legal/ ---
# 合同类 → financials
Get-ChildItem $DOWNLOAD -Recurse -File -Filter "*.pdf" | Where-Object {
    $_.Name -match "Agreement" -or $_.Name -match "Contract" -or
    $_.Name -match "Cooperation" -or $_.Name -match "Energy" -or
    $_.Name -match "Approval" -or $_.Name -match "Administrative"
} | ForEach-Object {
    Move-Item -Path $_.FullName -Destination "$DOCS_TARGET\03_financials\$($_.Name)" -Force
    Write-Host "  [DOC] 03_financials\$($_.Name)" -ForegroundColor Blue
    $script:movedDocs++
}

# --- 2.12 未分类文件 → docs/08_depin/ (兜底) ---
Get-ChildItem $DOWNLOAD -Recurse -File | ForEach-Object {
    $ext = $_.Extension.ToLower()
    if ($ext -eq ".pdf" -or $ext -eq ".drawio") {
        Move-Item -Path $_.FullName -Destination "$DOCS_TARGET\08_depin\$($_.Name)" -Force
        Write-Host "  [DOC] 08_depin\$($_.Name)" -ForegroundColor DarkYellow
    } else {
        Move-Item -Path $_.FullName -Destination "$DOCS_TARGET\08_depin\$($_.Name)" -Force
        Write-Host "  [FALLBACK] 08_depin\$($_.Name)" -ForegroundColor DarkYellow
    }
    $script:movedDocs++
}

# ========== 4. 验证结果 ==========
Write-Host "`n========== 迁移结果 ==========" -ForegroundColor Cyan
Write-Host "  Assets 快照: $movedAssets 个文件" -ForegroundColor Magenta
Write-Host "  Docs 文档:   $movedDocs 个文件" -ForegroundColor Blue
Write-Host "  总计:        $($movedAssets + $movedDocs) / 152" -ForegroundColor Green

# 统计各目标目录文件数
Write-Host "`n========== 目标目录统计 ==========" -ForegroundColor Cyan
$stats = @{}
Get-ChildItem $DOCS_TARGET -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Replace("$DOCS_TARGET\", "").Split('\')[0]
    if (-not $stats[$rel]) { $stats[$rel] = 0 }
    $stats[$rel]++
}
$stats.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Host "  docs/$($_.Name): $($_.Value) files"
}
$assetCount = (Get-ChildItem $ASSETS_TARGET -File -ErrorAction SilentlyContinue | Measure-Object).Count
Write-Host "  assets/generation: $assetCount files" -ForegroundColor Magenta

# ========== 5. 清理空目录 ==========
Write-Host "`n========== 清理空下载目录 ==========" -ForegroundColor Cyan
Get-ChildItem $DOWNLOAD -Directory | ForEach-Object {
    $count = (Get-ChildItem $_.FullName -File | Measure-Object).Count
    if ($count -eq 0) {
        Remove-Item $_.FullName -Force
        Write-Host "  [REMOVED] $($_.Name)" -ForegroundColor Red
    } else {
        Write-Host "  [REMAIN] $($_.Name) ($count files left)" -ForegroundColor Yellow
    }
}

Write-Host "`n========== 完成！ ==========" -ForegroundColor Green
