import dotenv from 'dotenv';
import { ethers } from "hardhat";
import hre from "hardhat";
import { FactoryOptions } from 'hardhat/types';
import { arbitrum as CONFIG } from './config.json';
import { BionicTokenDistributor } from '../typechain-types';
dotenv.config()

async function main() {
    let contract = await deployContract({});

    // let contract = await ethers.getContractAt("BionicTokenDistributor", CONFIG.bionicDistributor);

    console.log(`deployed BTD at ${contract.address}`)

    await verifyContract(contract, []);
}


async function deployContract(opt: FactoryOptions) {
    console.log(`Deploying BionicTokenDistributor contract...`);


    const BionicTokenDistributorContract = await ethers.getContractFactory("BionicTokenDistributor", opt);

    let funding = await BionicTokenDistributorContract.deploy();

    return await funding.deployed();
}

async function verifyContract(contract: BionicTokenDistributor, args: any) {
    let res;
    console.log(`Verifying BTB Contract at ${contract.address}`);
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

