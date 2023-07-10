import { GetAccountParams, TokenboundClient, } from "@tokenbound/sdk";
import { Mumbai } from '@thirdweb-dev/chains'
import dotenv from 'dotenv';
import { ethers } from "hardhat";
import { getProviderFromRpcUrl } from "@thirdweb-dev/sdk";
dotenv.config()

async function main() {
    let token: GetAccountParams = { tokenId: '0', tokenContract: "0xfFD890eBB19277f59f9d0810D464Efd2775df08E" }
    let signer = new ethers.Wallet(process.env.PRIVATE_KEY || "", getProviderFromRpcUrl(process.env.MUMBAI_RPC || ""));

    // const tokenboundClient = new TokenboundClient({ signer, chainId: Mumbai.chainId, });
    const tokenboundClient = new TokenboundClient({
        signer,
        chainId: Mumbai.chainId,
        //@ts-ignore
        implementation: 0x34278B198852CCCD6Bd535eb08E45620dcf9ca3b,
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
//     return tokenBoundAccount
// }



main().then(console.log).catch(console.error)