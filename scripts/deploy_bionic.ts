import hre,{ ethers, upgrades } from "hardhat";



async function main() {
  const BionicFTContract = await ethers.getContractFactory("Bionic");
  console.log("Deploying Bionic contract...");
  const v1contract = await upgrades.deployProxy(BionicFTContract, [], {
    initializer: "initialize",
    unsafeAllow: ['delegatecall']
  });
  await v1contract.deployed();
  console.log("Bionic Contract deployed to:", v1contract.address);

  verifyContract(v1contract.address);
}

async function verifyContract(contractAddress:string){
  console.log(`Verifying Contract at ${contractAddress}`);
  let res= await hre.run("verify:verify", {
      address: contractAddress,//funding.address,
      constructorArguments: [],
    });
  console.log("Verified: ",res)
  return res;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});