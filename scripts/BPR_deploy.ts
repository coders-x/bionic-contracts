import dotenv from 'dotenv';
import { ethers, upgrades } from "hardhat";
import hre from "hardhat";
import { FactoryOptions } from 'hardhat/types';
import { arbitrum as CONFIG } from './config.json';
import { BionicPoolRegistry } from '../typechain-types';
dotenv.config()

async function main() {
    let contract = await deployContract({});

    // let contract = await ethers.getContractAt("BionicPoolRegistry", CONFIG.bionicLaunchPad);

    console.log(`deployed BPR at ${contract.address}`)
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
    const args = [
        CONFIG.tokenAddress, CONFIG.usdtAddress, CONFIG.bionicInvestorPass, CONFIG.vrfCoordinator,
        CONFIG.keyHash, CONFIG.subId, CONFIG.reqVRFPerWinner
    ];
    let BRPContract = await upgrades.deployProxy(BionicPoolRegistryContract, args, {
        initializer: "initialize",
    });


    return await BRPContract.deployed() as BionicPoolRegistry;
}

async function verifyContract(contract: BionicPoolRegistry, args: any) {
    let res;


    // let treasuryAddress = await contract.treasury();
    // console.log(`Verifying Treasury Contract at ${treasuryAddress}`);
    // res = await hre.run("verify:verify", {
    //     address: treasuryAddress,
    //     args: [contract.address],//funding.address,
    // });

    // let claimAddress = await contract.distributor();
    // console.log(`Verifying ClaimFund Contract at ${claimAddress}`);
    // res = await hre.run("verify:verify", {
    //     address: claimAddress
    // });

    console.log(`Verifying BPR Contract at ${contract.address}`);
    res = await hre.run("verify:verify", {
        address: contract.address,//funding.address,
        // constructorArguments: args,

        libraries: {
            // Utils: utilsAddress//utils.address
        }
    });
    console.log("Verified: ", res);
    return res;
}

main().then(console.log).catch(console.error);

