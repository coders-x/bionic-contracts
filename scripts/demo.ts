import dotenv from "dotenv";
import { ethers, network } from "hardhat";
import { getProviderFromRpcUrl } from "@thirdweb-dev/sdk";
import { BigNumber, Contract, Signer } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { IERC20, TokenBoundAccount } from "../typechain-types";
import { goerli as configInfo } from './config.json';

dotenv.config();

interface User extends Signer {
    tokenId?: any;
}
// mumbai
const BIP_CONTRACT = configInfo.bionicInvestorPass,
    TOKEN_BOUND_IMP_ADDR = configInfo.tbaImpl,
    BIONIC_LAUNCH_ADDR = configInfo.bionicLaunchPad,
    BIONIC_TOKEN_ADDR = configInfo.tokenAddress,
    USDT_ADDR = configInfo.usdtAddress;

//     // mumbai
// const BIP_CONTRACT="0xfFD890eBB19277f59f9d0810D464Efd2775df08E", TOKEN_BOUND_IMP_ADDR="0xC0dC4Da60478e13e691E32261f5d63Fd3cDC075d",BIONIC_LAUNCH_ADDR="0x748b9d63815015A04057688c437B20e84ccD1b8E",
//     BIONIC_TOKEN_ADDR="0xa0262DCE141a5C9574B2Ae8a56494aeFe7A28c8F", USDT_ADDR="0x2F7b97837F2D14bA2eD3a4B2282e259126A9b848";

const ENTRY_POINT = configInfo.entryPoint,
    ERC6551_REGISTRY_ADDR = configInfo.erc6551Reg;
// //goerli
// const BIP_CONTRACT="0xA9652d7d33FacC265be044055B7392A261c3efD8",ERC6551_REGISTRY_ADDR="0x02101dfB77FDE026414827Fdc604ddAF224F0921",
//     TOKEN_BOUND_IMP_ADDR="0x55FcaE61dF06858DC8115bDDd21B622F0634d8Ac",BIONIC_LAUNCH_ADDR="0x96Ccc65AD06205d8Ce83368755190A69213f0B94",
//     BIONIC_TOKEN_ADDR="0x2111efE6FB546EDdF98A293BFEbEa50e594211Ef", USDT_ADDR="0x2F7b97837F2D14bA2eD3a4B2282e259126A9b848";
let provider = getProviderFromRpcUrl(process.env.RPC_URL || "", {});
let owner = new ethers.Wallet(process.env.PRIVATE_KEY || "", provider);

