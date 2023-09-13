import { GetAccountParams, TokenboundClient, } from "@tokenbound/sdk";
import { Mumbai } from '@thirdweb-dev/chains'
import dotenv from 'dotenv';
import { ethers, network } from "hardhat";
import { getProviderFromRpcUrl } from "@thirdweb-dev/sdk";
import { BigNumber, Signer } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { IERC20, TokenBoundAccount } from "../typechain-types";
dotenv.config()

interface User extends Signer{
    tokenId?:any
}
// mumbai
const BIP_CONTRACT="0xfFD890eBB19277f59f9d0810D464Efd2775df08E",ERC6551_REGISTRY_ADDR="0x02101dfB77FDE026414827Fdc604ddAF224F0921",
    TOKEN_BOUND_IMP_ADDR="0x55FcaE61dF06858DC8115bDDd21B622F0634d8Ac",BIONIC_LAUNCH_ADDR="0x0321a0e7f15577e6edc817f7c82aea17371573c1",
    BIONIC_TOKEN_ADDR="0xa0262DCE141a5C9574B2Ae8a56494aeFe7A28c8F", USDT_ADDR="0x2F7b97837F2D14bA2eD3a4B2282e259126A9b848";

const ENTRY_POINT = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";
// //goerli
// const BIP_CONTRACT="0xBE88D48C48946bE76337c26b7E2B6b37cfa17d34",ERC6551_REGISTRY_ADDR="0x02101dfB77FDE026414827Fdc604ddAF224F0921",
//     TOKEN_BOUND_IMP_ADDR="0x0Cf53c3cD24E536d5621d7E91d930CcFdfb5852A",BIONIC_LAUNCH_ADDR="0x73685c956Fdb9f2094E91462a00eBBeeA55cF4F1",
//     BIONIC_TOKEN_ADDR="0x2A8E08F7ca31551D13397Fcb74C9419c09387Af8", USDT_ADDR="0xe583769738b6dd4E7CAF8451050d1948BE717679";
let provider=getProviderFromRpcUrl(process.env.MUMBAI_RPC || "",{});
let owner = new ethers.Wallet(process.env.PRIVATE_KEY || "", provider);

