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

const BIP_CONTRACT="0xfFD890eBB19277f59f9d0810D464Efd2775df08E",ERC6551_REGISTRY_ADDR="0x02101dfB77FDE026414827Fdc604ddAF224F0921",
    TOKEN_BOUND_IMP_ADDR="0x34278B198852CCCD6Bd535eb08E45620dcf9ca3b",BIONIC_LAUNCH_ADDR="0xE34638197c4cac3c6E1fC3E666df5F994376B7Ab",
    BIONIC_TOKEN_ADDR="0xa0262DCE141a5C9574B2Ae8a56494aeFe7A28c8F", USDT_ADDR="0x2F7b97837F2D14bA2eD3a4B2282e259126A9b848";

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
    let owner = new ethers.Wallet(process.env.PRIVATE_KEY || "", getProviderFromRpcUrl(process.env.MUMBAI_RPC || "",{}));
    let users:User[]=getSigners(25);
    let fundingContract = await ethers.getContractAt("BionicFundRasing",BIONIC_LAUNCH_ADDR);
    let usdtContract=await ethers.getContractAt("ERC20",USDT_ADDR);
    let abstractAccounts:TokenBoundAccount[]=[];
    const aa_addresses=[
        "0x2cC07360D60e7E23CcaFa4704C2493Db42fda0cb",
        "0xDd9fcE951867F73e210923431Ee4965916bba9A0",
        "0xFfc0c21C158Cc08661De0c4d8B066aea1c89C4c2",
        "0xc9A14AC65435a3BBFbb51237b455b3cd15a8F219",
        "0x6c43bB579F87CE9ff8F26e5548302d457B615a02",
        "0x6d9D80c54Ef4f021aFaa55B0D241957fEBe92049",
        "0xCb8181bbfCA94E1041d3Aa23c48714938E20fCc9",
        "0x12535b95F7791feCDE3a1f6A10cC8c79Cd4c6dde",
        "0xbD0A5E2143Ae92F8FBD67AEa4e248283A52DcDD9",
        "0xdC57e3eB0f0F22a92517FBeF84F7502998a8ec9f",
        "0xc8E00a3BdB315Eb9B5a9B4C27680767fFA3aB370",
        "0x9c1c92A20e5510a6f1D77dC07D5278dC47265019",
        "0x6CB97fD61b67b462F501931bbccc1b664A2779Da",
        "0x45360eabF04F903b22A849cF72EE858379CA1A14",
        "0x4d7E0D22299CdfD6904E7fcA939AE127a82e6D63",
        "0xB670247ef5701109830290b0B927431a4f409af8",
        "0x4Dc7554bc1E8Cb84b16EeBdE26526EA76A7864ab",
        "0x120b93DE8c9449C875beBc87A900CDD46527a0B2",
        "0x6De39b723b9f3a9Dd8be786aC2264ad373870B00",
        "0x1140846104Ce05161880206f536c7CCd7b3138FB",
        "0x0F140f5A550E03c510a6f6D5521a274054c47676",
        "0xB3E96a8C98Dd0eb572CfDb5F4C4D2D4b7A9b29B2",
        "0x1c8206adA739B7b033592D279646b8aCa1A76b0B",
        "0xF2a8aff42b257f1A80402AA85F9E72ee98219B57",
        "0x286Db404026B1c8950Fd06B82e1502AdC55EC572",
    ];

    /*** Mint BIP and Assign SmartWallet */
   if(level==1){
       level++;
       let bipContract=await ethers.getContractAt("BionicInvestorPass",BIP_CONTRACT);
       let tokenBoundContractRegistry = await ethers.getContractAt("ERC6551Registry",ERC6551_REGISTRY_ADDR);
       let tokenBoundImpContract=await ethers.getContractAt("TokenBoundAccount",TOKEN_BOUND_IMP_ADDR)
        for (const u of users) {
            if ((await bipContract.balanceOf(u.getAddress())).lt(0)){
                //mint NFT
                let res=await (await bipContract.connect(owner).safeMint(await u.getAddress(),"https://SomeWHEREWithMETADATA")).wait(1);
                u.tokenId=res.events[0]?.args.tokenId;


                //create abstracted accounts
                let r = await(await tokenBoundContractRegistry.createAccount(tokenBoundImpContract.address,
                    network.config.chainId as number, bipContract.address,
                    u.tokenId, "0", [])).wait(1);

            
            }
            let aa_addr = await(await tokenBoundContractRegistry.account(tokenBoundImpContract.address,
                network.config.chainId as number, bipContract.address,
                u.tokenId, "0"));     
                console.log(`Minted ${u.tokenId} for address ${await u.getAddress()} and assigned ${aa_addr}`);
            let acc = await ethers.getContractAt("TokenBoundAccount", aa_addr);
            abstractAccounts.push(acc);
        }
        /**
         *  Minted 47 for address 0x71CB05EE1b1F506fF321Da3dac38f25c0c9ce6E1 and assigned 0x2cC07360D60e7E23CcaFa4704C2493Db42fda0cb
            Minted 48 for address 0xC85C795D69e67De78B02ccAA51F03f4c56B2446e and assigned 0xDd9fcE951867F73e210923431Ee4965916bba9A0
            Minted 49 for address 0x7c7F5Da308D0d3bF663Aca84EFb6975322d6fEf9 and assigned 0xFfc0c21C158Cc08661De0c4d8B066aea1c89C4c2
            Minted 50 for address 0x41eb935B58b1Aa4c2E882d193fDa4c9Cb7E82953 and assigned 0xc9A14AC65435a3BBFbb51237b455b3cd15a8F219
            Minted 51 for address 0xAA41768a0B574D28739D80023CA8e840D9A40101 and assigned 0x6c43bB579F87CE9ff8F26e5548302d457B615a02
            Minted 52 for address 0xd86F0D3E6aFFa6DCc4AF89D36887d7E707B52FE9 and assigned 0x6d9D80c54Ef4f021aFaa55B0D241957fEBe92049
            Minted 53 for address 0x5cD498Ab11A58bEcA81D5aCb18d70F1d9D7cC525 and assigned 0xCb8181bbfCA94E1041d3Aa23c48714938E20fCc9
            Minted 54 for address 0xd400C8056Da47668F52d4d88fe31628353a6c9eB and assigned 0x12535b95F7791feCDE3a1f6A10cC8c79Cd4c6dde
            Minted 55 for address 0xEd52b72814C8ae374F3793FFda598E329eaaFfA9 and assigned 0xbD0A5E2143Ae92F8FBD67AEa4e248283A52DcDD9
            Minted 56 for address 0xEf96F5204D591CE5FFB9936257bc7F3e4d087863 and assigned 0xdC57e3eB0f0F22a92517FBeF84F7502998a8ec9f
            Minted 57 for address 0xE0f3639A21ec00040813b61dE60eCA60f0Ba0076 and assigned 0xc8E00a3BdB315Eb9B5a9B4C27680767fFA3aB370
            Minted 58 for address 0xEeECa539A47C2a8f0fFE80aC11dEa67eb62C6A05 and assigned 0x9c1c92A20e5510a6f1D77dC07D5278dC47265019
            Minted 59 for address 0xBb32CEFfBB556b7773992fD4c7321b26B68bD338 and assigned 0x6CB97fD61b67b462F501931bbccc1b664A2779Da
            Minted 60 for address 0xFF1cd1616EC396A70892F93CEDf36757B3750250 and assigned 0x45360eabF04F903b22A849cF72EE858379CA1A14
            Minted 61 for address 0x758A1Be1Fc89FAfDdb59F76bD7c90026F491EAc7 and assigned 0x4d7E0D22299CdfD6904E7fcA939AE127a82e6D63
            Minted 62 for address 0xe995a346d2c4a616D61409FCBaa48f59a51479A9 and assigned 0xB670247ef5701109830290b0B927431a4f409af8
            Minted 63 for address 0xa09a36b7E6868AC0dB53a338a0bf7Fce0a966Fdc and assigned 0x4Dc7554bc1E8Cb84b16EeBdE26526EA76A7864ab
            Minted 64 for address 0x3E5790533849d721820732D789910F04Cb4e4B39 and assigned 0x120b93DE8c9449C875beBc87A900CDD46527a0B2
            Minted 65 for address 0xB8f1D0BAcBda1aB3d8133c7877a5D71D5A9cB301 and assigned 0x6De39b723b9f3a9Dd8be786aC2264ad373870B00
            Minted 66 for address 0x0E4626cF54aD7D2Cc3A9e11137C3C9F63367d77f and assigned 0x1140846104Ce05161880206f536c7CCd7b3138FB
            Minted 67 for address 0x598859B60411c11F61E609A1281C5D65d62893B3 and assigned 0x0F140f5A550E03c510a6f6D5521a274054c47676
            Minted 68 for address 0x1B18a178fa4A50f88601A74Ba96dEc8f03CDe71D and assigned 0xB3E96a8C98Dd0eb572CfDb5F4C4D2D4b7A9b29B2
            Minted 69 for address 0x0C97deD6D397c3fD3BE186E694967250a0F8FC7E and assigned 0x1c8206adA739B7b033592D279646b8aCa1A76b0B
            Minted 70 for address 0x6ff95C9BB28F3b74603681cf0F6730Af86BD97F5 and assigned 0xF2a8aff42b257f1A80402AA85F9E72ee98219B57
            Minted 71 for address 0x9433fBE0f639A67124899804c728f8A81E37465c and assigned 0x286Db404026B1c8950Fd06B82e1502AdC55EC572
        */
   }else{
    for (const a of aa_addresses) {
        let acc = await ethers.getContractAt("TokenBoundAccount", a);
        abstractAccounts.push(acc);
    }
   }

   /*** Add Project */
   let pid=0,pledgeAmount=1000;
   if(level==2){
    level++;
    let pledgeEnding=new Date();
    pledgeEnding.setHours(pledgeEnding.getHours()+3)
    let tokenAllocationStartTime=new Date(pledgeEnding.getTime());
    tokenAllocationStartTime.setHours(tokenAllocationStartTime.getHours()+3);
    // console.log(`now ${Date.now()/1000|0} and 3 hours later ${pledgeEnding.getTime()/1000|0} and token allocation ${tokenAllocationStartTime.getTime()/1000|0}`);
    let res=await(await fundingContract.add(BIONIC_TOKEN_ADDR,Date.now()/1000|0,pledgeEnding.getTime()/1000|0,1000,10,tokenAllocationStartTime.getTime()/1000|0,10,1e10,[5,10,8])).wait(1);
    pid=res.events[1].args?.pid;
    console.log(pid);
   }

   /*** Fund */
   if(level==3){
    level++;
    for (const u of aa_addresses) {
        let res=await (await usdtContract.transfer(u,5000)).wait(1);
        console.log(`Transferred ${res.events[0]?.args.amount} to ${res.events[0]?.args.to}`,res.events[0]?.args.from);
    }
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
        let raw = fundingContract.interface.encodeFunctionData("pledge", [0, pledgeAmount, deadline, v, r, s]);
        let res=await(await abstractAccounts[i].connect(aa_addresses[i]).executeCall(fundingContract.address, 0, raw)).wait(1);
        console.log(res.events);
    }
   }





}




main(4).then(console.log).catch(console.error)


const getSigners = (amount: number): Signer[] => {
    const mnemonic = "announce room limb pattern dry unit scale effort smooth jazz weasel alcohol";
    const signers: Signer[] = []
    for (let i = 0; i < amount; i++) {
        const walletMnemonic = ethers.Wallet.fromMnemonic(mnemonic,`m/44'/60'/0'/0/${i}`)
        signers.push(walletMnemonic)
    }
    return signers
}

async function getCurrencyPermitSignature(signer: SignerWithAddress, account: TokenBoundAccount, currency: IERC20, spender: string, value: BigNumber, deadline: BigNumber = ethers.constants.MaxUint256) {
    const [nonce, name, version, chainId] = await Promise.all([
        account.nonces(signer.address),
        "BionicAccount",
        "1",
        signer.getChainId(),
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

