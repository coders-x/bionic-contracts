import { GetAccountParams, TokenboundClient, } from "@tokenbound/sdk";
import { Mumbai } from '@thirdweb-dev/chains'
import dotenv from 'dotenv';
import { ethers } from "hardhat";
import { getProviderFromRpcUrl } from "@thirdweb-dev/sdk";
import { arbitrum as configInfo } from './config.json';
dotenv.config()

async function main() {
    let token: GetAccountParams = { tokenId: '0', tokenContract: configInfo.bionicInvestorPass as any }
    let signer = new ethers.Wallet(process.env.PRIVATE_KEY || "", getProviderFromRpcUrl(process.env.ARB_RPC || ""));

    // const tokenboundClient = new TokenboundClient({ signer, chainId: Mumbai.chainId, });
    const tokenboundClient = new TokenboundClient({
        signer,
        chainId: Mumbai.chainId,
        //@ts-ignore
        implementation: configInfo.tbaImpl,
    })

    const createAccount = tokenboundClient.getAccount(token);
    console.log(`address:${createAccount}`);

    //@ts-ignore
    const preparedAccount = await tokenboundClient.prepareCreateAccount(token);
    console.log(`preparedAccount:${preparedAccount}`);

    const account = await tokenboundClient.createAccount(token);
    console.log(`account:${account}`);


}

// export default async function newSmartWallet(token: any) {




//     //0x1a2...3b4cd
//     return BionicAccount
// }



main().then(console.log).catch(console.error)