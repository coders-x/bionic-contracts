import { Mumbai } from '@thirdweb-dev/chains'
import dotenv from 'dotenv';
import { PrivateKeyWallet, SmartWallet, SmartWalletConfig, WalletOptions, getAllSmartWallets } from "@thirdweb-dev/wallets";
import { NFT, SmartContract, ThirdwebSDK } from '@thirdweb-dev/sdk';
import { BaseContract, ethers } from 'ethers';
dotenv.config()

const chain = Mumbai;
const factoryAddress = "0x02101dfB77FDE026414827Fdc604ddAF224F0921";
const implementation: string = '0x34278B198852CCCD6Bd535eb08E45620dcf9ca3b'
const nftDropAddress: string = '0xfFD890eBB19277f59f9d0810D464Efd2775df08E'
const tokenAddress: string = '0x2e1AEAE3B9856b23cF5C9B30FEb0c3904A5db37E'
const thirdwebApiKey = process.env.THIRDWEB_API_KEY as string;

async function main() {
    try {
        if (!thirdwebApiKey) {
            throw new Error(
                "No API Key found, get one from https://thirdweb.com/dashboard"
            );
        }
        console.log("Running on", chain.slug, "with factory", factoryAddress);

        // Load or create personal wallet
        // here we generate LocalWallet that will be stored in wallet.json
        const personalWallet = new PrivateKeyWallet(process.env.PRIVATE_KEY as string, chain, thirdwebApiKey);
        // await personalWallet.load({
        //     strategy: "privateKey",
        //     encryption: false,
        // });
        const personalWalletAddress = await personalWallet.getAddress();
        console.log("Personal wallet address:", personalWalletAddress);


        const sdk = new ThirdwebSDK(chain);
        const contract = await sdk.getContract(nftDropAddress);
        const nft = await contract.erc721.get(0);


        // Configure the smart wallet
        const config: SmartWalletConfig = TBAConfig(nft);
        const smartWallet = new SmartWallet(config);
        await smartWallet.connect({
            personalWallet
        })
        let smart_address = await smartWallet.getAddress();

        console.log(`smart wallets for personal wallet`, smart_address);

    } catch (error) {
        console.error(error);
    }



}



main().then(console.log).catch(console.error)


function TBAConfig(token: NFT) {
    //Smart Wallet config object
    const config: WalletOptions<SmartWalletConfig> = {
        chain, // the chain where your smart wallet will be or is deployed
        factoryAddress, // your own deployed account factory address
        thirdwebApiKey: thirdwebApiKey, // obtained from the thirdweb dashboard
        gasless: true, // enable or disable gasless transactions
        factoryInfo: {
            createAccount: async (
                factory: SmartContract<BaseContract>,
                owner: string
            ) => {
                const account = factory.prepare("createAccount", [
                    implementation,
                    chain.chainId,
                    nftDropAddress,
                    token.metadata.id,
                    0,
                    ethers.utils.toUtf8Bytes("")
                ]);
                console.log("here", account);
                return account;
            }, // the factory method to call to create a new account
            getAccountAddress: async (
                factory: SmartContract<BaseContract>,
                owner: string
            ) => {
                return factory.call("account", [
                    implementation,
                    chain.chainId,
                    nftDropAddress,
                    token.metadata.id,
                    0
                ]);
            }, // the factory method to call to get the account address
        },
    };
    return config
    // return new SmartWallet(config);
}