const hre = require("hardhat");

async function main() {
  console.log("🚀 Starting deployment...");

  const InsuranceFactory = await hre.ethers.getContractFactory(
    "DecentralizedInsurance"
  );
  const insurance = await InsuranceFactory.deploy();
  await insurance.waitForDeployment();

  const address = await insurance.getAddress();
  console.log("✅ Contract deployed to:", address);
}

main().catch((error) => {
  console.error("❌ Deployment failed:", error);
  process.exitCode = 1;
});
