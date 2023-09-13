import dotenv from 'dotenv';
import hre, { ethers } from "hardhat";
dotenv.config()

const ENTRY_POINT = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",
    ERC6551_REGISTRY_ADDR = "0x02101dfB77FDE026414827Fdc604ddAF224F0921";

async function main() {
    let contract=await deployContract();
    verifyContract(contract.address);

    return ;


}


async function deployContract(){
    console.log(`Deploying TokenBound contract...`);
    const TBAContract = await ethers.getContractFactory("TokenBoundAccount");
    let tba=await TBAContract.deploy(ENTRY_POINT, ERC6551_REGISTRY_ADDR);

    return await tba.deployed();
}

async function verifyContract(contractAddress:string){
    console.log(`Verifying Contract at ${contractAddress}`);
    let res= await hre.run("verify:verify", {
        address: contractAddress,//funding.address,
        constructorArguments: [ENTRY_POINT, ERC6551_REGISTRY_ADDR],
      });
    console.log("Verified: ",res)
    return res;
}



main().then(console.log).catch(console.error)