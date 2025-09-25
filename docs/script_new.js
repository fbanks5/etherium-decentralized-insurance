// Web3 JavaScript integration for Decentralized Insurance dApp
// import { CONTRACT_ADDRESS } from "./config.js";

let provider;
let signer;
let contract;
let walletAddress;

const contractAddress = "0xa82fF9aFd8f496c3d6ac40E2a0F282E47488CFc9"; // Local Hardhat deployment
const abiPath = "./new_abi.json";

async function connectWallet() {
  try {
    if (typeof window.ethereum !== "undefined") {
      provider = new ethers.BrowserProvider(window.ethereum); // ✅ Ethers v6
      const accounts = await provider.send("eth_requestAccounts", []);
      walletAddress = accounts[0];
      // walletStatus.innerText = `Wallet connected: ${walletAddress}`;
      document.getElementById(
        "walletStatus"
      ).innerText = `Wallet Connected: ${walletAddress}`;
      console.log("Wallet connected:", walletAddress);
      await loadContract(provider);
    } else {
      walletStatus.innerText = "MetaMask is not installed";
      console.error("MetaMask is not installed");
    }
  } catch (err) {
    console.error("Wallet connection failed", err);
    walletStatus.innerText = "Wallet connection failed";
  }
}

async function loadContract(provider) {
  try {
    const response = await fetch(abiPath);
    const abi = await response.json();

    signer = await provider.getSigner();
    contract = new ethers.Contract(contractAddress, abi, signer);

    console.log("Contract loaded:", contract);
    document.getElementById("contractStatus").innerText = "✅ Contract loaded";
  } catch (err) {
    console.error("Failed to load contract:", err);
    alert("Failed to load contract: " + err.message);
  }
}

async function loadPolicySummary() {
  console.log("Loading policy summary...");
  if (!contract || !walletAddress) return;

  try {
    const policies = await contract.getPoliciesByUser(walletAddress);
    let total = policies.length;
    let active = 0;
    let inactive = 0;

    for (let i = 0; i < policies.length; i++) {
      const isActive = policies[i].isActive;
      if (isActive) active++;
      else inactive++;
    }

    document.getElementById("totalPolicies").innerText = total;
    document.getElementById("activePolicies").innerText = active;
    document.getElementById("inactivePolicies").innerText = inactive;
  } catch (err) {
    console.error("Error loading policy summary:", err);
  }
}

// TEMPORARY FUNCTION TO VERIFY CONTRACT
async function checkPolicyCount() {
  if (!contract || !walletAddress)
    return alert("Contract or wallet not loaded");
  try {
    const count = await contract.getPolicyCountForAddress(walletAddress);
    alert(`Policy Count: ${count}`);
  } catch (err) {
    console.error("Error calling getPolicyCountForAddress:", err);
    alert("Failed to fetch policy count.");
  }
}

// Buy a new insurance policy (value: 0.1 ETH)
async function buyPolicy() {
  if (!contract) return alert("Contract not loaded.");

  try {
    const tx = await contract.joinPool(0, {
      value: ethers.parseEther("0.1"),
    });
    await tx.wait();
    alert("Insurance policy purchased successfully!");
    await loadPolicySummary();
  } catch (error) {
    console.error("Failed to buy policy:", error); // console error
    alert("Failed to purchase policy: ${error.message || error}"); // browser alert
  }
}

// File a claim for an active policy
async function fileClaim() {
  if (!contract) return alert("Contract not loaded.");

  const reason = document.getElementById("claimReason").value;
  if (!reason.trim()) return alert("Please enter a reason for the claim.");

  try {
    const tx = await contract.submitClaim(0, ethers.parseEther("0.05"), reason);
    await tx.wait();
    alert("Claim submitted successfully!");
  } catch (error) {
    console.error("Failed to submit claim:", error);
    alert("Failed to submit claim: " + (error?.message || error));
  }
}

