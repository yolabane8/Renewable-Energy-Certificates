# 🌱 Renewable Energy Certificates (REC) Smart Contract

A comprehensive Clarity smart contract for managing Renewable Energy Certificates on the Stacks blockchain. This contract enables the creation, transfer, retirement, and tracking of renewable energy certificates with full transparency and verifiability.

## 🌟 Features

- **🏭 Certificate Issuance**: Authorized issuers can mint REC NFTs with energy type, amount, and location data
- **🔄 Transfer & Trading**: Seamless transfer of certificates between users
- **⚡ Certificate Retirement**: Permanent retirement to prevent double-counting
- **📊 Portfolio Management**: Track user portfolios and calculate energy holdings
- **🔍 Verification System**: Authenticate certificates and verify issuer authorization
- **⚙️ Fractional Retirement**: Retire partial amounts from certificates
- **📈 Market Analytics**: Real-time statistics and market summaries
- **🚨 Emergency Controls**: Pause/unpause functionality for security
- **🎯 Monthly Targets**: Set and track renewable energy goals

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://docs.hiro.so/stacks/clarinet/cli) installed
- Stacks wallet for testing

### Installation
```bash
git clone <repository-url>
cd renewable-energy-certificates
clarinet check
```

### Testing
```bash
npm install
npm test
```

## 📋 Usage Instructions

### 1. **Add Authorized Issuer** 👥
Only contract owner can authorize certificate issuers:
```clarity
(contract-call? .renewable-energy-certificates add-authorized-issuer 'SP1ABC...)
```

### 2. **Register Energy Types** 🔋
Register valid renewable energy types:
```clarity
(contract-call? .renewable-energy-certificates register-energy-type "solar")
```

### 3. **Issue Certificate** 📜
Authorized issuers can create new certificates:
```clarity
(contract-call? .renewable-energy-certificates issue-certificate
    'SP1RECIPIENT...
    "solar"
    u1000  ;; 1000 MWh
    u1000000  ;; generation date (block height)
    u2000000  ;; expiry date (block height)
    "California Solar Farm A"
)
```

### 4. **Transfer Certificate** ↔️
Certificate owners can transfer to new owners:
```clarity
(contract-call? .renewable-energy-certificates transfer-certificate u1 'SP1NEWOWNER...)
```

### 5. **Retire Certificate** ♻️
Permanently retire certificates to claim environmental benefits:
```clarity
(contract-call? .renewable-energy-certificates retire-certificate u1)
```

### 6. **Fractional Retirement** ⚡
Retire partial amounts from larger certificates:
```clarity
(contract-call? .renewable-energy-certificates fractional-retire u1 u500)  ;; Retire 500 MWh
```

## 🔍 Query Functions

### Get Certificate Data
```clarity
(contract-call? .renewable-energy-certificates get-certificate-data u1)
```

### Verify Certificate Authenticity
```clarity
(contract-call? .renewable-energy-certificates verify-certificate-authenticity u1)
```

### Check Market Summary
```clarity
(contract-call? .renewable-energy-certificates get-market-summary)
```

### Calculate User Portfolio
```clarity
(contract-call? .renewable-energy-certificates calculate-user-portfolio 'SP1USER...)
```

## 📊 Certificate Structure

Each REC contains:
- **Energy Type**: Solar, wind, hydro, biomass, geothermal
- **MWh Amount**: Energy quantity in megawatt hours
- **Generation Date**: When energy was produced
- **Expiry Date**: Certificate validity period
- **Location**: Geographic source of renewable energy
- **Issuer**: Authorized issuer who created the certificate
- **Retirement Status**: Whether certificate has been retired

## 🛡️ Security Features

- **Authorization Control**: Only approved issuers can create certificates
- **Owner Verification**: Only certificate owners can transfer or retire
- **Pause Mechanism**: Emergency pause/unpause for security incidents
- **Input Validation**: Comprehensive validation of all inputs
- **Retirement Prevention**: Retired certificates cannot be transferred

## 🏗️ Contract Architecture

The contract implements:
- **NFT Standard**: Each certificate is a unique NFT
- **Data Maps**: Efficient storage of certificate metadata
- **Statistics Tracking**: Real-time market and issuer analytics
- **Batch Operations**: Process multiple certificates simultaneously
- **Fractional Operations**: Split certificates for partial retirement

## 🎯 Use Cases

- **🏢 Corporate Sustainability**: Companies buying RECs for carbon neutrality
- **⚡ Utility Compliance**: Meeting renewable energy mandates
- **💰 REC Trading Markets**: Facilitating certificate trading
- **📈 Impact Tracking**: Measuring renewable energy adoption
- **🌍 Carbon Offset Programs**: Environmental benefit verification

## 🔧 Development

### Running Tests
```bash
clarinet test
```

### Local Development
```bash
clarinet console
```

### Deployment
```bash
clarinet deploy
```

## 📈 Statistics & Analytics

The contract provides comprehensive analytics:
- Total certificates issued and retired
- MWh tracking across the entire system
- Individual issuer performance metrics
- Portfolio calculations for certificate holders
- Market retirement rates and trends

## 🌍 Environmental Impact

This smart contract enables transparent tracking of renewable energy generation and consumption, supporting the global transition to clean energy through verifiable environmental certificates.

---

Built with ❤️ for a sustainable future 🌱
