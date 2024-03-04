import dotenv from 'dotenv';
import hre, { ethers } from "hardhat";
dotenv.config()

const ENTRY_POINT = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",
    GUARDIAN_ADDRESS = "0x4712e03DE21b2d8dfEDc996D1D401328f4cD9342";

async function main() {
    //deploy with guardian
    let guardian = await deployGuardian();
    let contract = await deployContract(guardian.address);
    verifyContract(contract.address, guardian.address);

    //use existing Guardian
    // let contract=await deployContract(GUARDIAN_ADDRESS);
    // verifyContract(contract.address,GUARDIAN_ADDRESS);

    return;
}


async function deployGuardian() {
    console.log(`Deploying Guardian contract...`);
    const TBAContract = await ethers.getContractFactory("AccountGuardian");
    let tba = await TBAContract.deploy();

    return await tba.deployed();
}
async function deployContract(guardian: string) {
    console.log(`Deploying TokenBound contract...`);
    const TBAContract = await ethers.getContractFactory("BionicAccount");
    let tba = await TBAContract.deploy(guardian, ENTRY_POINT);

    return await tba.deployed();
}

async function verifyContract(contractAddress: string, guardianAddress: string) {
    console.log(`Verifying Contract at ${contractAddress}`);
    let res = await hre.run("verify:verify", {
        address: contractAddress,//funding.address,
        constructorArguments: [guardianAddress, ENTRY_POINT],
    });
    console.log("Verified: ", res)
    return res;
}



main().then(console.log).catch(console.error)