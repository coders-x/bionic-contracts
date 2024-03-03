import dotenv from 'dotenv';
import { ethers } from "hardhat";
import hre from "hardhat";
import { FactoryOptions } from 'hardhat/types';
import { mumbai as config } from './config.json';
import { BionicPoolRegistry } from '../typechain-types';
dotenv.config()
const CONFIG = config;

async function main() {
    // let contract = await deployContract({});

    let contract = await ethers.getContractAt("BionicPoolRegistry", config.bionicLaunchPad);

    console.log(`deployed fwv at ${contract.address}`)
    // await verifyContract(contract, utils.address, [
    //     CONFIG.tokenAddress, CONFIG.usdtAddress, CONFIG.bionicInvestorPass, CONFIG.vrfCoordinator, CONFIG.keyHash,
    //     CONFIG.subId, CONFIG.reqVRFPerWinner
    // ]);


    await verifyContract(contract, [
        CONFIG.tokenAddress, CONFIG.usdtAddress, CONFIG.bionicInvestorPass,
        CONFIG.vrfCoordinator, CONFIG.keyHash, CONFIG.subId, CONFIG.reqVRFPerWinner
    ]);
}


async function deployContract(opt: FactoryOptions) {

    console.log(`Deploying BionicPoolRegistry contract...`);


    const BionicPoolRegistryContract = await ethers.getContractFactory("BionicPoolRegistry", opt);

    let funding = await BionicPoolRegistryContract.deploy(CONFIG.tokenAddress, CONFIG.usdtAddress, CONFIG.bionicInvestorPass,
        CONFIG.vrfCoordinator, CONFIG.keyHash, CONFIG.subId, CONFIG.reqVRFPerWinner);

    return await funding.deployed();
}

async function verifyContract(contract: BionicPoolRegistry, args: any) {
    let res;

    // console.log(`Verifying Utils Contract at ${utilsAddress}`);
    // res = await hre.run("verify:verify", {
    //     address: utilsAddress,//funding.address,
    // });

    let treasuryAddress = await contract.treasury();
    console.log(`Verifying Treasury Contract at ${treasuryAddress}`);
    res = await hre.run("verify:verify", {
        address: treasuryAddress,
        args: [contract.address],//funding.address,
    });

    let claimAddress = await contract.claimFund();
    console.log(`Verifying ClaimFund Contract at ${claimAddress}`);
    res = await hre.run("verify:verify", {
        address: claimAddress
    });

    console.log(`Verifying FWV Contract at ${contract.address}`);
    res = await hre.run("verify:verify", {
        address: contract.address,//funding.address,
        constructorArguments: args,
        libraries: {
            // Utils: utilsAddress//utils.address
        }
    });
    console.log("Verified: ", res);
    return res;
}

main().then(console.log).catch(console.error);

