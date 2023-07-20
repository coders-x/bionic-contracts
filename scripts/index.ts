import { Mumbai } from '@thirdweb-dev/chains'
import dotenv from 'dotenv';
import { PrivateKeyWallet, SmartWallet, SmartWalletConfig, WalletOptions, getAllSmartWallets, isSmartWalletDeployed } from "@thirdweb-dev/wallets";
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


        let sdk = new ThirdwebSDK(chain);
        const contract = await sdk.getContract(nftDropAddress);
        const nft = await contract.erc721.get(0);


        // Configure the smart wallet
        const config: SmartWalletConfig = TBAConfig(nft);

        // NOT WORKING FOR ERC6551 Factory doesn't support this
        // // [Optional] get all the smart wallets associated with the personal wallet
        // const accounts = await getAllSmartWallets(
        //     chain,
        //     factoryAddress,
        //     personalWalletAddress
        // );
        // console.log(`Associated smart wallets for personal wallet`, accounts);

        // [Optional] check if the smart wallet is deployed for the personal wallet
        // const isWalletDeployed = await isSmartWalletDeployed(
        //     chain,
        //     factoryAddress,
        //     personalWalletAddress
        // );
        // console.log(`Is smart wallet deployed?`, isWalletDeployed);

        // Connect the smart wallet
        const smartWallet = new SmartWallet(config);
        await smartWallet.connect({
            personalWallet,
        });

        // now use the SDK normally to perform transactions with the smart wallet
        sdk = await ThirdwebSDK.fromWallet(smartWallet, chain);

        console.log("Smart Account addr:", await sdk.wallet.getAddress());
        console.log("balance (eth):", (await sdk.wallet.balance()).displayValue);

        // Bionic ERC20 Token
        const bionicContract = await sdk.getContract(
            "0xa0262DCE141a5C9574B2Ae8a56494aeFe7A28c8F"
        );
        const tokenBalance = await bionicContract.erc20.balance();
        console.log("ERC20 Bionic token balance:", tokenBalance.displayValue);
        const tx = await bionicContract.erc20.transfer("0x534136eE30A39B731802DB8C027C76d95B35E37D", 1);
        console.log("Sent 1 Bionic, tx hash:", tx.receipt.transactionHash);



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