async function main(level:number) {
    /*
    1. generate n numbers of users
    2. mint BIP NFT for them
    3. add a project to BionicFunding
    4.1. fund user smart wallets
    4.2. pledge users to the project
    5. draw for the lottery
    6. go claim 
    */
    let chainId=network.config.chainId||80001;
    let users:User[]=getSigners(1);
    let fundingContract = await ethers.getContractAt("BionicFundRasing",BIONIC_LAUNCH_ADDR);
    let usdtContract=await ethers.getContractAt("ERC20",USDT_ADDR);
    let bionicContract=await ethers.getContractAt("ERC20",BIONIC_TOKEN_ADDR);
    const TBAContract = await ethers.getContractFactory("TokenBoundAccount");
    let tokenBoundImpContract=await TBAContract.deploy(ENTRY_POINT, ERC6551_REGISTRY_ADDR);
    await tokenBoundImpContract.deployed();
    console.log(`tokenBoundAccount Implementation Deployed at ${tokenBoundImpContract.address}`);
    let abstractAccounts:TokenBoundAccount[]=[];
    const aa_addresses=[
        "0x33bfdB8C1ce6113BCD2A23262D74FA8Ba7508b8B",
        "0x14e5712Afe66BA0be8cFBeEB526b2fCc82e0d14C",
        "0x45FdECD8fdd7361Daf004C274240A0604E6C649E",
        "0x3DFBb9DEeb3478552a9aA3D2e827bE4E18a6ab65",
        "0x93A48Dcc435F9B6D2c39bf3a77c73d4898f2EB4e",
        "0xd20466A64f5C1C64ce6F77f8A3098F66963d9b5b",
        "0x89820a675e5D19306409935F80f21b22151Eb015",
        "0xEA76900a714060Eb51857587816a6E24B140CECe",
        "0xDe05170cd367f320c4712Bb25FF07D5529E25a68",
        "0xd77E947C267D0D04cccD93c95973426446c275d9",
        "0x53fa973B987DbDf6a7479Ac47cC58227855aE068",
        "0xd532190F51bc6B1FaDF9A47Aa852a3F254f217a0",
        "0x31150dbc756767c7FA58E3b726caAE02B18C9A73",
        "0x8504821fd23aeF6799a512c735f756c69E222a7D",
        "0x1F4cA47748016B034B3A6E4390c29Bc83fC5908F",
        "0x621f0B0F8E3bfbF2d3C1bbDE7b456aBB0E467910",
        "0x5251D29f488DB8389188b1c46DD0bDf7A4bb2dBE",
        "0x3b6D0CCd7DfB81cD5616f1c4fA680347378C09e2",
        "0xF8264A7e01195DDCf552Eb8d925a5aB25fEA0F90",
        "0x6Da6bCaBECFBa8ebBEeDbe8900Bf3C8FE3BbcD2F",
        "0x2bE509dB39F11959fEaBCEb955326b2dA2c36c2A",
        "0xC5aD426778B8bEEba0f903773ceADB8d0EE644e8",
        "0x461813314C71D6baCB99643Db5F244CEcbA07e1B",
        "0xD899E84Ca45c1b11cDAd95c9f29850425B3fC42D",
        "0xf262A2C0753c19E4CE7fDd43211779347bBF016d"
    ];

    /*** Mint BIP and Assign SmartWallet */
   if(level==1){
       level++;
       let bipContract=await ethers.getContractAt("BionicInvestorPass",BIP_CONTRACT);
       let tokenBoundContractRegistry = await ethers.getContractAt("ERC6551Registry",ERC6551_REGISTRY_ADDR);
    //    let tokenBoundImpContract=await ethers.getContractAt("TokenBoundAccount",tba.address)
        for (let i=0;i<users.length;i++) {
            const u=users[i];
            if ((await bipContract.balanceOf(u.getAddress())).lte(0)){
                //mint NFT
                let res=await (await bipContract.connect(owner).safeMint(await u.getAddress(),"https://SomeWHEREWithMETADATA")).wait(1);
                u.tokenId=res.events[0]?.args?.tokenId
            }else{
                u.tokenId=i+47
            }
            //create abstracted accounts
            let r = await(await tokenBoundContractRegistry.createAccount(tokenBoundImpContract.address,
                chainId as number, bipContract.address,
                u.tokenId, "0", [])).wait(1);
            let aa_addr = (await tokenBoundContractRegistry.account(tokenBoundImpContract.address,
                chainId as number, bipContract.address,
                u.tokenId, "0"));     
                console.log(`Minted ${u.tokenId} for address ${await u.getAddress()} and assigned ${aa_addr}`);
            let acc = await ethers.getContractAt("TokenBoundAccount", aa_addr);
            abstractAccounts.push(acc);
        }
        /**
            Minted 47 for address 0x71CB05EE1b1F506fF321Da3dac38f25c0c9ce6E1 and assigned 0x33bfdB8C1ce6113BCD2A23262D74FA8Ba7508b8B
            Minted 48 for address 0xC85C795D69e67De78B02ccAA51F03f4c56B2446e and assigned 0x14e5712Afe66BA0be8cFBeEB526b2fCc82e0d14C
            Minted 49 for address 0x7c7F5Da308D0d3bF663Aca84EFb6975322d6fEf9 and assigned 0x45FdECD8fdd7361Daf004C274240A0604E6C649E
            Minted 50 for address 0x41eb935B58b1Aa4c2E882d193fDa4c9Cb7E82953 and assigned 0x3DFBb9DEeb3478552a9aA3D2e827bE4E18a6ab65
            Minted 51 for address 0xAA41768a0B574D28739D80023CA8e840D9A40101 and assigned 0x93A48Dcc435F9B6D2c39bf3a77c73d4898f2EB4e
            Minted 52 for address 0xd86F0D3E6aFFa6DCc4AF89D36887d7E707B52FE9 and assigned 0xd20466A64f5C1C64ce6F77f8A3098F66963d9b5b
            Minted 53 for address 0x5cD498Ab11A58bEcA81D5aCb18d70F1d9D7cC525 and assigned 0x89820a675e5D19306409935F80f21b22151Eb015
            Minted 54 for address 0xd400C8056Da47668F52d4d88fe31628353a6c9eB and assigned 0xEA76900a714060Eb51857587816a6E24B140CECe
            Minted 55 for address 0xEd52b72814C8ae374F3793FFda598E329eaaFfA9 and assigned 0xDe05170cd367f320c4712Bb25FF07D5529E25a68
            Minted 56 for address 0xEf96F5204D591CE5FFB9936257bc7F3e4d087863 and assigned 0xd77E947C267D0D04cccD93c95973426446c275d9
            Minted 57 for address 0xE0f3639A21ec00040813b61dE60eCA60f0Ba0076 and assigned 0x53fa973B987DbDf6a7479Ac47cC58227855aE068
            Minted 58 for address 0xEeECa539A47C2a8f0fFE80aC11dEa67eb62C6A05 and assigned 0xd532190F51bc6B1FaDF9A47Aa852a3F254f217a0
            Minted 59 for address 0xBb32CEFfBB556b7773992fD4c7321b26B68bD338 and assigned 0x31150dbc756767c7FA58E3b726caAE02B18C9A73
            Minted 60 for address 0xFF1cd1616EC396A70892F93CEDf36757B3750250 and assigned 0x8504821fd23aeF6799a512c735f756c69E222a7D
            Minted 61 for address 0x758A1Be1Fc89FAfDdb59F76bD7c90026F491EAc7 and assigned 0x1F4cA47748016B034B3A6E4390c29Bc83fC5908F
            Minted 62 for address 0xe995a346d2c4a616D61409FCBaa48f59a51479A9 and assigned 0x621f0B0F8E3bfbF2d3C1bbDE7b456aBB0E467910
            Minted 63 for address 0xa09a36b7E6868AC0dB53a338a0bf7Fce0a966Fdc and assigned 0x5251D29f488DB8389188b1c46DD0bDf7A4bb2dBE
            Minted 64 for address 0x3E5790533849d721820732D789910F04Cb4e4B39 and assigned 0x3b6D0CCd7DfB81cD5616f1c4fA680347378C09e2
            Minted 65 for address 0xB8f1D0BAcBda1aB3d8133c7877a5D71D5A9cB301 and assigned 0xF8264A7e01195DDCf552Eb8d925a5aB25fEA0F90
            Minted 66 for address 0x0E4626cF54aD7D2Cc3A9e11137C3C9F63367d77f and assigned 0x6Da6bCaBECFBa8ebBEeDbe8900Bf3C8FE3BbcD2F
            Minted 67 for address 0x598859B60411c11F61E609A1281C5D65d62893B3 and assigned 0x2bE509dB39F11959fEaBCEb955326b2dA2c36c2A
            Minted 69 for address 0x0C97deD6D397c3fD3BE186E694967250a0F8FC7E and assigned 0xC5aD426778B8bEEba0f903773ceADB8d0EE644e8
            Minted 68 for address 0x1B18a178fa4A50f88601A74Ba96dEc8f03CDe71D and assigned 0x461813314C71D6baCB99643Db5F244CEcbA07e1B
            Minted 71 for address 0x9433fBE0f639A67124899804c728f8A81E37465c and assigned 0xD899E84Ca45c1b11cDAd95c9f29850425B3fC42D
            Minted 70 for address 0x6ff95C9BB28F3b74603681cf0F6730Af86BD97F5 and assigned 0xf262A2C0753c19E4CE7fDd43211779347bBF016d
        */
   }else{
    for (const a of aa_addresses) {
        let acc = await ethers.getContractAt("TokenBoundAccount", a);
        abstractAccounts.push(acc);
    }
   }

    /*** Fund */
    if(level==2){
        level++;
        for (let i=0;i<abstractAccounts.length;i++) {
            let res=await (await bionicContract.connect(owner).transfer(abstractAccounts[i].address,50000)).wait();
            res=await (await usdtContract.connect(owner).transfer(abstractAccounts[i].address,5000)).wait();
            await (await owner.sendTransaction({value:80000000000000,to:users[i].getAddress()})).wait()
            console.log(`Transferred ${res.events[0]?.args.amount}USDT+${80000000000000}wei to ${res.events[0]?.args.to}`,res.events[0]?.args.from);
        }
    }


    

   /*** Add Project */
   let pid=4,pledgeAmount=1000;
   if(level==3){
    level++;
    let pledgeEnding=new Date();
    pledgeEnding.setHours(pledgeEnding.getHours()+3)
    let tokenAllocationStartTime=new Date(pledgeEnding.getTime());
    tokenAllocationStartTime.setHours(tokenAllocationStartTime.getHours()+3);
    console.log(`now ${Date.now()/1000|0} and 3 hours later ${pledgeEnding.getTime()/1000|0} and token allocation ${tokenAllocationStartTime.getTime()/1000|0}`);
    let r=await(await fundingContract.connect(owner).add(BIONIC_TOKEN_ADDR,Date.now()/1000|0,pledgeEnding.getTime()/1000|0,1000,10,tokenAllocationStartTime.getTime()/1000|0,10,1e10,[5,10,8])).wait(1);
    pid=r?.events[1].args?.pid;
    console.log(pid);
   }


   /*** Pledge */
   if(level==4){
    level++;
    const deadline = ethers.constants.MaxUint256;
    for (let i = 0; i < users.length; i++) {
        const { v, r, s } = await getCurrencyPermitSignature(
            users[i] as SignerWithAddress,
            abstractAccounts[i],
            usdtContract,
            fundingContract.address,
            BigNumber.from(pledgeAmount),
            deadline
        );
        let raw = fundingContract.interface.encodeFunctionData("pledge", [pid, pledgeAmount, deadline, v, r, s]);
        let feeData=await provider.getFeeData()
        try {
            let res=await(await abstractAccounts[i].connect(users[i]).executeCall(fundingContract.address, 0, raw,{gasLimit:3000000, gasPrice: feeData.gasPrice||undefined })).wait(1);
            console.log(res.events);
            console.log(res.logs);
        } catch (err) {
            console.error(err.receipt.logs);
        }
    }
   }





}






