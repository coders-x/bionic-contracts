import dotenv from 'dotenv';
import { ethers } from "hardhat";
import hre from "hardhat";
import { FactoryOptions } from 'hardhat/types';
import { goerli as config } from './config.json';
import { BionicFundRasing } from '../typechain-types';
dotenv.config()
const CONFIG = config;

async function main() {
    const UtilsLib = await ethers.getContractFactory("Utils");
    const utils = await UtilsLib.deploy();
    await utils.deployed();
    console.log(`deployed utils at ${utils.address}`)
    let contract = await deployContract({
        libraries: {
            Utils: utils.address,//"0x03A1726655bE74aD1430aa30e4A823E14428346c"
            // Utils: CONFIG.utilsAddress,//"0x03A1726655bE74aD1430aa30e4A823E14428346c"
        }
    })
    console.log(`deployed fwv at ${contract.address}`)
    await verifyContract(contract, utils.address, [
        CONFIG.tokenAddress, CONFIG.usdtAddress, CONFIG.bionicInvestorPass, CONFIG.vrfCoordinator, CONFIG.keyHash,
        CONFIG.subId, CONFIG.reqVRFPerWinner
    ]);


    // await verifyContract("0xf6e470B6A6433880a97f80e7a841644237518259",CONFIG.utilsAddress,[
    //     CONFIG.tokenAddress, CONFIG.usdtAddress, CONFIG.bionicInvestorPass, CONFIG.vrfCoordinator, CONFIG.keyHash, 
    //     CONFIG.subId, CONFIG.cbGasLimit, CONFIG.reqVRFPerWinner
    // ]);
}


async function deployContract(opt: FactoryOptions) {

    console.log(`Deploying BionicFundRasing contract...`);


    const FundWithVestingContract = await ethers.getContractFactory("BionicFundRasing", opt);

    let funding = await FundWithVestingContract.deploy(CONFIG.tokenAddress, CONFIG.usdtAddress, CONFIG.bionicInvestorPass,
        CONFIG.vrfCoordinator, CONFIG.keyHash, CONFIG.subId, CONFIG.reqVRFPerWinner);

    return await funding.deployed();
}

async function verifyContract(contract: BionicFundRasing, utilsAddress: string, args: any) {
    let res;

    console.log(`Verifying Utils Contract at ${utilsAddress}`);
    res = await hre.run("verify:verify", {
        address: utilsAddress,//funding.address,
    });

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
            Utils: utilsAddress//utils.address
        }
    });
    console.log("Verified: ", res);
    return res;
}

main().then(console.log).catch(console.error);

