# AGV Protocol - Community Edition

> Bridging renewable energy assets with decentralized finance on BNB Chain.

## Quick Start

```bash
# Frontend
cd agv-web && pnpm install && pnpm dev

# Contracts
cd tokencontracts-main && forge build && forge test
```

## Project Structure

```
AGV-Public/
├── agvprotocol-contracts-main/   # NFT Pass Contracts (Foundry)
├── onchainverification-main/     # Oracle Verification
├── tokencontracts-main/          # pGVT/sGVT Token Contracts
└── agv-web/                      # Frontend Apps (Next.js 15)
    ├── agv-protocol-app/         # Main DApp
    ├── buy-page/                 # NFT Purchase & Airdrop
    ├── G3-Funding/               # GVT Funding
    ├── investor-portal/          # Investor Dashboard
    ├── architecture/             # Documentation
    └── template/                 # Starter Template
```

## Deployed Contracts (BSC Mainnet)

| Contract | Address |
|----------|---------|
| pGVT | `0x8F9EC8107C126e94F5C4df26350Fb7354E0C8af9` |
| sGVT | `0x53e599211bF49Aa2336C3F839Ad57e20dE3662a3` |
| SeedPass V3 | `0x4d5c8A1f...` |
| SolarPass V3 | `0xeE899BaA...` |

## License

MIT License - See [LICENSE](LICENSE)