const getSigners = (amount: number): Signer[] => {
    const mnemonic = "announce room limb pattern dry unit scale effort smooth jazz weasel alcohol";
    const signers: Signer[] = []
    for (let i = 0; i < amount; i++) {
        const walletMnemonic = ethers.Wallet.fromMnemonic(mnemonic,`m/44'/60'/0'/0/${i}`)
        let signer = new ethers.Wallet(walletMnemonic.privateKey || "", getProviderFromRpcUrl(process.env.MUMBAI_RPC || "",{}));
        signers.push(signer)
    }
    return signers
}

async function getCurrencyPermitSignature(signer: SignerWithAddress, account: TokenBoundAccount, currency: IERC20, spender: string, value: BigNumber, deadline: BigNumber = ethers.constants.MaxUint256) {
    const [nonce, name, version, chainId] = await Promise.all([
        account.nonce(),
        "BionicAccount",
        "1",
        80001
    ])



    return ethers.utils.splitSignature(
        await signer._signTypedData(
            {
                name,
                version,
                chainId,
                verifyingContract: account.address,
            },
            {
                Permit: [
                    {
                        name: "currency",
                        type: "address",
                    },
                    {
                        name: "spender",
                        type: "address",
                    },
                    {
                        name: "value",
                        type: "uint256",
                    },
                    {
                        name: "nonce",
                        type: "uint256",
                    },
                    {
                        name: "deadline",
                        type: "uint256",
                    },
                ],
            },
            {
                currency: currency.address,
                spender,
                value,
                nonce,
                deadline,
            }
        )
    )
}

main(1).then(console.log).catch(console.error)