async function main(level: number, pid: number = 0) {
    /*
      1. generate n numbers of users
      2. mint BIP NFT for them
      3. add a project to BionicFunding
      4.1. fund user smart wallets
      4.2. pledge users to the project
      5. draw for the lottery
      6. go claim 
      */
    let chainId = network.config.chainId || 80001;
    let users: User[] = getSigners(20);
    let fundingContract = await ethers.getContractAt(
        "BionicFundRasing",
        BIONIC_LAUNCH_ADDR
    );
    let usdtContract = await ethers.getContractAt("ERC20", USDT_ADDR);
    let bionicContract = await ethers.getContractAt("ERC20", BIONIC_TOKEN_ADDR);
    // const TBAContract = await ethers.getContractFactory("TokenBoundAccount");
    // let tokenBoundImpContract=await TBAContract.deploy(ENTRY_POINT, ERC6551_REGISTRY_ADDR);
    // await tokenBoundImpContract.deployed();
    // console.log(`tokenBoundAccount Implementation Deployed at ${tokenBoundImpContract.address}`);
    let abstractAccounts: TokenBoundAccount[] = [];
    //goerli
    const aa_addresses = [
        "0xEb061CC58a39483A26089d7Ce514a4CFB50881E5",
        "0x29A9194b77292b4875f8D070C819f23A90Cf478E",
        "0x4f7805C1Ef304405840B250B69E4d16b5450f9f2",
        "0x43daA91B9b339DFD8daE48d824e46b060e012135",
        "0x81A8a47c2b06A47C594C5C3711d9C8ddd3B78d8f",
        "0xc92cf3FBEED66aDa7617Acd998Ce70533C552fdA",
        "0xe23EF0D205C42bE572CC016265978EF111d010ee",
        "0x247408c3C21C28756F29990380d518246d1a88f3",
        "0x234Ec7c68743F1614f58bFF1DA15BA9A24567D49",
        "0xbE87210E920C773F6F9438FA42B804D204f9222d",
        "0xfA8f3B8Cd42a7054c9BA7d786f526Ad4758F1446",
        "0x432F3bBFB0b09e07554559e7706b08c11bc121ec",
        "0x1E5945182718bfF7B85689edDD51cd32a1c9Fad8",
        "0x93ed97C8d3b28192a42864668F1F7DB7661Ee998",
        "0x15CA19E0de7E5F2CCB07e4989EF3b030eE938551",
        "0xD75621624811Ff6D6BCff1048bAc90FE219b4A9d",
        "0x74af39f573Dc681deBCfA58c2863Aa44F23D3c99",
        "0x28310d3c8Ff416c0FC158AAC741b73253dBA80F5",
        "0x83eCD224c33fD5D7713597fD0869064d9C81e9a7",
        "0x7b42735dc0923eDD8f99f522a38503e1653bc6Ce",
    ];

    // const aa_addresses=[
    //     "0xdeE730aFb19d80BD159E05F4BBFbd4EdD6178e6d",
    //     "0x14e5712Afe66BA0be8cFBeEB526b2fCc82e0d14C",
    //     "0x45FdECD8fdd7361Daf004C274240A0604E6C649E",
    //     "0x3DFBb9DEeb3478552a9aA3D2e827bE4E18a6ab65",
    //     "0x93A48Dcc435F9B6D2c39bf3a77c73d4898f2EB4e",
    //     "0xd20466A64f5C1C64ce6F77f8A3098F66963d9b5b",
    //     "0x89820a675e5D19306409935F80f21b22151Eb015",
    //     "0xEA76900a714060Eb51857587816a6E24B140CECe",
    //     "0xDe05170cd367f320c4712Bb25FF07D5529E25a68",
    //     "0xd77E947C267D0D04cccD93c95973426446c275d9",
    //     "0x53fa973B987DbDf6a7479Ac47cC58227855aE068",
    //     "0xd532190F51bc6B1FaDF9A47Aa852a3F254f217a0",
    //     "0x31150dbc756767c7FA58E3b726caAE02B18C9A73",
    //     "0x8504821fd23aeF6799a512c735f756c69E222a7D",
    //     "0x1F4cA47748016B034B3A6E4390c29Bc83fC5908F",
    //     "0x621f0B0F8E3bfbF2d3C1bbDE7b456aBB0E467910",
    //     "0x5251D29f488DB8389188b1c46DD0bDf7A4bb2dBE",
    //     "0x3b6D0CCd7DfB81cD5616f1c4fA680347378C09e2",
    //     "0xF8264A7e01195DDCf552Eb8d925a5aB25fEA0F90",
    //     "0x6Da6bCaBECFBa8ebBEeDbe8900Bf3C8FE3BbcD2F",
    //     "0x2bE509dB39F11959fEaBCEb955326b2dA2c36c2A",
    //     "0xC5aD426778B8bEEba0f903773ceADB8d0EE644e8",
    //     "0x461813314C71D6baCB99643Db5F244CEcbA07e1B",
    //     "0xD899E84Ca45c1b11cDAd95c9f29850425B3fC42D",
    //     "0xf262A2C0753c19E4CE7fDd43211779347bBF016d"
    // ];

    /*** Mint BIP and Assign SmartWallet */
    if (level == 1) {
        level++;
        let bipContract = await ethers.getContractAt(
            "BionicInvestorPass",
            BIP_CONTRACT
        );
        let tokenBoundContractRegistry = await ethers.getContractAt(
            "ERC6551Registry",
            ERC6551_REGISTRY_ADDR
        );
        let tokenBoundImpContract = await ethers.getContractAt(
            "TokenBoundAccount",
            TOKEN_BOUND_IMP_ADDR
        );
        for (let i = 0; i < users.length; i++) {
            const u = users[i];
            if ((await bipContract.balanceOf(u.getAddress())).lte(0)) {
                //mint NFT
                let res = await (
                    await bipContract
                        .connect(owner)
                        .safeMint(await u.getAddress(), "https://SomeWHEREWithMETADATA")
                ).wait(1);
                u.tokenId = res.events[0]?.args?.tokenId;
            } else {
                u.tokenId = i;
            }
            //create abstracted accounts
            let r = await (
                await tokenBoundContractRegistry.createAccount(
                    tokenBoundImpContract.address,
                    chainId as number,
                    bipContract.address,
                    u.tokenId,
                    "0",
                    []
                )
            ).wait(1);
            let aa_addr = await tokenBoundContractRegistry.account(
                tokenBoundImpContract.address,
                chainId as number,
                bipContract.address,
                u.tokenId,
                "0"
            );
            console.log(
                `Minted ${u.tokenId
                } for address ${await u.getAddress()} and assigned ${aa_addr}`
            );
            let acc = await ethers.getContractAt("TokenBoundAccount", aa_addr);
            abstractAccounts.push(acc);
        }
        /**
                Minted 0 for address 0x1cf71Ae69ed0c16253f1523a4B5c2cA4fcd967BA and assigned 0xEb061CC58a39483A26089d7Ce514a4CFB50881E5
                Minted 1 for address 0xedB346a71c747608B4966f0932DA83976DA41652 and assigned 0x29A9194b77292b4875f8D070C819f23A90Cf478E
                Minted 2 for address 0x132d6c57A3f39859536d6C04db56bAA70Cf32E9C and assigned 0x4f7805C1Ef304405840B250B69E4d16b5450f9f2
                Minted 3 for address 0x6cA18dBf7a9eb5E99f481E181C053bFAe32Ed010 and assigned 0x43daA91B9b339DFD8daE48d824e46b060e012135
                Minted 4 for address 0x2370172164b26D37d0B47e6582823Afa7006ea95 and assigned 0x81A8a47c2b06A47C594C5C3711d9C8ddd3B78d8f
                Minted 5 for address 0x8e61F9d8AC761a936aAD8A1421fA5CeaD5942Af3 and assigned 0xc92cf3FBEED66aDa7617Acd998Ce70533C552fdA
                Minted 6 for address 0xf9E4a48A1131373e2ad08992aAb63F0750f6a277 and assigned 0xe23EF0D205C42bE572CC016265978EF111d010ee
                Minted 7 for address 0x3b6982853DDC791fb365A18014221EAbb46B92D7 and assigned 0x247408c3C21C28756F29990380d518246d1a88f3
                Minted 8 for address 0x7AfF777a45f071E5666332fa6ed5Feb4c90f6369 and assigned 0x234Ec7c68743F1614f58bFF1DA15BA9A24567D49
                Minted 9 for address 0x4d26a02eD5dac607301880aE1d1a87215a32E0ed and assigned 0xbE87210E920C773F6F9438FA42B804D204f9222d
                Minted 10 for address 0x1d80EbD4fa787EC5Fb4b18aa4f3561954fE9fF6F and assigned 0xfA8f3B8Cd42a7054c9BA7d786f526Ad4758F1446
                Minted 11 for address 0xd3111f9253Bb484FF5490F575AC21978D981cD3e and assigned 0x432F3bBFB0b09e07554559e7706b08c11bc121ec
                Minted 12 for address 0x9c175A24c56BFe220f43DC78446ED6787AF3b519 and assigned 0x1E5945182718bfF7B85689edDD51cd32a1c9Fad8
                Minted 13 for address 0xF1459f47eA0F225D1A7ec635d4F9cDF28a42F66e and assigned 0x93ed97C8d3b28192a42864668F1F7DB7661Ee998
                Minted 14 for address 0xBD6bad70a2756058BE287a12078ecd469B933B7e and assigned 0x15CA19E0de7E5F2CCB07e4989EF3b030eE938551
                Minted 15 for address 0xBe2453FfE7caAc3268dc82E6561496579Dacf034 and assigned 0xD75621624811Ff6D6BCff1048bAc90FE219b4A9d
                Minted 16 for address 0xC26FC7D5ff5aef027406c918ceD5a11c30068914 and assigned 0x74af39f573Dc681deBCfA58c2863Aa44F23D3c99
                Minted 17 for address 0x4c71747Dd0BBc1A023136A424334072FDf0aB1Ce and assigned 0x28310d3c8Ff416c0FC158AAC741b73253dBA80F5
                Minted 18 for address 0xBA3e816a5F664B0Bb119fd51a3D4886B759510A5 and assigned 0x83eCD224c33fD5D7713597fD0869064d9C81e9a7
                Minted 19 for address 0xeba6FdBc5Bf93d1850411694750a9729c67A6ad1 and assigned 0x7b42735dc0923eDD8f99f522a38503e1653bc6Ce
            */
    } else {
        for (const a of aa_addresses) {
            let acc = await ethers.getContractAt("TokenBoundAccount", a);
            abstractAccounts.push(acc);
        }
    }

    /*** Fund */
    if (level == 2) {
        level++;
        for (let i = 0; i < abstractAccounts.length; i++) {
            let res = await (
                await bionicContract
                    .connect(owner)
                    .transfer(abstractAccounts[i].address, 50000)
            ).wait();
            res = await (
                await usdtContract
                    .connect(owner)
                    .transfer(abstractAccounts[i].address, 5000)
            ).wait();
            await (
                await owner.sendTransaction({
                    value: 80000000000000,
                    to: users[i].getAddress(),
                })
            ).wait();
            console.log(
                `Transferred ${res.events[0]?.args.amount
                }USDT+${80000000000000}wei to ${res.events[0]?.args.to}`,
                res.events[0]?.args.from
            );
        }
    }

    /*** Add Project */
    //    level++;
    let pledgeAmount = 1000,
        tiers = [4, 3, 2];
    if (level == 3) {
        level++;
        let timeDifference = 10;
        let pledgeEnding = new Date();
        pledgeEnding.setMinutes(pledgeEnding.getMinutes() + timeDifference);
        let tokenAllocationStartTime = new Date(pledgeEnding.getTime());
        tokenAllocationStartTime.setMinutes(tokenAllocationStartTime.getMinutes() + timeDifference / 4);
        console.log(
            `now ${(Date.now() / 1000) | 0} and ${timeDifference} mins later ${(pledgeEnding.getTime() / 1000) | 0
            } and token allocation will be at ${(tokenAllocationStartTime.getTime() / 1000) | 0}`
        );
        let r = await (
            await fundingContract
                .connect(owner)
                .add(
                    BIONIC_TOKEN_ADDR,
                    (Date.now() / 1000) | 0,
                    (pledgeEnding.getTime() / 1000) | 0,
                    1000,
                    10,
                    (tokenAllocationStartTime.getTime() / 1000) | 0,
                    10,
                    1e10,
                    tiers
                )
        ).wait(1);
        pid = r?.events[1].args?.pid;
        console.log(pid);
    }

    /*** Pledge */
    if (level == 4) {
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
            let raw = fundingContract.interface.encodeFunctionData("pledge", [
                pid,
                pledgeAmount,
                deadline,
                v,
                r,
                s,
            ]);
            let feeData = await provider.getFeeData();
            try {
                let res = await (
                    await abstractAccounts[i]
                        .connect(users[i])
                        .executeCall(fundingContract.address, 0, raw, {
                            gasLimit: 3000000,
                            gasPrice: feeData.gasPrice || undefined,
                        })
                ).wait(1);
                console.log(
                    `approved and moved ${res.events[3].args.value} in  ${res.events[3].args.currency} from ${res.events[3].address} to ${res.events[3].args.spender} `
                );
            } catch (err) {
                console.error(err);
            }
        }
    }

    /*** Add tiers */
    if (level <= 5) {
        level++;
        let pool = await fundingContract.poolInfo(pid);
        let usersPerTier = Math.floor(users.length / pool.winnersCount);
        let tierUsers: string[][] = [];
        let userIdx = 0;
        for (let i = 0; i < tiers.length - 1; i++) {
            // leave last teir to be setup by smart contract
            tierUsers[i] = [];
            for (let j = 0; j < tiers[i] * usersPerTier; j++) {
                tierUsers[i].push(abstractAccounts[userIdx++].address);
            }
        }
        for (let i = 0; i < tierUsers.length; i++) {
            console.log(`Tier ${i} contains ${tierUsers[i].length} =>`);
            console.log(tierUsers[i]);
            let res = await (
                await fundingContract.connect(owner).addToTier(pid, i, tierUsers[i])
            ).wait();
            console.log(
                `Added ${res.events[0]?.args.members.length} members to ${res.events[0]?.args.tierId} for pool ${res.events[0]?.args.pid}`
            );
        }
    }

    if (level <= 6) {
        level++;
        try {
            let res = await (await fundingContract.draw(pid, configInfo.cbGasLimit)).wait();
            console.log(`last tier initated with ${res.events[0].args.members.length}`, res.events[0].args.members);
        } catch (error) {
            let pool = await fundingContract.poolInfo(pid);
            let toWait = pool.tokenAllocationStartTime.sub(Date.now() / 1000 | 0);
            if (toWait.gt(0)) {
                console.log(`need to wait to do the draw for ${toWait} seconds`)
            } else {
                console.log(error)
            }
        }
    }

    //    /*** test */
    //    if(level==5){
    //     const deadline = ethers.constants.MaxUint256;
    //     const { v, r, s } = await getCurrencyPermitSignature(
    //         //@ts-ignore
    //         owner,
    //         await ethers.getContractAt("TokenBoundAccount","0xEb061CC58a39483A26089d7Ce514a4CFB50881E5"),
    //         bionicContract,
    //         fundingContract.address,
    //         BigNumber.from(pledgeAmount),
    //         deadline
    //     );
    //     let raw = fundingContract.interface.encodeFunctionData("pledge", [0, BigNumber.from(pledgeAmount), deadline, v, r, s]);

    //     console.log("raw:",raw)
    //    }
}

const getSigners = (amount: number): Signer[] => {
    const mnemonic =
        "announce room limb pattern dry unit scale effort smooth jazz weasel alcohol";
    const signers: Signer[] = [];
    for (let i = 25; i < amount + 25; i++) {
        const walletMnemonic = ethers.Wallet.fromMnemonic(
            mnemonic,
            `m/44'/60'/0'/0/${i}`
        );
        let signer = new ethers.Wallet(walletMnemonic.privateKey || "", provider);
        signers.push(signer);
    }
    return signers;
};

async function getCurrencyPermitSignature(
    signer: SignerWithAddress,
    account: TokenBoundAccount,
    currency: IERC20,
    spender: string,
    value: BigNumber,
    deadline: BigNumber = ethers.constants.MaxUint256
) {
    const [nonce, name, version, chainId] = await Promise.all([
        account.nonce(),
        "BionicAccount",
        "1",
        signer.getChainId(),
    ]);

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
    );
}
//step, pid
main(3, 13).then(console.log).catch(console.error);
