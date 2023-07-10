import { ethers, upgrades } from "hardhat";


async function main() {
  const BionicInvestorPassContract = await ethers.getContractFactory("BionicInvestorPass");
  console.log("Deploying BionicInvestorPass contract...");
  const v1contract = await upgrades.deployProxy(BionicInvestorPassContract, [], {
    initializer: "initialize",
    unsafeAllow: ['delegatecall']
  });
  await v1contract.deployed();
  console.log("BionicInvestorPass Contract deployed to:", v1contract.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});