import dotenv from "dotenv";
import { ethers, network } from "hardhat";
import { getProviderFromRpcUrl } from "@thirdweb-dev/sdk";
import { BigNumber, Contract, Signer } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { IERC20, BionicAccount } from "../typechain-types";
import { arbitrum as configInfo } from './config.json';
import { BionicStructs } from "../typechain-types/contracts/Launchpad/BionicPoolRegistry";

dotenv.config();

interface User extends Signer {
    tokenId?: any;
}
const BIP_CONTRACT = configInfo.bionicInvestorPass,
    TOKEN_BOUND_IMP_ADDR = configInfo.tbaImpl,
    BIONIC_LAUNCH_ADDR = configInfo.bionicLaunchPad,
    BIONIC_TOKEN_ADDR = configInfo.tokenAddress,
    USDT_ADDR = configInfo.usdtAddress,
    ERC6551_REGISTRY_ADDR = configInfo.erc6551Reg,
    PLEDGE_AMOUNT = 1000,
    GUARDIAN_RESCUE_ACCOUNT = "0xC1207Ef2eC9F05166d3cd563cFb17BaEE191b868";
// //goerli
// let provider = getProviderFromRpcUrl(process.env.RPC_URL || "", {});
// //mumbai
// let provider = getProviderFromRpcUrl(process.env.MUMBAI_RPC || "", {});
// arb-sepolia
let provider = getProviderFromRpcUrl(process.env.ARB_RPC || "", {});
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
    let chainId = network.config.chainId || 421614;
    let users: User[] = getSigners(20);
    let fundingContract = await ethers.getContractAt(
        "BionicPoolRegistry",
        BIONIC_LAUNCH_ADDR
    );
    let usdtContract = await ethers.getContractAt("ERC20", USDT_ADDR);
    let bionicContract = await ethers.getContractAt("ERC20", BIONIC_TOKEN_ADDR);
    let tokenBoundImpContract = await ethers.getContractAt("BionicAccount", configInfo.tbaImpl);
    console.log(`using BionicAccount Implementation Deployed at ${tokenBoundImpContract.address}`);
    let abstractAccounts: BionicAccount[] = [];
    //goerli
    // const aa_addresses = [
    //     "0xEb061CC58a39483A26089d7Ce514a4CFB50881E5",
    //     "0x29A9194b77292b4875f8D070C819f23A90Cf478E",
    //     "0x4f7805C1Ef304405840B250B69E4d16b5450f9f2",
    //     "0x43daA91B9b339DFD8daE48d824e46b060e012135",
    //     "0x81A8a47c2b06A47C594C5C3711d9C8ddd3B78d8f",
    //     "0xc92cf3FBEED66aDa7617Acd998Ce70533C552fdA",
    //     "0xe23EF0D205C42bE572CC016265978EF111d010ee",
    //     "0x247408c3C21C28756F29990380d518246d1a88f3",
    //     "0x234Ec7c68743F1614f58bFF1DA15BA9A24567D49",
    //     "0xbE87210E920C773F6F9438FA42B804D204f9222d",
    //     "0xfA8f3B8Cd42a7054c9BA7d786f526Ad4758F1446",
    //     "0x432F3bBFB0b09e07554559e7706b08c11bc121ec",
    //     "0x1E5945182718bfF7B85689edDD51cd32a1c9Fad8",
    //     "0x93ed97C8d3b28192a42864668F1F7DB7661Ee998",
    //     "0x15CA19E0de7E5F2CCB07e4989EF3b030eE938551",
    //     "0xD75621624811Ff6D6BCff1048bAc90FE219b4A9d",
    //     "0x74af39f573Dc681deBCfA58c2863Aa44F23D3c99",
    //     "0x28310d3c8Ff416c0FC158AAC741b73253dBA80F5",
    //     "0x83eCD224c33fD5D7713597fD0869064d9C81e9a7",
    //     "0x7b42735dc0923eDD8f99f522a38503e1653bc6Ce",
    // ];
    //mumbai
    // const aa_addresses = [
    //     "0xEF8A4118c332dA68A8021725b8720823c83EE32b",
    //     "0x917e66a24C1cba42E2f296D84cb3DB90919e1931",
    //     "0x4ed1036D34E3aA2b74a15884248602C8600e54B6",
    //     "0x37D17BaF2435f6148b6B3d720aFa37DCfb71376b",
    //     "0xab9cC70492D4D418777fB75C8518D8C19D88b2f2",
    //     "0x6EDee3FcEfB5C97194A64794f2F2d2B4BBF80876",
    //     "0x2D2F0dA03fF258820DddDBd1db9C0D3B167B6197",
    //     "0xF59818808E6474Ac6799db497167A71cE14A348A",
    //     "0x50430177170225E450D8f72B04c6E72f910ac612",
    //     "0x7cda89f88a24259aCB3c5624ea89Cb09bF9B64f4",
    //     "0x07674Ee6C456C556Ac1Ae73f645670638219ce34",
    //     "0x2B5b2da3C5d07249AC60dce0D09219eacb0Ad002",
    //     "0xEcF899766dc38acC29DBc89922E4a27317fD5e32",
    //     "0xCe5Bfb0632C71F33e3D06b3dd90D95B633b70389",
    //     "0x03d2D94AfDDEFcfbF339Ec97206Ea2be472b242C",
    //     "0xbB5A909a2441B18182f69407035A3ED6a0F0992D",
    //     "0x53ACCcF4cf5207F2e8B85B6E41AdcA2eDD6454ca",
    //     "0x9A07d707Ae26AEF0B28b3B2481A3184a313Bd8C0",
    //     "0xa4F111e2524D3484c5A99816C25348f6b01B73c1",
    //     "0xc1F5F6b508259378C5F261C7819A6Df315225550",
    // ];
    // sepoia - arb
    const aa_addresses: string[] = [
        "0xa9706A7A5de3fCf596697ac49062453cF4476CeC",
        "0x195347D9508f5ab6f60Dc282D597E07eaaCd7092",
        "0x7d7Ca13115b909835f99732206966a7bf6238B2F",
        "0xaC8d06d58c0b13981F710e996c79753D2BB991Fd",
        "0xDcf6CE2882F546A64C57f1eC4cD6F5E239D2F6dC",
        "0x85049588a12dBBebD2A8E1EbbDDfAa70da2E9C55",
        "0x3fC01781CC809662D281ceeD123eB44Ae348DD97",
        "0xC283821D4BE4B7752016d3a196b23C2b85788462",
        "0xaD703B2F35D158e0A54c318e62193062bC7f40FF",
        "0xb0d416B1061664589Debd411f97195fD034a2F07",
        "0xf852520AFA52A743a7835E3A5D225878E3507471",
        "0x8dEc7E62395E5f8cC08112c1d43C0988786749c1",
        "0x0bDDC16d67b3b0b9fFe347887911606D533dc55d",
        "0x56a4f7A8fF552f8554b350274948Fbd0062100e8",
        "0xC6C340dE2C9aE818E7655aC5e6a39C71a404d164",
        "0x08E3775e2F90349C00EfB5DD5045C81C9bfE4e00",
        "0x210e5Bf8129E208Ca80E02f22bb1f7465F2f28B4",
        "0x9cCD9169d9293c0D18c162339F04C97966f9284d",
        "0x0aAB4DcC6de46873D7BA01cDF6eb305e6fA11A98",
        "0xa42889Fb2A3F7f263C40fca01b73Cfa535f641A3",
    ];

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
            "BionicAccount",
            TOKEN_BOUND_IMP_ADDR
        );
        console.log(`loaded contracts, BIP: ${bipContract.address}, TBA: ${tokenBoundImpContract.address}, Registry: ${tokenBoundContractRegistry.address}`)
        for (let i = 0; i < users.length; i++) {
            const u = users[i];
            if ((await bipContract.balanceOf(u.getAddress())).lte(0)) {
                //mint NFT
                let res = await (
                    await bipContract
                        .connect(owner)
                        .safeMint(await u.getAddress(), GUARDIAN_RESCUE_ACCOUNT, "https://loremflickr.com/320/240?lock=" + i)
                ).wait(1);
                u.tokenId = res?.events[0]?.args?.tokenId;
            } else {
                const res = await (await fetch(`https://api-sepolia.arbiscan.io/api?module=account&action=tokennfttx&contractaddress=${configInfo.bionicInvestorPass}&address=${(await users[i].getAddress()).toLocaleLowerCase()}&page=1&apikey=${process.env.ARBITRUMSCAN_API_KEY}`)).json();
                u.tokenId = await res.result[0].tokenID
            }
            process.stdout.write(`minted ${u.tokenId} for ${await u.getAddress()}\t`);
            //create abstracted accounts
            let r = await (
                await tokenBoundContractRegistry.createAccount(
                    tokenBoundImpContract.address,
                    ethers.utils.formatBytes32String(""),
                    chainId as number,
                    bipContract.address,
                    u.tokenId
                )
            ).wait(1);
            let aa_addr = await tokenBoundContractRegistry.account(
                tokenBoundImpContract.address,
                ethers.utils.formatBytes32String(""),
                chainId as number,
                bipContract.address,
                u.tokenId,
            );
            process.stdout.write(`assigned ${aa_addr}\n`);
            let acc = await ethers.getContractAt("BionicAccount", aa_addr);
            abstractAccounts.push(acc);
        }
        /**
        Minted 0 for address 0x1cf71Ae69ed0c16253f1523a4B5c2cA4fcd967BA and assigned 0xEF8A4118c332dA68A8021725b8720823c83EE32b
        Minted 1 for address 0xedB346a71c747608B4966f0932DA83976DA41652 and assigned 0x917e66a24C1cba42E2f296D84cb3DB90919e1931
        Minted 2 for address 0x132d6c57A3f39859536d6C04db56bAA70Cf32E9C and assigned 0x4ed1036D34E3aA2b74a15884248602C8600e54B6
        Minted 3 for address 0x6cA18dBf7a9eb5E99f481E181C053bFAe32Ed010 and assigned 0x37D17BaF2435f6148b6B3d720aFa37DCfb71376b
        Minted 4 for address 0x2370172164b26D37d0B47e6582823Afa7006ea95 and assigned 0xab9cC70492D4D418777fB75C8518D8C19D88b2f2
        Minted 5 for address 0x8e61F9d8AC761a936aAD8A1421fA5CeaD5942Af3 and assigned 0x6EDee3FcEfB5C97194A64794f2F2d2B4BBF80876
        Minted 6 for address 0xf9E4a48A1131373e2ad08992aAb63F0750f6a277 and assigned 0x2D2F0dA03fF258820DddDBd1db9C0D3B167B6197
        Minted 7 for address 0x3b6982853DDC791fb365A18014221EAbb46B92D7 and assigned 0xF59818808E6474Ac6799db497167A71cE14A348A
        Minted 8 for address 0x7AfF777a45f071E5666332fa6ed5Feb4c90f6369 and assigned 0x50430177170225E450D8f72B04c6E72f910ac612
        Minted 9 for address 0x4d26a02eD5dac607301880aE1d1a87215a32E0ed and assigned 0x7cda89f88a24259aCB3c5624ea89Cb09bF9B64f4
        Minted 10 for address 0x1d80EbD4fa787EC5Fb4b18aa4f3561954fE9fF6F and assigned 0x07674Ee6C456C556Ac1Ae73f645670638219ce34
        Minted 11 for address 0xd3111f9253Bb484FF5490F575AC21978D981cD3e and assigned 0x2B5b2da3C5d07249AC60dce0D09219eacb0Ad002
        Minted 12 for address 0x9c175A24c56BFe220f43DC78446ED6787AF3b519 and assigned 0xEcF899766dc38acC29DBc89922E4a27317fD5e32
        Minted 13 for address 0xF1459f47eA0F225D1A7ec635d4F9cDF28a42F66e and assigned 0xCe5Bfb0632C71F33e3D06b3dd90D95B633b70389
        Minted 14 for address 0xBD6bad70a2756058BE287a12078ecd469B933B7e and assigned 0x03d2D94AfDDEFcfbF339Ec97206Ea2be472b242C
        Minted 15 for address 0xBe2453FfE7caAc3268dc82E6561496579Dacf034 and assigned 0xbB5A909a2441B18182f69407035A3ED6a0F0992D
        Minted 16 for address 0xC26FC7D5ff5aef027406c918ceD5a11c30068914 and assigned 0x53ACCcF4cf5207F2e8B85B6E41AdcA2eDD6454ca
        Minted 17 for address 0x4c71747Dd0BBc1A023136A424334072FDf0aB1Ce and assigned 0x9A07d707Ae26AEF0B28b3B2481A3184a313Bd8C0
        Minted 18 for address 0xBA3e816a5F664B0Bb119fd51a3D4886B759510A5 and assigned 0xa4F111e2524D3484c5A99816C25348f6b01B73c1
        Minted 19 for address 0xeba6FdBc5Bf93d1850411694750a9729c67A6ad1 and assigned 0xc1F5F6b508259378C5F261C7819A6Df315225550
            */
    } else {
        for (const a of aa_addresses) {
            let acc = await ethers.getContractAt("BionicAccount", a);
            abstractAccounts.push(acc);
        }
    }

    /*** Fund */
    if (level == 2) {
        level++;
        for (let i = 0; i < abstractAccounts.length; i++) {
            let res;
            if ((await bionicContract.balanceOf(abstractAccounts[i].address)).lte(await fundingContract.MINIMUM_BIONIC_STAKE())) {
                res = await (
                    await bionicContract
                        .connect(owner)
                        .transfer(abstractAccounts[i].address, await fundingContract.MINIMUM_BIONIC_STAKE())
                ).wait();
                process.stdout.write(`${res.events[0]?.args[2]} $BCNX + `);
            }
            if ((await usdtContract.balanceOf(abstractAccounts[i].address)).lte(BigNumber.from(0))) {
                res = await (
                    await usdtContract
                        .connect(owner)
                        .transfer(abstractAccounts[i].address, 5000)
                ).wait();
                process.stdout.write(`${res.events[0]?.args[2]} $USDT + `);
            }
            if (await (await users[i].getBalance()).lte(BigNumber.from("300000000000000"))) {
                await (
                    await owner.sendTransaction({
                        value: BigNumber.from("300000000000000"),
                        to: users[i].getAddress(),
                    })
                ).wait();
                process.stdout.write(`[+${300000000000000} $wei ${await users[i].getAddress()}] `);
            }
            process.stdout.write(`Funded ${abstractAccounts[i].address}\n`);
        }
    }

    /*** Add Project */
    //    level++;
    let pledgeAmount = PLEDGE_AMOUNT,
        tiers = [4, 3, 2],
        pledgingTiers: BionicStructs.PledgeTierStruct[] = [
            { maximumPledge: PLEDGE_AMOUNT, minimumPledge: PLEDGE_AMOUNT, tierId: 1 },
            { maximumPledge: PLEDGE_AMOUNT * 3, minimumPledge: PLEDGE_AMOUNT * 3, tierId: 2 },
            { maximumPledge: PLEDGE_AMOUNT * 5, minimumPledge: PLEDGE_AMOUNT * 5, tierId: 3 }
        ]
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
                    pid,
                    bionicContract.address,
                    (Date.now() / 1000) | 0, //PLEDGING_START_TIME
                    (pledgeEnding.getTime() / 1000) | 0, //PLEDGING_END_TIME
                    1000, //tokenAllocationPerMonth
                    (tokenAllocationStartTime.getTime() / 1000) | 0, //tokenAllocationStartTime
                    10,//tokenAllocationMonthCount
                    1e10,//targetRaise
                    true,//do raffle
                    tiers,
                    pledgingTiers,
                )
        ).wait(1);
        pid = r.events[0]?.args[0];
        console.log(`added project with Id: ${pid}`)
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
                        .execute(fundingContract.address, 0, raw, 0, {
                            gasLimit: 3000000,
                            gasPrice: feeData.gasPrice || undefined,
                        })
                ).wait(1);
                console.log(
                    `approved and moved ${res.events[6]} `
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
            // leave last tier to be setup by smart contract
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
    //         await ethers.getContractAt("BionicAccount","0xEb061CC58a39483A26089d7Ce514a4CFB50881E5"),
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
    account: BionicAccount,
    currency: IERC20,
    spender: string,
    value: BigNumber,
    deadline: BigNumber = ethers.constants.MaxUint256
) {
    const [nonce, name, version, chainId] = await Promise.all([
        account.getNonce(),
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
main(6, 0).then(console.log).catch(console.error);
