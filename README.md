# AGV Protocol - Community Edition

> 🌍 **AGV (Asset Grosse Value)** - RWA 太阳能资产协议

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue)](https://soliditylang.org/)
[![BSC Mainnet](https://img.shields.io/badge/BSC-Mainnet-orange)](https://bscscan.com/)

## 📖 简介

AGV Protocol 是一个基于 BNB Chain 的 RWA（Real World Assets）协议，专注于太阳能资产的代币化和链上管理。

本仓库是社区开源版本，包含：
- 智能合约源码（NFT Pass、Token、Oracle）
- 前端 DApp 代码
- 部署脚本和测试

## 🏗 项目结构

```
AGV-Public/
├── agvprotocol-contracts-main/   ← NFT Pass 合约（ERC721A + UUPS）
├── onchainverification-main/     ← Oracle 验证合约（EIP-712）
├── tokencontracts-main/          ← Token 经济合约（pGVT/sGVT/GVT）
└── agv-web/                      ← 前端 DApp（Next.js 15）
    ├── agv-protocol-app/         主 DApp
    ├── investor-portal/          投资者门户
    ├── buy-page/                 NFT 购买
    ├── G3-Funding/               GVT 融资
    ├── asset/                    资产展示
    └── architecture/             文档站
```

## 🔗 链上合约（BSC Mainnet）

| 合约 | 地址 | 状态 |
|------|------|------|
| **pGVT** | `0x8F9EC8107C126e94F5C4df26350Fb7354E0C8af9` | ✅ Verified |
| **sGVT** | `0x53e599211bF49Aa2336C3F839Ad57e20dE3662a3` | ✅ Verified |
| **SeedPass V3** | `0x4d5c8A1f...` | ✅ Verified |
| **TreePass V3** | `0xB27A0EAD...` | ✅ Verified |
| **SolarPass V3** | `0xeE899BaA...` | ✅ Verified |
| **ComputePass V3** | `0xA9d26c79...` | ✅ Verified |

## 🛠 快速开始

### 合约构建

```bash
cd agvprotocol-contracts-main && forge build
cd onchainverification-main && forge build
cd tokencontracts-main && forge build
```

### 前端启动

```bash
cd agv-web
pnpm install
cd agv-protocol-app && pnpm dev
```

## 📜 许可证

MIT License - 详见各子项目的 LICENSE 文件

## 🔗 链接

- **官网**: [agvnexrur.ai](https://agvnexrur.ai)
- **GeckoTerminal**: [pGVT](https://www.geckoterminal.com/bsc/pools/0x5558e43eE316C45e6C842bC7aC4B770EED03c5C0) | [sGVT](https://www.geckoterminal.com/bsc/pools/0xBE1B08D1743f2C158165472Fa2fEB038E8DfaA9d)

---

> ⚠️ **注意**: 这是社区开源版本。生产部署请使用环境变量配置敏感信息。
