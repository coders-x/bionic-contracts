import { ethers, upgrades } from "hardhat";


async function main() {
  const BionicFTContract = await ethers.getContractFactory("Bionic");
  console.log("Deploying Bionic contract...");
  const v1contract = await upgrades.deployProxy(BionicFTContract, [], {
    initializer: "initialize",
    unsafeAllow: ['delegatecall']
  });
  await v1contract.deployed();
  console.log("Bionic Contract deployed to:", v1contract.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});