# AGV Nexrur — 文件管理与 Google Drive 迁移设计

> 版本：v3.0 (2026-04-18)
> 依据：`agv-digital-ops/DESIGN.md` v3.0 §2（三层信任模型）& §8（AUDIT 联动）

---

## 目录

1. [总览](#一总览)
2. [四角色模型](#二四角色模型s1--s3-联动)
3. [两级 Drive 架构](#三两级-drive-架构)
4. [协议层 Drive](#四协议层-driveagv-protocol-docs)
5. [资产层 Drive](#五资产层-drive义传-agv-asset-drive)
6. [Drive 权限矩阵](#六drive-权限矩阵)
7. [本地目录结构](#七本地目录结构)
8. [三大配置文件对齐](#八三大配置文件对齐)
9. [文件命名规范](#九文件命名规范)
10. [迁移实施清单](#十迁移实施清单)
11. [早期阶段兼任规则](#十一早期阶段兼任规则)
12. [交叉引用](#十二交叉引用)
13. [assets/ JUNCTION 架构（本地开发环境）](#十三assets-junction-架构本地开发环境)
14. [前端 URL 盘点](#十四前端-url-盘点)

---

## 一、总览

`agv-nexrur/` 管理两类 Google Drive 文件：

| 类别 | 配置文件 | 内容 | 受众 | Drive 数 |
|------|---------|------|------|:--------:|
| **协议层** | `src/agv_docs.yml` (124 文件) | 白皮书/Pitch/法律/ESG/DePIN 视频 | 所有投资者（公开/半公开） | 1 个 |
| **资产层** | `src/agv_asset.yml` (30+ 文件) | 电站档案/发电快照/运维/财务 | 特定审计方（权限隔离） | **每资产 1 个** |

**核心原则**：协议层 = 面向投资者的公开材料，统一 Viewer 读取；资产层 = 电站运营数据，按四角色矩阵严格隔离。两层文件**不混放**于同一 Drive。

---

## 二、四角色模型（S1 + S3 联动）

| # | 角色 | 对应系统 | 职责 | 独立性要求 |
|---|------|---------|------|-----------|
| 1 | 电站运营方 | S1 上游输入 | 提供原始数据（电表读数、设备日志、GPS 坐标） | 被审计方 — **必须独立于角色 3** |
| 2 | 数据链运维 | S1 Oracle | 采集 → AI PoV 四层校验 → 哈希链化 → EIP-712 上链 | 保证数据不可篡改 |
| 3 | 审计师 | S3 Digital-Ops | 日审（五维模型）→ 异常分类 → 结算四步验证 → 报告生成 | 审计方 — **必须独立于角色 1** |
| 4 | 管理员 | 基础设施 | Drive 权限管理 + 自动化编排 + frank@agvnexrur.ai | Workspace 管理员 |

**核心独立性原则**：角色 1（被审计方）≠ 角色 3（审计方），这是审计铁律。
- S1 的哈希链保证角色 1 **无法篡改**已上链数据
- S3 的审计链保证角色 3 的判定**有据可查**

---

## 三、两级 Drive 架构

```
Google Workspace (frank@agvnexrur.ai)
│
├── 「AGV Protocol Docs」               ← 协议层（agv_docs.yml 对应）
│   ├── 01_home/                        投资者首页材料
│   ├── 02_tech/                        技术白皮书
│   ├── 03_financials/                  财务模型 & 报表
│   ├── 04_legal/                       法律文件
│   ├── 05_esg/                         ESG 文件
│   ├── 06_sales_marketing/             销售营销
│   ├── 07_management_team/             管理团队
│   └── 08_depin/                       DePIN 媒体
│       ├── videos/                     视频（25 个）
│       └── images/                     图片（34 个）
│   权限: frank@ Manager | 投资者 Viewer
│
└── 「义传 AGV Asset Drive」            ← 资产层（agv_asset.yml 对应 — 见§五）
    └── yichuan/                        ← asset_id（纯命名空间，无权限设置）
        ├── op-profile/                 运营方档案 ← 权限设在此层
        ├── s1-snapshots/               S1 每日快照 ← 权限设在此层
        ├── s3-audit/                   S3 审计产出 ← 权限设在此层
        └── s3-reports/                 最终报告 ← 权限设在此层
    权限: 四角色矩阵，设在**角色目录层**（见§六）
```

**扩展模式**：未来新增资产（如"陕西 XX 电站"）时，为其创建**独立** Shared Drive，在 `agv_asset.yml` 的 `assets:` 下新增一个顶层 key，与义传同构。

---

## 四、协议层 Drive（AGV Protocol Docs）

### 4.1 内容来源

`src/agv_docs.yml` 记录 **124 个文件**，分 9 组，每组对应 `investor-portal` 的一个前端页面（`08_depin` 下 videos/images 各算一组）：

| 组 | `dir` | 前端页面 | 文件数 | 内容 |
|----|-------|---------|:------:|------|
| 1 | `01_home` | `[locale]/page.tsx` | 3 | 首页材料 |
| 2 | `02_tech` | `[locale]/tech/page.tsx` | 8 | 技术白皮书、PowerToMint、RWA |
| 3 | `03_financials` | `[locale]/financials/page.tsx` | 9 | 财务模型 & 报表 |
| 4 | `04_legal` | `[locale]/legal/page.tsx` | 24 | 法律文件 |
| 5 | `05_esg` | `[locale]/esg/page.tsx` | 16 | ESG 审批文件 |
| 6 | `06_sales_marketing` | `[locale]/sales-marketing/page.tsx` | 4 | 销售营销 + MOU |
| 7 | `07_management_team` | `[locale]/management-team/page.tsx` | 1 | 管理团队 |
| 8 | `08_depin/videos` | `[locale]/depin/page.tsx` | 25 | DePIN 视频 |
| 9 | `08_depin/images` | `[locale]/depin/page.tsx` | 34 | DePIN 图片 |
| | | **合计** | **124** | |
> ✅ **已确认**（v3.0）：第 9 组 `08_depin/images`（34 个文件）位于 `agv_docs.yml` 第 420 行之后。
> 与组 8 `08_depin/videos` 共用 `dir: 08_depin`，共同服务 `depin/page.tsx`（60+ 个嵌入 URL）。

### 4.2 已知交叉引用

- `01_home/#3` 与 `02_tech/#7` 为同一文件（`file_id: 11N8RXY9NnAQd9bi`），迁移后共用同一 Drive URL 即可
- `08_depin/#18`、`#19` 等标注"代码中为.view格式(已损坏)，文件ID有效"— 迁移时需验证

### 4.3 协议层 Drive 权限

| 角色 | 权限 | 说明 |
|------|------|------|
| `frank@agvnexrur.ai` | **Manager** | 创建者、文件上传、权限管理 |
| 投资者/客户 | **Viewer** | 按需邀请，只读 |
| S1/S3 Agent | **无** | 协议层与审计无关，不授权 |

### 4.4 迁移方式

1. 以 `frank@agvnexrur.ai` 创建「AGV Protocol Docs」Shared Drive
2. 按 `01_home` ~ `08_depin` 创建 8 个子文件夹
3. 运行 `gdrive_download.py` 批量下载 154 个文件到 `assets/docs/`（穿透 JUNCTION 直接写入云盘）
4. 按文件归属上传至新 Shared Drive 对应子文件夹
5. 逐个回填 `agv_docs.yml` 中的 `new_url` 字段
6. 前端代码 `page.tsx` 从 `old_url` 切换到 `new_url`

---

## 五、资产层 Drive（义传 AGV Asset Drive）

### 5.1 Drive 文件夹结构

> **三层架构**：Drive → `{asset_id}/` → 角色目录。**权限设在角色目录层**，asset_id 层为纯命名空间。
> **命名前缀**：`op-` = 运营方（Operator），`s1-` = S1 Agent，`s3-` = S3 Agent。

```
义传 AGV Asset Drive/
└── yichuan/                ← asset_id（纯命名空间，无权限设置）
    ├── op-profile/         ← 角色1(运营方) Contributor 写入 | 角色2-4 只读
    │   ├── raw/            ← 运营方原始数据
│   │   ├── meter/          ← 电表原始读数
    │   │   ├── equipment/  ← 设备状态日志
    │   │   └── gps/        ← GPS 坐标
    │   ├── esg/            ← 政府审批 & ESG 文件
    │   ├── legal/          ← 法律/公司注册文件
    │   ├── financials/     ← 财务报表
    │   ├── verification/   ← 权属/合规验证
    │   └── due-diligence/  ← DD 报告
    ├── s1-snapshots/       ← 角色2(S1 Agent) 自动写入 | 角色3 只读
    │   └── {YYYY-MM}/      ← 每月快照目录
    │       └── {YYYY-MM-DD}_snapshot.yml
    ├── s3-audit/           ← 角色3(S3 Agent) 写入 | 角色4 管理
    │   ├── daily/          ← rwa_audit_record.yml（每日）
    │   ├── anomaly/        ← rwa_anomaly_report.yml（异常时触发）
    │   └── settlement/     ← rwa_settlement_verification.yml（每月）
    └── s3-reports/         ← 最终人类可读报告 → 按需分享给客户
```

### 5.1a 权限设置层级

| 层级 | Drive 路径 | 权限设置 | 说明 |
|------|-----------|----------|------|
| Drive 根 | `义传 AGV Asset Drive` | frank@ Manager | Drive 创建者 |
| asset_id | `yichuan/` | **不设置** | 纯命名空间，继承 Drive 根权限 |
| 角色目录 | `op-profile/` | 运营方 Contributor | **权限设在此层** |
| 角色目录 | `s1-snapshots/` | S1 Agent Contributor | **权限设在此层** |
| 角色目录 | `s3-audit/` | S3 Agent Contributor | **权限设在此层** |
| 角色目录 | `s3-reports/` | S3 Agent Contributor | **权限设在此层** |

**为什么不在 asset_id 层设权限**：
- 运营方不应看到 `s3-audit/` 内容（审计独立性）
- 投资者只应看到 `s3-reports/`（最终报告）
- 权限下沉到角色目录层可实现精细隔离

### 5.2 内容来源

`src/agv_asset.yml` 按资产 → 公司层 → 电站层组织：

```yaml
assets:
  yichuan:                          # 资产标识
    display_name: "义传新能源"
    drive_name: "义传 AGV Asset Drive"   # ✅ 已创建
    drive_id: "0AL2b1JHZDR_3Uk9PVA"      # ✅ 已创建

    profile:                        # 公司层文件（一次性）
      business_reg: [...]           # 工商/营业执照
      ownership: [...]              # 电站权属证明
      major_contracts: [...]        # EPC/O&M/融资协议

    stations:                       # 电站层文件（按站独立）
      - station_id: ""              # ← 待填（操作 T3）
        generation:
          "2025": [...]             # 30 个 daily snapshots（已从 agv_docs.yml 迁出）
        operations: [...]           # 运维报告
        financials: [...]           # 银行回款/补贴/税务
```

### 5.3 站点元数据待填

当前 `agv_asset.yml` 中所有 `station_id` / `station_name` 为空。**30 个 generation snapshots** 需要绑定到具体站点：

| 字段 | 当前状态 | 操作 |
|------|---------|------|
| `station_id` | `""` | 填写实际编号，如 `gd_01` |
| `station_name` | `""` | 填写名称，如 `广东1号电站` |
| `capacity_mw` | `0` | 填写装机容量（MW） |
| `province` | `""` | 填写省份 |

---

## 六、Drive 权限矩阵

### 6.1 协议层（AGV Protocol Docs）

| 角色 | 所有子文件夹 | Google 账号 |
|------|:----------:|------------|
| 管理员 | Manager | frank@agvnexrur.ai |
| 投资者 | Viewer（按需邀请） | investor@agvnexrur.ai |

### 6.2 资产层（义传 AGV Asset Drive）

> **权限设在角色目录层**（`yichuan/op-profile/` 等），`yichuan/` 本身不设权限。

| # | 角色 | `op-profile/` | `s1-snapshots/` | `s3-audit/` | `s3-reports/` | Google 账号 | 系统映射 |
|:-:|------|:-------------:|:---------------:|:-----------:|:-------------:|------------|---------|
| 1 | 电站运营方 | **写** | 读 | ❌ | ❌ | operator@agvnexrur.ai | 外部数据源（S1 上游，提交注册+电表） |
| 2 | S1 运维 | 读 | **写** | 读 | 读 | s1agent@agvnexrur.ai | S1 Agent（admitter/checker/monitor） |
| 3 | S3 审计师 | 读 | 读 | **写** | **写** | s3agent@agvnexrur.ai | S3 Agent（digital-ops）→ AUDIT 桥接 |
| 4 | 管理员 | 全部 | 全部 | 全部 | 全部 | frank@agvnexrur.ai | Workspace 管理员 |
| 5 | 客户/投资者 | ❌ | ❌ | ❌ | 读 | investor@agvnexrur.ai | investor-portal / 审计报告消费方 |

> **写** = Contributor（可上传/编辑自己的文件，不能删除他人文件）。
> **读** = Viewer（只读）。
> **全部** = Manager（完全控制）。
> ❌ = 不授权访问。

---

## 七、本地目录结构

```
agv-nexrur/
├── .env                            ← 环境变量（当前为空）
├── assets/                         ← 资产层（本地镜像 + 设计文档）
│   ├── DESIGN.md                   ← 本文件
│   └── yichuan/                    ← 义传资产本地文件
│       ├── _profile/               ← 对应 agv_asset.yml → profile
│       │   ├── business_reg/       ← 工商/营业执照
│       │   ├── ownership/          ← 权属证明
│       │   └── major_contracts/    ← 主合同
│       └── stations/               ← 对应 agv_asset.yml → stations
│           └── _template/          ← 站点模板
├── docs/                           ← 协议层（投资者文档本地副本）
│   ├── 01_home/                    ← 对应 agv_docs.yml → 01_home
│   ├── 02_tech/
│   ├── 03_financials/
│   ├── 04_legal/
│   ├── 05_esg/
│   ├── 06_sales_marketing/
│   ├── 07_management_team/
│   └── 08_depin/
└── src/                            ← 配置 + 工具
    ├── agv_docs.yml                ← 协议层 Drive 文件清单（124 文件）
    ├── agv_asset.yml               ← 资产层 Drive 文件索引
    └── gdrive_download.py          ← 批量下载脚本
```

### 7.1 `docs/` 与 `agv_docs.yml` 同构

`docs/` 的 8 个子目录名 **必须** 与 `agv_docs.yml` 的 `groups[].dir` 一一对应（`08_depin` 下 videos+images 两组共用一个物理目录）。

> ⚠️ `gdrive_download.py` 使用 **不同的子目录命名体系**（如 `00_whitepaper`、`07_operations`），详见 §八 对齐分析。下载完成后需按 `agv_docs.yml` 的 `dir` 重新归类。

### 7.2 `assets/yichuan/` 与 `agv_asset.yml` 同构

本地存放从 Drive 下载的资产文件副本。站点投产后，`stations/_template/` 用于复制创建实际站点目录：

```bash
# 示例：创建义传01号站
cp -r assets/yichuan/stations/_template assets/yichuan/stations/gd_01
```

---

## 八、三大配置文件对齐

### 8.1 三文件概况

| 文件 | 定位 | 文件数 | 子目录数 |
|------|------|:------:|:--------:|
| `agv_docs.yml` | 协议层真相源（对应前端页面路由） | **124** | 9 组（含 `08_depin` 下 videos+images 两子组） |
| `gdrive_download.py` | 批量下载工具（Google Drive → 本地） | **154**（145 + 9 EXTRA_IDS） | 9 个子目录 |
| `agv_asset.yml` | 资产层真相源（义传电站数据） | **30** snapshots | — |

### 8.2 gdrive_download.py 与 agv_docs.yml 子目录不对齐

两套文件使用**完全不同的子目录命名体系**：

| `agv_docs.yml` group | 文件数 | `gdrive_download.py` 子目录 | 文件数 | 状态 |
|----------------------|:------:|---------------------------|:------:|------|
| `01_home` (3) | 3 | *（无对应）* | — | ❌ download.py 无此目录 |
| `02_tech` (8) | 8 | `01_tech` (5) | 5 | ⚠️ 编号不同、数量不同 |
| `03_financials` (9) | 9 | `04_financials` (35) | 35 | ⚠️ 编号不同、download.py 多 26 个 |
| `04_legal` (24) | 24 | `06_legal` (16) | 16 | ⚠️ 编号不同、download.py 少 8 个 |
| `05_esg` (16) | 16 | `05_esg_approvals` (15) | 15 | ≈ 名称和数量略有差异 |
| `06_sales_marketing` (4) | 4 | `03_sales_marketing` (4) | 4 | ⚠️ 编号不同、数量一致 |
| `07_management_team` (1) | 1 | *（无对应）* | — | ❌ download.py 无此目录 |
| `08_depin/videos` (25) | 25 | *（无对应）* | — | ❌ download.py 无此目录 |
| `08_depin/images` (34) | 34 | *（无对应）* | — | ❌ download.py 无此目录 |
| *（无对应）* | — | `00_whitepaper` (1) | 1 | ❌ docs.yml 无此分组 |
| *（无对应）* | — | `02_pitch_decks` (4) | 4 | ❌ docs.yml 无此分组 |
| *（无对应）* | — | `07_operations` (64) | 64 | ❌ **最大孤儿目录**，待归属 |
| *（无对应）* | — | `08_gdocs` (1) | 1 | ❌ Google Docs 导出 |
| **合计** | **124** | | **145** | |

另有 **9 个 EXTRA_IDS**（`.view` 格式 URL 的文件，归入 `07_operations`），合计 **154** 个下载目标。

### 8.3 file_id 交叉污染

部分 file_id 在两套系统中被**不同分类**。例如：
- `1CXU6V0Rv2FhDvAGdI3aL7XpQl8yyibVC`：gdrive_download.py 标记为 `Financial_22`（`04_financials`），但 agv_docs.yml 中属于 `08_depin/images` seq 1

说明 `gdrive_download.py` 的分类是早期**粗放分类**（按文件纬度批量编号），agv_docs.yml 是后期**按前端页面归类**的精确版本。

### 8.4 对齐原则

**`agv_docs.yml` 是唯一真相源**（因为它直接对应前端页面路由）。

下载阶段（当前）的策略：
1. **先用 `gdrive_download.py` 按原始子目录全量下载 154 个文件**，不做任何重命名
2. 下载完成后，逐个核实 `07_operations`（64 个）+ `00_whitepaper`（1 个）+ `02_pitch_decks`（4 个）+ `08_gdocs`（1 个）的归属：
   - 属于协议层 → 归入 `agv_docs.yml` 对应 group，补充 entry
   - 属于资产层（如电站运维文件）→ 迁入 `agv_asset.yml`
   - 重复文件 → 标记去重
3. 对齐完成后，`gdrive_download.py` 子目录重命名以匹配 `agv_docs.yml` 的 `dir`

### 8.5 ~~34 文件分组待核实~~ — 已解决

> ✅ **v3.0 已确认**：`agv_docs.yml` 的第 9 组 `08_depin/images`（34 个文件）位于文件第 420 行之后。
> 之前 v2.0 只读到第 420 行，误以为文件只有 8 组 90 个。实际完整读取后确认 **9 组 124 个文件**。

---

## 九、文件命名规范

### 9.1 资产层（S1 + S3 产出）

| 文件 | 位置（Drive） | 周期 | 写入方 | 命名示例 |
|------|--------------|------|--------|---------|
| 每日快照 | `s1-snapshots/{YYYY-MM}/` | 每日 | S1 Agent（角色 2） | `2026-04-12_snapshot.yml` |
| 审计记录 | `s3-audit/daily/` | 每日 | S3 Agent（角色 3） | `rwa_audit_record.yml` |
| 异常报告 | `s3-audit/anomaly/` | 触发时 | S3 Agent（角色 3） | `rwa_anomaly_report.yml` |
| 结算验证 | `s3-audit/settlement/` | 每月 | S3 Agent（角色 3） | `rwa_settlement_verification.yml` |
| 月度报告 | `s3-reports/` | 每月 | S3 Agent（角色 3） | `2026-04_gd_01_report.pdf` |

### 9.2 资产层（运营方上传 — `op-profile/`）

命名规范：`{year}-{month:02d}_{来源}_{描述}.ext`

示例：
- `2025-10_国电_义传01号站对账单.pdf`
- `2025-10_运维_巡检记录.pdf`

### 9.3 协议层（投资者文档）

无严格命名规范。文件名保留 Google Drive 原始名称，迁移时不重命名。

---

## 十、迁移实施清单

### T1 — 创建义传 Asset Drive（P0 — 10 min）

| # | 操作 | 完成标志 |
|---|------|---------|
| 1 | 以 `frank@agvnexrur.ai` 创建「义传 AGV Asset Drive」 | Drive 可见 |
| 2 | 创建 asset_id 目录 `yichuan/`（纯命名空间，不设权限） | 目录存在 |
| 3 | 在 `yichuan/` 下创建 4 个角色目录并分别设置权限（见 §五.1a） | `op-profile/` `s1-snapshots/` `s3-audit/` `s3-reports/` 存在 |
| 4 | 创建 `yichuan/op-profile/raw/` 子目录 `meter/` `equipment/` `gps/` | 3 个子文件夹存在 |
| 5 | 创建 `yichuan/op-profile/` 子目录 `esg/` `legal/` `financials/` `verification/` `due-diligence/` | 5 个子文件夹存在 |
| 6 | 创建 `yichuan/s3-audit/` 子目录 `daily/` `anomaly/` `settlement/` | 3 个子文件夹存在 |
| 7 | 填写 `agv_asset.yml` 的 `drive_name`、`drive_id` 和 `asset_id: yichuan` | YAML 已更新 |

### T2 — 迁移 30 个 generation snapshots（P0 — 30 min）

| # | 操作 | 完成标志 |
|---|------|---------|
| 1 | 从 personal Drive 下载 30 个快照文件 | 本地 `assets/yichuan/stations/` 下存在 |
| 2 | 上传至「义传 AGV Asset Drive」→ `yichuan/s1-snapshots/{YYYY-MM}/` | Drive 文件可见 |
| 3 | 回填 `agv_asset.yml` 每个条目的 `new_url` | 30 个 `new_url` 非空 |

### T3 — 填充 station 元数据（P0 — 15 min）

| # | 操作 | 完成标志 |
|---|------|---------|
| 1 | 确认义传有几个站点、各站编号 | 站点清单确认 |
| 2 | 填写 `agv_asset.yml` 中 `station_id` / `station_name` / `capacity_mw` / `province` | 字段非空 |
| 3 | 将 30 个 generation snapshots 按站分配 | 每个 snapshot 归属明确 |
| 4 | 本地 `assets/yichuan/stations/` 下创建实际站点目录 | `gd_01/` 等目录存在 |

### T4 — 创建协议层 Drive + 迁移 124 文件（P1 — 1~2 h）

| # | 操作 | 完成标志 |
|---|------|---------|
| 1 | 以 `frank@agvnexrur.ai` 创建「AGV Protocol Docs」 | Drive 可见 |
| 2 | 创建 8 个子文件夹 `01_home` ~ `08_depin` | 8 个文件夹存在 |
| 3 | 运行 `gdrive_download.py` 下载到 `assets/docs/`（穿透 JUNCTION 写入云盘） | 154 个文件在 `assets/docs/` 可见 |
| 4 | 核实 70 个孤儿文件归属（`07_operations` 64 + 其他 6） | 每个文件有明确分类 |
| 5 | 按 group 上传到对应 Shared Drive 子文件夹 | 所有文件可见 |
| 6 | 回填 `agv_docs.yml` 每个条目的 `new_url` | 124+ 个 `new_url` 非空 |

### T5 — 对齐 gdrive_download.py（P1 — 1 h）

| # | 操作 | 完成标志 |
|---|------|--------|
| 1 | 打开 `assets/docs/` 下载产出，逐文件核实内容和归属 | 154 个文件有内容描述 |
| 2 | 将 `07_operations`（64）、`00_whitepaper`（1）、`02_pitch_decks`（4）、`08_gdocs`（1） 归入 `agv_docs.yml` 或 `agv_asset.yml` | 零孤儿文件 |
| 3 | `FILE_CATALOG` 子目录重命名与 `agv_docs.yml` 的 `dir` 一致 | 编号匹配 |
| 4 | 确认 `agv_docs.yml` 文件计数准确（当前 124，可能增加） | 数字一致 |

### T6 — 前端代码切换（P2 — 按页面逐步）

| # | 操作 | 完成标志 |
|---|------|---------|
| 1 | 逐个 `page.tsx` 从 `old_url` 切换到 `new_url` | 页面链接可访问 |
| 2 | 测试所有下载/预览功能正常 | QA 通过 |
| 3 | 移除前端对 personal Drive 的引用 | 零 `old_url` 残留 |

### T7 — 权限分配（P2 — 按角色）

| # | 操作 | 完成标志 |
|---|------|---------|
| 1 | Asset Drive：按§六权限矩阵邀请角色邮箱 | 权限生效 |
| 2 | Protocol Drive：按需邀请投资者 Viewer | 投资者可访问 |
| 3 | 验证角色 1 ≠ 角色 3（审计独立性） | 邮箱不重叠 |

---

## 十一、早期阶段兼任规则

| 兼任 | 允许？ | 说明 |
|------|:------:|------|
| 角色 2（S1 运维） + 角色 4（管理员） | ✅ | `frank@agvnexrur.ai` 一人兼任 |
| 角色 1（运营方） + 角色 3（审计师） | ❌ | **不可妥协的审计铁律** |
| 角色 1（运营方） + 角色 2（S1 运维） | ⚠️ | 早期可临时兼任，但 S1 哈希链保证数据不可回溯篡改 |
| 角色 3（审计师） + 角色 4（管理员） | ✅ | 管理员是基础设施角色，不影响审计独立性 |

---

## 十二、交叉引用

| 文档 | 路径 | 与本文件的关系 |
|------|------|--------------|
| S3 Digital-Ops 设计 | `agv-digital-ops/DESIGN.md` v3.0 | §2 三层信任模型 → 本文§二角色来源；§8 AUDIT 联动 → 本文§五审计产出 |
| agv_docs.yml | `agv-nexrur/src/agv_docs.yml` | 协议层文件索引（124 文件），§四的数据源 |
| agv_asset.yml | `agv-nexrur/src/agv_asset.yml` | 资产层文件索引（义传），§五的数据源 |
| gdrive_download.py | `agv-nexrur/src/gdrive_download.py` | 批量下载工具，§八对齐问题的核心 |
| AGV-WEB-RUN.md | `agv-web/AGV-WEB-RUN.md` | Vercel 部署指南（前端 `new_url` 切换后需重新部署） |
| AGENTS.md | `AGV/AGENTS.md` | 全仓约束（禁止 npm install 等） |

---

## 十三、assets/ JUNCTION 架构（本地开发环境）

> 本节记录 2026-04-12 确认的本地文件系统链接设计。

### 13.1 文件系统性质

`agv-nexrur/assets/` 在本地开发环境中是一个 **NTFS Junction**（目录联接点），指向 Google Shared Drive 的本地映射：

```
assets  ──JUNCTION──▶  G:\共享云端硬盘\义传 AGV Asset Drive
```

| 特性 | NTFS Junction | 说明 |
|------|:---:|------|
| 创建命令 | `cmd /c mklink /J assets "G:\共享云端硬盘\义传 AGV Asset Drive"` | 无需管理员权限 |
| 支持目标 | 仅目录 | 适合 Drive 映射 |
| 删除行为 | `rmdir` 只删链接，不删云盘内容 | 安全 |
| 透明性 | 对应用程序完全透明 | 读写穿透到云盘 |

### 13.2 设计意图

**轻量代码骨架入 git，重资产留云盘。**

| 层级 | 存储位置 | 跟踪方式 | 内容 |
|------|---------|---------|------|
| 设计文档 | git index → 穿透 Junction 写入云盘 | `git` 跟踪 | `DESIGN.md` |
| 运营数据 | 云盘原生 | **不入 git** | `op-profile/`、`s1-snapshots/`、`s3-audit/`、`s3-reports/` |

git index 中 `assets/` 下仅跟踪 **1 个文件**：

```
agv-web/agv-nexrur/assets/DESIGN.md   (18,435B LF / 本地 18,833B CRLF)
```

差值 = 398 行 × 1 字节 `\r`，是标准 CRLF 换行转换，内容完全一致。

### 13.3 Git 交互分析

**Git 完全不知道 Junction 的存在**，像操作普通目录一样穿透它。

| 场景 | 表现 | 影响 |
|------|------|------|
| `git pull` 更新 `DESIGN.md` | 穿透 Junction 直接写入云盘 | 正常 ✅ |
| `git checkout` / `git reset` / `git rebase` | **穿透 Junction 删除云盘文件** | ⛔ **极高风险** |
| 云盘新增大文件（op-profile/s1-snapshots 等） | 不会被 git 自动跟踪 | 正常 ✅ |
| 新开发者 clone（无 Junction） | 得到普通 `assets/DESIGN.md` 目录 | 正常，只是没有云盘资产 ✅ |
| 云盘离线（G: 不可用） | `git status` 可能变慢或报错读取 assets/ | ⚠️ 轻微 |

> ⚠️⚠️⚠️ **2026-04-13 事故教训**
>
> `git rebase` 到不含 `yichuan/` 文件的旧 commit 时：
> ```
> git rebase → checkout 旧树 → 发现文件"多余" → 删除工作树
>     ↓ Junction 将删除操作穿透到云端
>     ↓ Google Drive 137 个业务文件被真实删除
>     ↓ 所有同步用户数据丢失
> ```
>
> **根因**：git 不区分普通目录和 Junction，对它而言"删除工作树文件"就是标准 checkout 行为。
>
> **强制规则**（与 `AGENTS.md` JUNC-R1~R3 同步）：
> - **JUNC-R1**：Junction 目录必须在 `.gitignore` 中保护
> - **JUNC-R2**：禁止对含 Junction 内容的 commit 执行 `git rebase`
> - **JUNC-R3**：Junction 内容只通过云端管理，禁止 `git add`
>
> 当前 `.gitignore` 已保护：
> ```gitignore
> agv-web/agv-nexrur/assets/yichuan/
> !agv-web/agv-nexrur/assets/yichuan/DESIGN.md
> ```

`git status` 唯一噪音：

```
?? agv-web/agv-nexrur/assets/desktop.ini    ← Google Drive 自动生成的元数据
```

### 13.4 注意事项

1. **`git pull` 冲突处理**：如果远程更新了 `assets/` 下的 git 跟踪文件，而本地 Junction 目标（云盘）上该文件有变更，git 会按普通文件冲突处理——标准 merge 流程，无特殊风险
2. **跨机器不可移植**：Junction 目标 `G:\共享云端硬盘\...` 是本机 Google Drive 映射路径，其他开发者需按自己的 Drive 映射路径重建 Junction
3. **`desktop.ini` 噪音**：可在仓库根 `.gitignore` 添加 `desktop.ini` 消除（可选，不影响功能）

---

## 十四、Operator Profile Upload 前端集成

> 本节描述 `agv-web/asset/` 应用中运营方文档上传功能与本 Drive 架构的集成设计。  
> **详细 UI/路由设计**：见 `agv-web/asset/DESIGN.md`

### 14.1 设计背景

Asset App 承载两个独立工作流，两者的存储后端不同：

| 工作流 | 入口 | 频率 | 存储后端 | 原因 |
|--------|------|------|---------|------|
| Asset Registration | `/[locale]` 首页表单 | 一次性 | Firebase Storage | 小体积、注册阶段完成后不更新 |
| **Operator Profile Upload** | `/stations/[id]/upload` | 持续性 | **Google Shared Drive** | 大体积、审计独立性、多角色协作 |

### 14.2 路由与 Drive 路径映射

前端上传页的类别选择直接映射到 Drive 目录结构：

| 前端 UI 类别 | Drive 完整路径 | 写入权限 |
|-------------|---------------|---------|
| ESG & Sustainability | `{asset_id}/op-profile/esg/` | 角色 1, 4 |
| Legal Documents | `{asset_id}/op-profile/legal/` | 角色 1, 4 |
| Financial Records | `{asset_id}/op-profile/financials/` | 角色 1, 4 |
| Third-Party Verification | `{asset_id}/op-profile/verification/` | 角色 1, 4 |
| Due Diligence | `{asset_id}/op-profile/due-diligence/` | 角色 1, 4 |
| Raw Data: Meter | `{asset_id}/op-profile/raw/meter/` | 角色 1, 4 |
| Raw Data: Equipment | `{asset_id}/op-profile/raw/equipment/` | 角色 1, 4 |
| Raw Data: GPS | `{asset_id}/op-profile/raw/gps/` | 角色 1, 4 |

> **注意**：`{asset_id}` 当前为 `yichuan`，多资产场景下扩展为 `{asset_id}` 命名空间。

### 14.3 上传流程与本架构的接线

```
前端 Upload Page                      API Route                      本架构
────────────────                      ─────────                      ────────
1. 选择类别
   └─ ESG & Sustainability ──────▶ category = "esg"
                                          │
2. 选择文件                               │
   └─ 义传01号站对账单.pdf ───────▶ originalFilename
                                          │
3. 输入来源/描述                          │
   └─ source="国电"                       │
   └─ description="对账单"                │
                                          │
4. 点击 Upload                            ▼
                                  ┌──────────────────┐
                                  │ /api/upload/drive │
                                  │──────────────────│
                                  │ 1. Auth 验证      │
                                  │ 2. 角色 = 运营方   │
                                  │ 3. 构建文件名:    │
                                  │    2026-04_国电_  │
                                  │    义传01号站对账 │
                                  │    单.pdf        │
                                  │ 4. 查 agv_asset  │
                                  │    .yml → asset  │
                                  │    _id=yichuan   │
                                  │ 5. 调 Drive API  │
                                  │    上传到:       │
                                  │    yichuan/op-   │
                                  │    profile/esg/  │
                                  └────────┬─────────┘
                                           │
                                           ▼
                              ┌─────────────────────────┐
                              │  Google Shared Drive    │
                              │ 「义传 AGV Asset Drive」│
                              │  └─ yichuan/            │
                              │      └─ op-profile/     │
                              │          └─ esg/        │
                              │              └─ 2026-04 │
                              │                 _国电_  │
                              │                 义传01号│
                              │                 站对账单│
                              │                 .pdf    │
                              └─────────────────────────┘
```

### 14.4 文件命名规范执行

前端/API 必须遵循 §九.2 定义的命名规范：

```
{year}-{month:02d}_{来源}_{描述}.ext
```

**API Route 实现伪代码**：

```typescript
function buildFilename(input: UploadInput): string {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const source = input.source || '运营方';
  const description = input.description || input.originalFilename.replace(/\.[^.]+$/, '');
  const ext = input.originalFilename.split('.').pop();
  
  return `${year}-${month}_${source}_${description}.${ext}`;
}
// 输出: "2026-04_国电_义传01号站对账单.pdf"
```

### 14.5 权限验证链路

上传请求必须通过三层验证：

| 层级 | 验证内容 | 拒绝时返回 |
|------|---------|-----------|
| 1. Auth | Firebase ID Token 有效 | 401 Unauthorized |
| 2. Role | `users/{uid}.role == "operator"` 或 `"admin"` | 403 Forbidden |
| 3. Asset | `users/{uid}.assignedAssets.includes(stationId)` | 403 Forbidden |

> 角色 2（S1 Agent）和角色 3（S3 Auditor）不可上传到 `op-profile/`，只能读取。

### 14.6 与 JUNCTION 的关系

**前端上传不经过 JUNCTION**。上传是 API Route → Google Drive API 直连。

JUNCTION 仅用于：
- 本地开发时查看云盘文件
- 本设计文档 (`DESIGN.md`) 的 git 追踪

```
前端上传路径：
  Browser → Next.js API Route → Google Drive API → Shared Drive
  （不涉及本地文件系统）

JUNCTION 用途：
  本地开发者 → 通过 assets/ Junction 路径 → 直接浏览云盘文件
  （只读访问，开发调试用）
```

### 14.7 agv_asset.yml 扩展

上传功能需要知道 station → asset_id 的映射。`agv_asset.yml` 应包含：

```yaml
assets:
  yichuan:
    drive_name: "义传 AGV Asset Drive"
    drive_id: "0XXXXX..."  # Shared Drive ID
    stations:
      gd_01:
        name: "义传 01 号站"
        # ...
      gd_02:
        name: "义传 02 号站"
        # ...
```

API Route 读取此配置确定上传目标：

```typescript
const assetId = getAssetIdByStationId(stationId); // → "yichuan"
const driveId = config.assets[assetId].drive_id;
const uploadPath = `${assetId}/op-profile/${category}/`;
```

---

## 十五、前端 URL 盘点

> 本节记录 `investor-portal` 中 Google Drive URL 的分布现状，为 T6（前端代码切换）提供基线。

### 14.1 URL 分布（按页面）

`investor-portal/src/app/[locale]/` 下各 `page.tsx` 中**硬编码**的 Google Drive URL 数量：

| 页面文件 | URL 数 | 对应 `agv_docs.yml` 组 |
|---------|:------:|----------------------|
| `depin/page.tsx` | **~60** | `08_depin/videos` + `08_depin/images` |
| `financials/page.tsx` | **~31** | `03_financials` |
| `esg/page.tsx` | **~16** | `05_esg` |
| `tech/page.tsx` | **~8** | `02_tech` |
| `legal/page.tsx` | **~6** | `04_legal` |
| `sales-marketing/page.tsx` | **~4** | `06_sales_marketing` |
| `management-team/page.tsx` | **~1** | `07_management_team` |
| `page.tsx`（首页） | **~3** | `01_home` |
| **合计** | **~129** | |

> 与 `agv_docs.yml` 的 124 条相近（差异来自 `01_home`/`02_tech` 的交叉引用共用 file_id）。

### 14.2 当前架构特征

| 特征 | 现状 | 迁移影响 |
|------|------|---------|
| **URL 存放位置** | 各 `page.tsx` 内联数组（无集中配置） | 每个 URL 需逐文件替换 |
| **URL 格式** | `https://drive.google.com/file/d/{id}/view` 或 `/preview` | 迁移后 `new_url` 保持同格式 |
| **工具函数** | `client-utils.ts`：`extractDriveFileId()`, `getDirectDownloadUrl()`, `getPreviewUrl()` | 迁移后工具函数无需修改（处理标准 Drive URL） |
| **服务端 API** | `google-drive.ts`：`fetchDriveFile()` | 如切换 Shared Drive，需确认 API 权限 |
| **Firestore 配置** | `firestore.ts`：~45 条 dummy URL（`https://example.com/`） | 已是占位符，待填真实 `new_url` |

### 14.3 已知问题

- **~5 个 `.view` 格式 URL**（`depin/page.tsx`）：格式为 `https://drive.google.com/file/d/{id}.view`（末尾 `.view` 而非 `/view`），浏览器可能无法正确解析。对应 `agv_docs.yml` 中 `08_depin/videos` seq 18-20 和 `08_depin/images` seq 20, 27-31 的条目
- **无集中 URL 配置**：150+ 个 URL 散落在 8 个 `page.tsx` 中，迁移时无法批量替换，需逐页面操作

### 14.4 建议迁移方案

T6 执行时的推荐步骤：

1. 从 `agv_docs.yml` 生成 `old_url → new_url` 映射表
2. 按页面逐个替换（优先 `depin/page.tsx`，URL 数最多）
3. 修复 `.view` 格式 URL（替换为正确的 `/view` 或 `/preview`）
4. 考虑将 URL 集中到单一配置文件（如 `src/config/drive-urls.ts`），减少未来维护成本