// View Claim Information
async function viewClaim() {
  try {
    const claimId = document.getElementById("claimId").value;
    if (!claimId) {
      alert("Please enter a Claim ID.");
      return;
    }

    const result = await contract.getClaimDetails(claimId);
    const [
      claimant,
      poolId,
      amount,
      description,
      timestamp,
      status,
      approvals,
      rejections,
      totalVotes,
    ] = result;
    const statusMap = {
      0: "Pending",
      1: "Approved",
      2: "Rejected",
      3: "Paid",
    };

    const output = `
        <p><strong>Claimant:</strong> ${claimant}</p>
            <p><strong>Pool ID:</strong> ${poolId}</p>
            <p><strong>Amount:</strong> ${ethers.formatEther(amount)} ETH</p>
            <p><strong>Description:</strong> ${description}</p>
            <p><strong>Timestamp:</strong> ${new Date(
              Number(timestamp) * 1000
            ).toLocaleString()}</p>
            <p><strong>Status:</strong> ${statusMap[status]}</p>
            <p><strong>Approvals:</strong> ${approvals}</p>
            <p><strong>Rejections:</strong> ${rejections}</p>
            <p><strong>Total Votes:</strong> ${totalVotes}</p>
    `;

    document.getElementById("claimInfo").innerHTML = output;
  } catch (err) {
    console.error("Error fetching claim details:", err);
    alert("Failed to fetch claim details. See console for error.");
  }
}

async function assessClaim(claimId, approve) {
  try {
    if (!contract) throw new Error("Contract not loaded.");
    const tx = await contract.assessClaim(claimId, approve);
    await tx.wait();
    alert(`Claim ${approve ? "approved" : "rejected"} successfully!`);
  } catch (err) {
    console.error("Error assessing claim:", err);
    alert("Failed to assess claim.  See console for details.");
  }
}

async function payClaim() {
  if (!contract) {
    console.error("Contract not loaded.");
    return;
  }

  const claimId = parseInt(document.getElementById("claimId").value);
  try {
    const tx = await contract.payClaim(claimId);
    await tx.wait();
    alert("Claim paid successfully!");
    console.log("Claim paid:", tx.hash);
  } catch (err) {
    console.error("Failed to pay claim:", err);
    alert("Failed to pay claim.  See console for details.");
  }
}

async function viewClaimHistory() {
  if (!contract || !walletAddress) {
    console.error("Contract not loaded or wallet not connected.");
    alert("Please connect your wallet first.");
    return;
  }

  try {
    const walletAddress = await signer.getAddress();
    const claimIds = await contract.getClaimIdsByUser(walletAddress);

    const claimsList = document.getElementById("claimsList");
    claimsList.innerHTML = "";

    if (claimIds.length === 0) {
      claimsList.innerHTML = "<li>No claims found.</li>";
      return;
    }

    const statusEnum = ["Pending", "Approved", "Rejected", "Paid"];

    for (let i = 0; i < claimIds.length; i++) {
      const id = claimIds[i];
      const details = await contract.getClaimDetails(id);
      const status = statusEnum[Number(details[5])];

      const listItem = document.createElement("li");
      listItem.innerHTML = `
        <strong>Claim #${id}</strong><br>
        Pool ID: ${details[1]}<br>
        Amount: ${ethers.formatEther(details[2])} ETH<br>
        Status: ${status}<br>
        Description: ${details[3]}<br>
        Date: ${new Date(Number(details[4]) * 1000).toLocaleString()}
        <hr>`;
      claimsList.appendChild(listItem);
    }
  } catch (err) {
    console.error("Error fetching claim history:", err);
    alert("Failed to fetch claim history.");
  }
}

async function viewUserPolicies() {
  if (!contract || !walletAddress) {
    console.error("Contract not loaded or wallet not connected.");
    alert("Please connect your wallet first");
    return;
  }

  try {
    const policies = await contract.getPoliciesByUser(walletAddress);
    const policiesList = document.getElementById("policiesList");
    policiesList.innerHTML = "";

    if (policies.length === 0) {
      policiesList.innerHTML = "<li>No policies found.</li>";
      return;
    }

    policies.forEach((policy, index) => {
      const listItem = document.createElement("li");
      listItem.innerText = `Policy #${policy.id} | Pool ID: ${
        policy.poolId
      } | Premium: ${ethers.formatEther(
        policy.premiumPaid
      )} ETH | Timestamp: ${new Date(
        Number(policy.timestamp) * 1000
      ).toLocaleString()} | Active: ${policy.isActive}`;
      policiesList.appendChild(listItem);
    });
  } catch (err) {
    console.error("Error fetching user policies:", err);
    alert("Failed to fetch user policies.");
  }
}

document.addEventListener("DOMContentLoaded", () => {
  const connectBtn = document.getElementById("connectWalletBtn");
  if (connectBtn) {
    connectBtn.addEventListener("click", connectWallet);
  }
});
