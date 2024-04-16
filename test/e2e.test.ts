import { BigNumber } from "@ethersproject/bignumber";
import { expect } from "chai";
import { ethers, upgrades, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
    IERC20Permit, ERC6551Registry, BionicPoolRegistry, ERC20Upgradeable, BionicAccount, MockEntryPoint,
    BionicInvestorPass, Bionic, ERC20,
    BionicTokenDistributor
}
    from "../typechain-types";
import { BionicStructs } from "../typechain-types/contracts/Launchpad/BionicPoolRegistry";
import { StandardMerkleTree } from '@openzeppelin/merkle-tree';

const helpers = require("@nomicfoundation/hardhat-network-helpers");


// const NETWORK_CONFIG = {
//     name: "mumbai",
//     linkToken: "0x326C977E6efc84E512bB9C30f76E30c160eD06FB",
//     ethUsdPriceFeed: "0x0715A7794a1dc8e42615F059dD6e406A6594651A",
//     keyHash: "0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f",
//     vrfCoordinator: "0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed",
//     vrfWrapper: "0x99aFAf084eBA697E584501b8Ed2c0B37Dd136693",
//     oracle: "0x40193c8518BB267228Fc409a613bDbD8eC5a97b3",
//     jobId: "ca98366cc7314957b8c012c72f05aeeb",
//     fee: "100000000000000000",
//     fundAmount: "100000000000000000", // 0.1
//     usdtAddr : "0x015cCFEe0249836D7C36C10C81a60872c64748bC", // on polygon network
//     usdtWhale : "0xd8781f9a20e07ac0539cc0cbc112c65188658816", // on polygon network
//     accountAddress: "0xd1ded19fE7B79005259e36a772Fd72D4dD08dF4F",
//     automationUpdateInterval: "30",
// };

const NETWORK_CONFIG = {
    name: "arbitrum",
    linkToken: "0xb1D4538B4571d411F07960EF2838Ce337FE1E80E",
    keyHash: "0x027f94ff1465b3525f9fc03e9ff7d6d2c0953482246dd6ae07570c45d6631414",
    vrfCoordinator: "0x50d47e4142598E3411aA864e08a44284e471AC6f",
    oracle: "0x40193c8518BB267228Fc409a613bDbD8eC5a97b3",
    fee: "100000000000000000",
    fundAmount: "100000000000000000", // 0.1
    usdtAddr: "0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d",
    usdtWhale: "0x6ED0C4ADDC308bb800096B8DaA41DE5ae219cd36",
    accountAddress: "0x5e3cd20A0401E23069F7209694AdB215D23bb830",
    automationUpdateInterval: "30",
};

const ENTRY_POINT = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",
    ERC6551_REGISTRY_ADDR = "0x000000006551c19487814612e58FE06813775758",
    USDT_ADDR = NETWORK_CONFIG.usdtAddr, // on polygon network
    USDT_WHALE = NETWORK_CONFIG.usdtWhale, // on polygon network
    ACCOUNT_ADDRESS = NETWORK_CONFIG.accountAddress,
    CALLBACK_GAS_LIMIT_PER_USER = 90300,
    REQUEST_VRF_PER_WINNER = true,
    PLEDGING_START_TIME = 1810704849,
    PLEDGING_END_TIME = 2710704849,
    tokenAllocationStartTime = PLEDGING_END_TIME + 1000,
    PLEDGE_AMOUNT = 1000,
    TIER_ALLOCATION = [3, 2, 1];

