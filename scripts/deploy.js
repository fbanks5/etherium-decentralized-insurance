const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("🚀 Starting deployment...");

  const InsuranceFactory = await hre.ethers.getContractFactory(
    "DecentralizedInsurance"
  );
  const insurance = await InsuranceFactory.deploy();
  await insurance.waitForDeployment();

  const address = await insurance.getAddress();
  console.log("✅ Contract deployed to:", address);

  // Create default pool
  const tx = await insurance.createPool(
    "Basic Insurance",
    hre.ethers.parseEther("0.1"),
    hre.ethers.parseEther("1.0")
  );
  await tx.wait();
  console.log("🏊 Default pool created: Basic Insurance");

  // Write address to frontend/config.js
  const configPath = path.resolve(__dirname, "../frontend/config.js");
  const configContent = `// Auto-generated contract address\nexport const CONTRACT_ADDRESS = "${address}";\n`;
  fs.writeFileSync(configPath, configContent);
  console.log("📝 Contract address written to frontend/config.js");
}

main().catch((error) => {
  console.error("❌ Deployment failed:", error);
  process.exitCode = 1;
});
