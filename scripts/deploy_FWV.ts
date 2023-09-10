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
    bionicInvsestorPass:"0xfFD890eBB19277f59f9d0810D464Efd2775df08E",
    subId:5682,
    cbGasLimit:50000,
    reqVRFPerWinner:false,
};

async function main() {

    // const IterableMappingLib = await ethers.getContractFactory("IterableMapping");
    // const lib = await IterableMappingLib.deploy();
    // await lib.deployed();
    // const UtilsLib = await ethers.getContractFactory("Utils");
    // const utils = await UtilsLib.deploy();
    // await utils.deployed();

    // let contract=deployContract({
    //     libraries: {
    //         IterableMapping: "0x8Fca87f23B586b8264722e88c7858F8c096039a4",//lib.address,
    //         Utils: "0xE1fec8E94AeEF98Ba54fac5e3CcEe9a3dEF27350"//utils.address
    //     }
    // })



      await verifyContract("0x651984DAbe103Fbede438BD7bD6787bCB0629B1e","0x8Fca87f23B586b8264722e88c7858F8c096039a4","0xE1fec8E94AeEF98Ba54fac5e3CcEe9a3dEF27350",[
        CONFIG.tokenAddress, CONFIG.usdtAddress, CONFIG.bionicInvsestorPass, CONFIG.vrfCoordinator, CONFIG.keyHash, 
        CONFIG.subId, CONFIG.cbGasLimit, CONFIG.reqVRFPerWinner
        ]);
}


async function deployContract(opt:FactoryOptions){

  
    console.log(`Deploying BionicFundRasing contract...`);


    const FundWithVestingContract = await ethers.getContractFactory("BionicFundRasing", opt);

    let funding=await FundWithVestingContract.deploy(CONFIG.tokenAddress, CONFIG.usdtAddress, CONFIG.bionicInvsestorPass, 
        CONFIG.vrfCoordinator, CONFIG.keyHash, CONFIG.subId, CONFIG.cbGasLimit, CONFIG.reqVRFPerWinner);

    return await funding.deployed();
}

async function verifyContract(contractAddress:string,iterableMappingAddress:string, utilsAddress:string,args:any){
    console.log(`Verifying Contract at ${}`);
    let res= await hre.run("verify:verify", {
        address: contractAddress,//funding.address,
        constructorArguments: args,
        libraries: {
            IterableMapping: iterableMappingAddress,//lib.address,
            Utils: utilsAddress//utils.address
        }
      });
    console.log("Verified: ",res)
    return res;
}

main().then(console.log).catch(console.error)