describe("e2e", function () {
    let bionicContract: Bionic, bipContract: BionicInvestorPass, BionicPoolRegistry: BionicPoolRegistry,
        tokenBoundImpContract: BionicAccount, abstractedAccount: BionicAccount, AbstractAccounts: BionicAccount[],
        usdtContract: ERC20Upgradeable, tokenBoundContractRegistry: ERC6551Registry, DistributorContract: BionicTokenDistributor, mockEntryPoint: MockEntryPoint;
    let owner: SignerWithAddress, client: SignerWithAddress, guardian: SignerWithAddress;
    let signers: SignerWithAddress[];
    let bionicDecimals: number;
    let pledgingTiers: BionicStructs.PledgeTierStruct[];
    let CYCLE_IN_SECONDS: number;


    before(async () => {
        [owner, client, guardian, ...signers] = await ethers.getSigners();
        bionicContract = await deployBionic();
        bipContract = await deployBIP();
        tokenBoundContractRegistry = await ethers.getContractAt("ERC6551Registry", ERC6551_REGISTRY_ADDR);
        mockEntryPoint = await ethers.getContractAt("MockEntryPoint", ENTRY_POINT);
        usdtContract = await ethers.getContractAt("ERC20Upgradeable", USDT_ADDR);
        let AccountGuardianFactory = await ethers.getContractFactory("AccountGuardian");
        let accountGuardian = await AccountGuardianFactory.deploy();
        tokenBoundImpContract = await deployTBA(mockEntryPoint.address, accountGuardian.address);
        bionicDecimals = await bionicContract.decimals();
        abstractedAccount = await ethers.getContractAt("BionicAccount", ACCOUNT_ADDRESS);
        pledgingTiers = [
            { maximumPledge: PLEDGE_AMOUNT, minimumPledge: PLEDGE_AMOUNT, tierId: 1 },
            { maximumPledge: PLEDGE_AMOUNT * 3, minimumPledge: PLEDGE_AMOUNT * 3, tierId: 2 },
            { maximumPledge: PLEDGE_AMOUNT * 5, minimumPledge: PLEDGE_AMOUNT * 5, tierId: 1 }
        ]

        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [USDT_WHALE],
        });

        const whale = await ethers.getSigner(USDT_WHALE);
        let tokenBoundAccBal = await usdtContract.balanceOf(abstractedAccount.address);
        const HUNDRED_THOUSAND = ethers.utils.parseUnits("100000", 6);
        await usdtContract.connect(whale).transfer(abstractedAccount.address, HUNDRED_THOUSAND);
        tokenBoundAccBal = await usdtContract.balanceOf(abstractedAccount.address);
        AbstractAccounts = [abstractedAccount];
        for (let i = 0; i < 10; i++) {
            //mint BIP 
            let res = await bipContract.safeMint(signers[(i * 2)].address, signers[(i * 2) + 1].address, "https://linktoNFT.com");
            let r = await res.wait()
            //@ts-ignore
            expect(BigNumber.from(r?.events[0]?.args.tokenId)).to.equal(BigNumber.from(i))
            //create abstracted accounts
            res = await tokenBoundContractRegistry.createAccount(tokenBoundImpContract.address, ethers.utils.formatBytes32String('0'),
                network.config.chainId as number, bipContract.address,
                i);
            let newAcc = await res.wait(1);
            let acc = await ethers.getContractAt("BionicAccount", newAcc?.events[0]?.args?.account);
            await usdtContract.connect(whale).transfer(acc.address, HUNDRED_THOUSAND);
            expect(await acc.owner()).to.equal(signers[i * 2].address);

            AbstractAccounts.push(acc);
        }


        // setup VRF_MOCK
        BionicPoolRegistry = await deployBionicPoolRegistry(bionicContract.address, usdtContract.address, bipContract.address);

        DistributorContract = await deployBionicTokenDistributor();
        CYCLE_IN_SECONDS = Number(await DistributorContract.CYCLE_IN_SECONDS());
    });


    describe("Bionic", function () {
        it("Should Mint owner 100000000 token upon deployed", async function () {
            expect(await bionicContract.totalSupply()).to.equal(await bionicContract.balanceOf(await owner.getAddress()));
        });

        it("Should set the right owner", async function () {
            expect(await bionicContract.hasRole(await bionicContract.DEFAULT_ADMIN_ROLE(), owner.address)).to.be.true;
            expect(await bionicContract.hasRole(await bionicContract.SNAPSHOT_ROLE(), owner.address)).to.be.true;
            expect(await bionicContract.hasRole(await bionicContract.UPGRADER_ROLE(), owner.address)).to.be.true;
        });
        it("Should transfer 100000000 to the other user", async function () {
            let total = BigNumber.from(await bionicContract.totalSupply());
            let amount = BigNumber.from(6000).mul(BigNumber.from(10).pow(bionicDecimals));
            await bionicContract.transfer(client.address, amount)
            expect(await bionicContract.balanceOf(client.address)).to.equal(amount);
            expect(await bionicContract.balanceOf(owner.address)).to.equal(total.sub(amount));
        });


        it("Should approve fundVesting contract to move 5 on behalf of user", async function () {
            let amount = BigNumber.from(5).mul(BigNumber.from(10).pow(bionicDecimals));
            await bionicContract.connect(client).approve(BionicPoolRegistry.address, amount);
            expect(await bionicContract.allowance(client.address, BionicPoolRegistry.address)).to.equal(amount);
        });
        it("Should permit fundVesting contract to move 10 on behalf of user", async function () {
            let amount = BigNumber.from(10).mul(BigNumber.from(10).pow(bionicDecimals));
            const deadline = ethers.constants.MaxUint256

            const { v, r, s } = await getPermitSignature(
                client,
                bionicContract,
                BionicPoolRegistry.address,
                amount,
                deadline
            )
            await bionicContract.connect(client).permit(client.address, BionicPoolRegistry.address, amount, deadline, v, r, s)
            expect(await bionicContract.allowance(client.address, BionicPoolRegistry.address)).to.equal(amount);
        });

    });
    describe("BIP", function () {
        it("Should set the right owner", async function () {
            expect(await bipContract.hasRole(await bipContract.DEFAULT_ADMIN_ROLE(), owner.address)).to.be.true;
            expect(await bipContract.hasRole(await bipContract.PAUSER_ROLE(), owner.address)).to.be.true;
            expect(await bipContract.hasRole(await bipContract.MINTER_ROLE(), owner.address)).to.be.true;
            expect(await bipContract.hasRole(await bipContract.UPGRADER_ROLE(), owner.address)).to.be.true;
        });
        it("Should Mint NFT to other user", async function () {
            let res = await bipContract.safeMint(client.address, guardian.address, "https://linktoNFT.com");

            let r = await res.wait()
            expect(r.events[0].args[0]).to.equal('0x0000000000000000000000000000000000000000')
            expect(BigNumber.from(r.events[0].args[2])).to.equal(BigNumber.from(10))
        });
    });

    describe("BionicAccount", () => {
        it("should Generate an address for SmartWallet", async () => {
            let res = await tokenBoundContractRegistry.account(tokenBoundImpContract.address, ethers.utils.formatBytes32String('0'),
                network.config.chainId as number, bipContract.address,
                "10");
            expect(res).to.equal(ACCOUNT_ADDRESS);
        })
        it("should deploy a new address for the user based on their token", async () => {
            await network.provider.send("hardhat_mine", ["0x100"]); //mine 256 blocks
            let res = await tokenBoundContractRegistry.createAccount(tokenBoundImpContract.address, ethers.utils.formatBytes32String('0'),
                network.config.chainId as number, bipContract.address,
                "10");
            let newAcc = await res.wait();

            expect(newAcc?.events[0]?.args?.account).to.equal(ACCOUNT_ADDRESS);
        })
        it("should permit fundingContract to transfer currencies out of users wallet", async () => {
            const deadline = ethers.constants.MaxUint256;
            const token = await abstractedAccount.token();
            const alreadyPledged = await abstractedAccount.allowances(client.address, BionicPoolRegistry.address);
            expect(alreadyPledged).to.equal(BigNumber.from(0));
            const amount = BigNumber.from(10);
            const { v, r, s } = await getCurrencyPermitSignature(
                client,
                abstractedAccount,
                bionicContract,
                BionicPoolRegistry.address,
                alreadyPledged.add(amount),
                deadline
            )


            await expect(abstractedAccount.connect(client).permit(bionicContract.address, BionicPoolRegistry.address, amount, deadline, v, r, s))
                .to.emit(abstractedAccount, "CurrencyApproval").withArgs(bionicContract.address, BionicPoolRegistry.address, amount);
            expect(await abstractedAccount.allowance(bionicContract.address, BionicPoolRegistry.address)).to.equal(alreadyPledged.add(amount));
        })
    });
    describe("FundingRegistry", () => {
        describe("Add", function () {
            const tokenAllocationPerMonth = 100, tokenAllocationMonthCount = 10, targetRaise = PLEDGE_AMOUNT * PLEDGE_AMOUNT
            it("Should fail if the not BROKER", async function () {
                await expect(BionicPoolRegistry.connect(client)
                    .add(0, PLEDGING_START_TIME, PLEDGING_END_TIME, tokenAllocationPerMonth, tokenAllocationStartTime, tokenAllocationMonthCount, targetRaise, true, pledgingTiers))
                    .to.be.reverted;
            });
            it("Should fail if the time is less than now", async function () {
                const t = Math.floor(Date.now() / 10000);
                await expect(BionicPoolRegistry.add(0, t, PLEDGING_END_TIME, tokenAllocationPerMonth, tokenAllocationStartTime, tokenAllocationMonthCount, targetRaise, true, pledgingTiers))
                    .to.revertedWithCustomError(BionicPoolRegistry, "BPR__PledgeStartAndPledgeEndNotValid");
            });
            it("Should allow BROKER to set new projects", async function () {
                expect(await BionicPoolRegistry.hasRole(await BionicPoolRegistry.BROKER_ROLE(), owner.address)).to.be.true;
                await expect(BionicPoolRegistry.add(0, PLEDGING_START_TIME, PLEDGING_END_TIME, tokenAllocationPerMonth, tokenAllocationStartTime, tokenAllocationMonthCount, targetRaise, true, pledgingTiers))
                    .to.emit(BionicPoolRegistry, "PoolAdded").withArgs(0)
            });
            it("Should return same Pool upon request", async () => {
                let pool = await BionicPoolRegistry.poolInfo(0);
                // let poolTiers = await BionicPoolRegistry.poolIdToTiers(0, 0);
                let pledgeTier = await BionicPoolRegistry.pledgeTiers(0);

                expect(pool.tokenAllocationStartTime).to.equal(tokenAllocationStartTime);
                expect(pool.pledgingEndTime).to.equal(PLEDGING_END_TIME);
                expect(pool.targetRaise).to.equal(targetRaise);
                expect(pledgeTier[0].maximumPledge).to.equal(pledgingTiers[0].maximumPledge);
                expect(pledgeTier[0].minimumPledge).to.equal(pledgingTiers[0].minimumPledge);
            })

        });


        describe("pledge", function () {
            // it("Should fail if not sent via TBA", async function () {
            //     await expect(BionicPoolRegistry.connect(client).pledge(0, 10, 32000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")))
            //         .to.be.revertedWith("Contract does not support BionicAccount");
            // });
            it("Should fail if Pool doesn't Exist", async function () {
                let raw = BionicPoolRegistry.interface.encodeFunctionData("pledge", [10000, 1000, 32000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")]);
                await expect(abstractedAccount.connect(client).execute(BionicPoolRegistry.address, 0, raw, 0))
                    .to.be.revertedWithCustomError(BionicPoolRegistry, "BPR__InvalidPool")//("pledge: Invalid PID");
            });

            it("Should fail if not enough amount pledged", async function () {
                let raw = BionicPoolRegistry.interface.encodeFunctionData("pledge", [0, 0, 32000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")]);
                await helpers.time.increaseTo(PLEDGING_START_TIME + 10);
                await expect(abstractedAccount.connect(client).execute(BionicPoolRegistry.address, 0, raw, 0))
                    .to.be.revertedWithCustomError(BionicPoolRegistry, "BPR__NotValidPledgeAmount").withArgs(0);
            });

            it("Should fail if pledge exceeds the max user share", async function () {
                let raw = BionicPoolRegistry.interface.encodeFunctionData("pledge", [0, 1001, 32000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")]);
                await expect(abstractedAccount.connect(client).execute(BionicPoolRegistry.address, 0, raw, 0))
                    .to.be.revertedWithCustomError(BionicPoolRegistry, "BPR__NotValidPledgeAmount").withArgs(1001);
            });
            it("Should fail if Not Enough Stake on the account", async function () {
                let raw = BionicPoolRegistry.interface.encodeFunctionData("pledge", [0, 1000, 32000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")]);
                await expect(abstractedAccount.connect(client).execute(BionicPoolRegistry.address, 0, raw, 0))
                    .to.be.revertedWithCustomError(BionicPoolRegistry, "BPR__NotEnoughStake");
            });
            it("Should fail if expired deadline", async function () {
                await bionicContract.transfer(abstractedAccount.address, BionicPoolRegistry.MINIMUM_BIONIC_STAKE());
                let raw = BionicPoolRegistry.interface.encodeFunctionData("pledge", [0, 1000, 32000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")]);
                await expect(abstractedAccount.connect(client).execute(BionicPoolRegistry.address, 0, raw, 0))
                    .to.be.revertedWith("CurrencyPermit: expired deadline");
            });
            it("Should fail on invalid signature", async function () {
                let raw = BionicPoolRegistry.interface.encodeFunctionData("pledge", [0, 1000, 32000000000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")]);
                await expect(abstractedAccount.connect(client).execute(BionicPoolRegistry.address, 0, raw, 0))
                    .to.be.revertedWith("ECDSA: invalid signature");
            });
            it("Should pledge user and permit contract to move amount", async function () {
                const deadline = ethers.constants.MaxUint256;
                for (let i = 0; i < AbstractAccounts.length; i++) {
                    const aac = AbstractAccounts[i];
                    await bionicContract.transfer(aac.address, BionicPoolRegistry.MINIMUM_BIONIC_STAKE());
                    const alreadyPledged = await BionicPoolRegistry.userTotalPledge(aac.address);
                    const amount = BigNumber.from(1000);
                    await pledgeBySigner(aac, i == 0 ? client : signers[(i - 1) * 2], usdtContract, BionicPoolRegistry, amount, deadline, alreadyPledged)
                }
            });

            it("Should fail on updating pledge amount", async function () {
                const deadline = ethers.constants.MaxUint256;
                const alreadyPledged = await BionicPoolRegistry.userTotalPledge(abstractedAccount.address);
                const amount = BigNumber.from(20);
                // let treasuryAddress = await BionicPoolRegistry.treasury();
                // const treasuryOldBalance = await usdtContract.balanceOf(treasuryAddress);
                expect(alreadyPledged).to.equal(1000);
                const { v, r, s } = await getCurrencyPermitSignature(
                    client,
                    abstractedAccount,
                    usdtContract,
                    BionicPoolRegistry.address,
                    amount,
                    deadline
                )
                await network.provider.send("hardhat_mine", ["0x100"]); //mine 256 blocks
                let raw = BionicPoolRegistry.interface.encodeFunctionData("pledge", [0, amount, deadline, v, r, s]);
                await expect(abstractedAccount.connect(client).execute(BionicPoolRegistry.address, 0, raw, 0))
                    .to.revertedWithCustomError(BionicPoolRegistry, "BPR__AlreadyPledgedToThisPool");
                // .to.emit(BionicPoolRegistry, "Pledge").withArgs(abstractedAccount.address, 0, amount)
                // .to.emit(abstractedAccount, "CurrencyApproval").withArgs(usdtContract.address, BionicPoolRegistry.address, amount)
                // .to.emit(BionicPoolRegistry, "PledgeFunded").withArgs(abstractedAccount.address, 0, amount);
                // expect(await usdtContract.balanceOf(treasuryAddress)).to.equal(amount.add(treasuryOldBalance))
                // expect(await abstractedAccount.allowance(usdtContract.address, BionicPoolRegistry.address)).to.equal(0).not.equal(amount);
            });

        });
    })


    describe("BionicTokenDistributor", function () {
        const investors: any = [];
        let merkleTree: StandardMerkleTree<any[]>;
        before(async () => {
            for (let i = 0; i < 10; i++) {
                investors.push([0, signers[i].address, 2000 * i + 1000]);
            }
            merkleTree = StandardMerkleTree.of(investors, ['uint256', 'address', 'uint256']);
        });

        describe("registerProjectToken", () => {
            it("Should fail if not owner", async function () {
                await expect(DistributorContract.connect(client).registerProjectToken(0, bionicContract.address, 0, 0, 0, merkleTree.root))
                    .to.be.revertedWith("Ownable: caller is not the owner");
            });
            it("Should register a new project", async function () {
                const tx = await DistributorContract.registerProjectToken(0, bionicContract.address, 10, tokenAllocationStartTime, 2, merkleTree.root);
                const config = await DistributorContract.s_projectTokens(0);
                expect(config.token).to.equal(bionicContract.address);
                expect(config.merkleRoot).to.equal(merkleTree.root);
            });
        });
        describe("claim", () => {
            it("Should fail if not registered", async function () {
                const investor = investors[0];
                await expect(DistributorContract.connect(client).claim(1, signers[0].address, investor[2], merkleTree.getProof(investor)))
                    .to.be.revertedWithCustomError(DistributorContract, "Distributor__InvalidProject");
            });
            it("Should fail if not valid proof", async function () {
                const investor = investors[0];
                await expect(DistributorContract.claim(0, signers[1].address, investor[2], merkleTree.getProof(investor)))
                    .to.be.revertedWithCustomError(DistributorContract, "Distributor__NotEligible");
            });
            it("Should fail if not enough balance", async function () {
                const investor = investors[0];
                await helpers.time.increaseTo(tokenAllocationStartTime + CYCLE_IN_SECONDS + 10);
                await expect(DistributorContract.claim(0, signers[0].address, investor[2], merkleTree.getProof(investor)))
                    .to.be.revertedWithCustomError(DistributorContract, "Distributor__NotEnoughTokenLeft");
            });
            it("Should claim the investment", async function () {
                const investor = investors[0];
                const treasury = 10e10, claimable = investor[2] * 10;
                await bionicContract.transfer(DistributorContract.address, treasury);
                await network.provider.send("hardhat_mine", ["0x100"]); //mine 256 blocks

                expect(await bionicContract.balanceOf(DistributorContract.address)).to.equal(treasury);
                expect(await bionicContract.balanceOf(signers[0].address)).to.equal(0);


                await expect(DistributorContract.claim(0, signers[0].address, investor[2], merkleTree.getProof(investor)))
                    .to.emit(DistributorContract, "Claimed").withArgs(0, signers[0].address, 1, claimable);

                expect(await bionicContract.balanceOf(signers[0].address)).to.equal(claimable);
                expect(await bionicContract.balanceOf(DistributorContract.address)).to.equal(treasury - claimable);
            });
            it("Should fail to claim twice", async function () {
                const investor = investors[0];
                await expect(DistributorContract.claim(0, signers[0].address, investor[2], merkleTree.getProof(investor)))
                    .to.be.revertedWithCustomError(DistributorContract, "Distributor__NothingToClaim");
            });
            it("Should claim whole revenue ", async function () {
                const investor = investors[0];
                const treasury = 10e10, claimable = investor[2] * 10;
                await helpers.time.increaseTo(tokenAllocationStartTime + CYCLE_IN_SECONDS * 3);


                await expect(DistributorContract.claim(0, signers[0].address, investor[2], merkleTree.getProof(investor)))
                    .to.emit(DistributorContract, "Claimed").withArgs(0, signers[0].address, 1, claimable);

                expect(await bionicContract.balanceOf(signers[0].address)).to.equal(claimable * 2);
                expect(await bionicContract.balanceOf(DistributorContract.address)).to.equal(treasury - claimable * 2);
            });
        });
    });





});

async function getPermitSignature(signer: SignerWithAddress, token: IERC20Permit | any, spender: string, value: BigNumber, deadline: BigNumber = ethers.constants.MaxUint256) {
    const [nonce, name, version, chainId] = await Promise.all([
        token.nonces(signer.address),
        token.name(),
        "1",
        signer.getChainId(),
    ])


    return ethers.utils.splitSignature(
        await signer._signTypedData(
            {
                name,
                version,
                chainId,
                verifyingContract: token.address.toLowerCase(),
            },
            {
                Permit: [
                    {
                        name: "owner",
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
                owner: signer.address,
                spender,
                value,
                nonce,
                deadline,
            }
        )
    )
}
async function getCurrencyPermitSignature(signer: SignerWithAddress, account: BionicAccount, currency: IERC20, spender: string, value: BigNumber, deadline: BigNumber = ethers.constants.MaxUint256) {
    const [nonce, name, version, chainId] = await Promise.all([
        account.getNonce(),
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


async function deployBionic() {
    const BionicFTContract = await ethers.getContractFactory("Bionic");
    console.log("Deploying Bionic contract...");
    let bionicContract = await upgrades.deployProxy(BionicFTContract, [], {
        initializer: "initialize",
        // unsafeAllow: ['delegatecall']
    });
    return await bionicContract.deployed();
}
async function deployBIP() {
    const BIPContract = await ethers.getContractFactory("BionicInvestorPass");
    console.log("Deploying BionicInvestorPass contract...");
    let bipContract = await upgrades.deployProxy(BIPContract, [], {
        initializer: "initialize",
        unsafeAllow: ['delegatecall']
    });
    return await bipContract.deployed();
}
async function deployBionicPoolRegistry(...args: any) {
    const BionicPoolRegistryContract = await ethers.getContractFactory("BionicPoolRegistry", {
        libraries: {
        }
    });
    let BRPContract = await upgrades.deployProxy(BionicPoolRegistryContract, args, {
        initializer: "initialize",
        unsafeAllow: ['delegatecall']
    });
    await BRPContract.deployed();

    console.log(`Deploying BionicPoolRegistry contract...`);
    return BRPContract as BionicPoolRegistry;
}
async function deployBionicTokenDistributor() {
    const BionicTokenDistributorContract = await ethers.getContractFactory("BionicTokenDistributor");
    console.log(`Deploying BionicTokenDistributor contract...`);
    return await BionicTokenDistributorContract.deploy();
}
async function deployTBA(entryPointAddress: string, guardianAddress: string) {
    const BionicAccountFactory = await ethers.getContractFactory("BionicAccount");
    let contract = await BionicAccountFactory.deploy(entryPointAddress, entryPointAddress, ERC6551_REGISTRY_ADDR, guardianAddress);

    console.log(`Deploying TBA contract...`);

    return contract;
}
async function deployVRFCoordinatorV2Mock() {
    const VRFCoordinatorV2MockFactory = await ethers.getContractFactory("VRFCoordinatorV2Mock");
    console.log("Deploying VRFCoordinatorV2Mock contract...");
    /**
     * @dev Read more at https://docs.chain.link/docs/chainlink-vrf/
     */
    const BASE_FEE = "100000000000000000"
    const GAS_PRICE_LINK = "1000000000" // 0.000000001 LINK per gas

    const VRFCoordinatorV2MockContract: VRFCoordinatorV2Mock = await VRFCoordinatorV2MockFactory.deploy(
        BASE_FEE,
        GAS_PRICE_LINK
    )

    const fundAmount = BigNumber.from(NETWORK_CONFIG["fundAmount"] || "1000000000000000000").mul(BigNumber.from(10000))
    const transaction = await VRFCoordinatorV2MockContract.createSubscription()
    const transactionReceipt = await transaction.wait(1)
    const subscriptionId = ethers.BigNumber.from(transactionReceipt?.events[0].topics[1])
    await VRFCoordinatorV2MockContract.fundSubscription(subscriptionId, fundAmount);

    return { VRFCoordinatorV2MockContract, subscriptionId }
}
// async function deployERC6551Registry() {
//     const ERC6551RegContract = await ethers.getContractFactory("ERC6551Registry");
//     console.log("Deploying BionicAccount contract...");

//     return await ERC6551RegContract.deploy();
// }

async function pledgeBySigner(aac: BionicAccount, signer: SignerWithAddress, usdtContract: ERC20, BionicPoolRegistry: BionicPoolRegistry, amount: BigNumber, deadline: BigNumber, alreadyPledged: BigNumber) {
    expect(await aac.owner()).to.equal(signer.address);
    const { v, r, s } = await getCurrencyPermitSignature(
        signer,
        aac,
        usdtContract,
        BionicPoolRegistry.address,
        amount,
        deadline
    )
    let treasuryAddress = await BionicPoolRegistry.treasury();
    let oldbalance = await usdtContract.balanceOf(treasuryAddress);
    let raw = BionicPoolRegistry.interface.encodeFunctionData("pledge", [0, amount, deadline, v, r, s]);
    await expect(aac.connect(signer).execute(BionicPoolRegistry.address, 0, raw, 0))
        .to.emit(BionicPoolRegistry, "Pledge").withArgs(aac.address, 0, amount)
        .to.emit(aac, "CurrencyApproval").withArgs(usdtContract.address, BionicPoolRegistry.address, amount)
        .to.emit(BionicPoolRegistry, "PledgeFunded").withArgs(aac.address, 0, amount);

    expect(oldbalance).to.not.equal(await usdtContract.balanceOf(treasuryAddress));
    expect(await usdtContract.balanceOf(treasuryAddress)).to.equal(oldbalance.add(alreadyPledged.add(amount)))
    expect(await aac.allowance(usdtContract.address, BionicPoolRegistry.address)).to.equal(0);
}