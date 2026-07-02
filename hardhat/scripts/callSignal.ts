import { ethers } from "ethers";
import { readFileSync } from "fs";
import { resolve } from "path";

async function main() {
  const provider = new ethers.JsonRpcProvider("https://rpc.ritualfoundation.org");
  const wallet = new ethers.Wallet(process.env.DEPLOYER_PRIVATE_KEY!, provider);
  
  const artifactPath = resolve("artifacts/contracts/agent/GoldSignalAgent.sol/GoldSignalAgent.json");
  const artifact = JSON.parse(readFileSync(artifactPath, "utf8"));
  
  const addr = "0x0f31168ea1c03e807Af63198DE9e083Ccc644036";
  const contract = new ethers.Contract(addr, artifact.abi, wallet);
  
  const tx = await contract.requestSignal("4053.30");
  console.log("TX hash:", tx.hash);
  await tx.wait();
  console.log("Signal requested on-chain!");
}

main().catch(console.error);
