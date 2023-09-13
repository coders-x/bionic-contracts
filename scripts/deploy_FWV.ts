import { verify } from '@thirdweb-dev/sdk';
import dotenv from 'dotenv';
import { ethers } from "hardhat";
import hre from "hardhat";
import { FactoryOptions } from 'hardhat/types';
dotenv.config()
const CONFIG = {
    name: "mumbai",
    keyHash: "0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f",
    vrfCoordinator: "0x7a1bac17ccc5b313516c5e16fb24f7659aa5ebed",
    tokenAddress:"0xa0262DCE141a5C9574B2Ae8a56494aeFe7A28c8F",
    usdtAddress:"0x2F7b97837F2D14bA2eD3a4B2282e259126A9b848",
    bionicInvestorPass:"0xfFD890eBB19277f59f9d0810D464Efd2775df08E",
    subId:5682,
    cbGasLimit:50000,
    reqVRFPerWinner:false,
};

async function main() {
    const UtilsLib = await ethers.getContractFactory("Utils");
    const utils = await UtilsLib.deploy();
    await utils.deployed();
    console.log(`deployed utils at ${utils.address}`)
    let contract=await deployContract({
        libraries: {
            Utils: utils.address,//"0x32a507b82822c194aB25931bE5d72772aA4F9F3b"
        }
    })
    console.log(`deployed fwv at ${contract.address}`)
    await verifyContract(contract.address, utils.address,[
        CONFIG.tokenAddress, CONFIG.usdtAddress, CONFIG.bionicInvestorPass, CONFIG.vrfCoordinator, CONFIG.keyHash, 
        CONFIG.subId, CONFIG.cbGasLimit, CONFIG.reqVRFPerWinner
    ]);


    // await verifyContract("0xf6e470B6A6433880a97f80e7a841644237518259","0x8956E81d76FDdAbF0de54D8Da0d06c2474DeA340",[
    //     CONFIG.tokenAddress, CONFIG.usdtAddress, CONFIG.bionicInvestorPass, CONFIG.vrfCoordinator, CONFIG.keyHash, 
    //     CONFIG.subId, CONFIG.cbGasLimit, CONFIG.reqVRFPerWinner
    // ]);
}


async function deployContract(opt:FactoryOptions){

      console.log(`Deploying BionicFundRasing contract...`);


    const FundWithVestingContract = await ethers.getContractFactory("BionicFundRasing", opt);

    let funding=await FundWithVestingContract.deploy(CONFIG.tokenAddress, CONFIG.usdtAddress, CONFIG.bionicInvestorPass, 
        CONFIG.vrfCoordinator, CONFIG.keyHash, CONFIG.subId, CONFIG.cbGasLimit, CONFIG.reqVRFPerWinner);

    return await funding.deployed();
}

async function verifyContract(contractAddress:string, utilsAddress:string,args:any){
    let res;
    
    console.log(`Verifying Utils Contract at ${utilsAddress}`);
     res= await hre.run("verify:verify", {
        address: utilsAddress,//funding.address,
    });

    console.log(`Verifying FWV Contract at ${contractAddress}`);
    res= await hre.run("verify:verify", {
        address: contractAddress,//funding.address,
        constructorArguments: args,
        libraries: {
            Utils: utilsAddress//utils.address
        }
      });
    console.log("Verified: ",res);
    return res;
}

main().then(console.log).catch(console.error);

