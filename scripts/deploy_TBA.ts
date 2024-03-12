import dotenv from 'dotenv';
import hre, { ethers } from "hardhat";
import { arbitrum as configInfo } from './config.json';
import { MULTICALL_ADDRESS } from '../lib/tokenbound/lib/multicall-authenticated/examples/typescript/constants';
dotenv.config()



async function main() {
    //deploy with guardian
    let guardian = await deployGuardian();
    let contract = await deployContract(guardian.address);
    verifyContract(contract.address, guardian.address);

    //use existing Guardian
    // let contract=await deployContract(configInfo.guardianAddress);
    // verifyContract(contract.address,configInfo.guardianAddress);

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
    let tba = await TBAContract.deploy(configInfo.entryPoint, MULTICALL_ADDRESS, configInfo.erc6551Reg, guardian);

    return await tba.deployed();
}

async function verifyContract(contractAddress: string, guardian: string) {
    console.log(`Verifying Contract at ${contractAddress} with guardian ${guardian}`);
    let res = await hre.run("verify:verify", {
        address: contractAddress,//funding.address,
        constructorArguments: [configInfo.entryPoint, MULTICALL_ADDRESS, configInfo.erc6551Reg, guardian],
    });
    console.log("Verified: ", res)
    return res;
}



main().then(console.log).catch(console.error)