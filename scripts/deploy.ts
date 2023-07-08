import { ethers } from "hardhat";

async function main() {
  const initialAmount = ethers.utils.parseEther("1");

  const Bionic = await ethers.getContractFactory("Bionic");
  const bionic = await Bionic.deploy({ value: initialAmount });

  await bionic.deployed();

  console.log(`Bionic with 1 ETH deployed to ${bionic.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
