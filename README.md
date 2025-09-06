# 🛡️ Decentralized Insurance dApp

A blockchain-based decentralized insurance platform built on Ethereum using Solidity and Hardhat. This dApp enables users to buy policies, file claims, and receive claim approvals transparently — without centralized intermediaries.

## 🚀 Live Deployment

Environment: Localhost (Hardhat)  
Status: ✅ Live  
Contract Address: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512

## 🧩 Features

- Policy Creation and Purchase
- Claim Filing and Claim Status Tracking
- Owner-Only Claim Approvals/Rejections
- Access Control with Role-based Restrictions
- Solidity Smart Contracts (v0.8.25)
- Web3 Wallet Integration (MetaMask support)
- Modular frontend with Ethers.js

## 🏗 Tech Stack

Frontend: HTML, CSS, JavaScript, Ethers.js  
Backend: Solidity (v0.8.25), Hardhat  
Testing: Mocha, Chai, Hardhat Network  
Deployment: Hardhat CLI + Local Blockchain

## 🧱 Project Structure

```
etherium-decentralized-insurance/
├── contracts/
│   └── DecentralizedInsurance.sol
├── scripts/
│   └── deploy.js
├── frontend/
│   ├── index.html
│   ├── style.css
│   ├── script_new.js
│   └── new_abi.json
├── test/
│   └── Insurance.test.js
├── hardhat.config.cjs
├── package.json
└── README.md
```

## ⚙️ Getting Started

1. Clone the Repository  
   `git clone https://github.com/fbanks5/etherium-decentralized-insurance.git`

2. Install Dependencies  
   `npm install`

3. Run Local Hardhat Node  
   `npx hardhat node`

4. Deploy Smart Contract  
   `npx hardhat run scripts/deploy.js --network localhost`

5. Launch Frontend  
   `cd frontend`  
   Open `index.html` in browser

## 🧪 Running Tests

`npx hardhat test`

## 🔐 Wallet Setup

Ensure MetaMask is:

- Connected to `localhost:8545`
- Using one of the generated test accounts

## 📅 Roadmap

- [x] Local development and deployment
- [x] Full frontend integration with MetaMask
- [ ] Deployment to Goerli / Sepolia testnet
- [ ] Add premium-based policy tiers
- [ ] Off-chain claim validation via Oracles
- [ ] Production launch & frontend hosting

## 🧠 Author

**Frantz Banks III**  
Application Security Engineer | Blockchain Developer  
[linkedin.com/in/](frantz-banks-iii-m-s-726bb6149)

## ⚠️ Disclaimer

> This project is for **educational and demonstration purposes only**.  
> Do not use in production without proper audits.
