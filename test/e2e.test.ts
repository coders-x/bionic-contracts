import { BigNumber } from "@ethersproject/bignumber";
import { expect } from "chai";
import { ethers, upgrades, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
    IERC20Permit, ERC6551Registry, BionicFundRaising, ERC20Upgradeable, TokenBoundAccount, MockEntryPoint,
    BionicInvestorPass, Bionic, VRFCoordinatorV2Mock, ClaimFunding, ERC20
}
    from "../typechain-types";
import { BionicStructs } from "../typechain-types/contracts/Launcpad/BionicFundRaising";
import { BytesLike } from "ethers";

const helpers = require("@nomicfoundation/hardhat-network-helpers");


const NETWORK_CONFIG = {
    name: "mumbai",
    linkToken: "0x326C977E6efc84E512bB9C30f76E30c160eD06FB",
    ethUsdPriceFeed: "0x0715A7794a1dc8e42615F059dD6e406A6594651A",
    keyHash: "0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f",
    vrfCoordinator: "0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed",
    vrfWrapper: "0x99aFAf084eBA697E584501b8Ed2c0B37Dd136693",
    oracle: "0x40193c8518BB267228Fc409a613bDbD8eC5a97b3",
    jobId: "ca98366cc7314957b8c012c72f05aeeb",
    fee: "100000000000000000",
    fundAmount: "100000000000000000", // 0.1
    automationUpdateInterval: "30",
};

const ENTRY_POINT = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",
    ERC6551_REGISTERY_ADDR = "0x953cbf74fD8736C97c61fc1c0f2b8A2959e5A328",
    USDT_ADDR = "0x015cCFEe0249836D7C36C10C81a60872c64748bC", // on polygon network
    USDT_WHALE = "0xd8781f9a20e07ac0539cc0cbc112c65188658816", // on polygon network
    ACCOUNT_ADDRESS = "0x0a54aa8deB3536dD6E3B890C16C18d203e88C0d0",
    CALLBACK_GAS_LIMIT_PER_USER = 90300,
    REQUEST_VRF_PER_WINNER = true,
    PLEDGING_START_TIME = 20000000,
    PLEDGING_END_TIME = 2694616991,
    tokenAllocationStartTime = PLEDGING_END_TIME + 1000,
    PLEDGE_AMOUNT = 1000,
    TIER_ALLOCATION = [3, 2, 1];

describe("e2e", function () {
    let bionicContract: Bionic, bipContract: BionicInvestorPass, BionicFundRaising: BionicFundRaising,
        tokenBoundImpContract: TokenBoundAccount, abstractedAccount: TokenBoundAccount, AbstractAccounts: TokenBoundAccount[],
        usdtContract: ERC20Upgradeable, tokenBoundContractRegistry: ERC6551Registry, vrfCoordinatorV2MockContract: VRFCoordinatorV2Mock,
        claimContract: ClaimFunding, mockEntryPoint: MockEntryPoint;
    let owner: SignerWithAddress, client: SignerWithAddress, guardian: SignerWithAddress;
    let signers: SignerWithAddress[];
    let bionicDecimals: number;
    let pledgingTiers: BionicStructs.PledgeTierStruct[]

    before(async () => {
        [owner, client, guardian, ...signers] = await ethers.getSigners();
        bionicContract = await deployBionic();
        bipContract = await deployBIP();
        let TokenBoundContractRegistryFacory = await ethers.getContractFactory("ERC6551Registry");
        tokenBoundContractRegistry = await TokenBoundContractRegistryFacory.deploy();
        let MockEntryPointFactory = await ethers.getContractFactory("MockEntryPoint");
        mockEntryPoint = await MockEntryPointFactory.deploy();
        tokenBoundContractRegistry = await TokenBoundContractRegistryFacory.deploy();
        usdtContract = await ethers.getContractAt("ERC20Upgradeable", USDT_ADDR);
        let AccountGuardianFactory = await ethers.getContractFactory("AccountGuardian");
        let accountGuardian = await AccountGuardianFactory.deploy();
        tokenBoundImpContract = await deployTBA(mockEntryPoint.address, accountGuardian.address);
        bionicDecimals = await bionicContract.decimals();
        abstractedAccount = await ethers.getContractAt("TokenBoundAccount", ACCOUNT_ADDRESS);
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
        let whaleBal = await usdtContract.balanceOf(USDT_WHALE);
        let tokenBoundAccBal = await usdtContract.balanceOf(abstractedAccount.address);
        const HUNDRED_THOUSAND = ethers.utils.parseUnits("100000", 6);
        await usdtContract.connect(whale).transfer(abstractedAccount.address, HUNDRED_THOUSAND);
        whaleBal = await usdtContract.balanceOf(USDT_WHALE);
        tokenBoundAccBal = await usdtContract.balanceOf(abstractedAccount.address);
        AbstractAccounts = [abstractedAccount];
        for (let i = 0; i < 10; i++) {
            //mint BIP 
            let res = await bipContract.safeMint(signers[(i * 2)].address, signers[(i * 2) + 1].address, "https://linktoNFT.com");
            let r = await res.wait()
            //@ts-ignore
            expect(BigNumber.from(r?.events[0]?.args.tokenId)).to.equal(BigNumber.from(i))
            //create abstracted accounts
            res = await tokenBoundContractRegistry.createAccount(tokenBoundImpContract.address,
                network.config.chainId as number, bipContract.address,
                i, "0", []);
            let newAcc = await res.wait(1);
            let acc = await ethers.getContractAt("TokenBoundAccount", newAcc?.events[0]?.args?.account);
            await usdtContract.connect(whale).transfer(acc.address, HUNDRED_THOUSAND);
            expect(await acc.owner()).to.equal(signers[i * 2].address);

            AbstractAccounts.push(acc);
        }


        // setup VRF_MOCK
        //replace with FWV contract
        let { VRFCoordinatorV2MockContract, subscriptionId } = await deployVRFCoordinatorV2Mock();

        const keyHash =
            NETWORK_CONFIG["keyHash"]


        vrfCoordinatorV2MockContract = VRFCoordinatorV2MockContract;
        BionicFundRaising = await deployBionicFundRaising(bionicContract.address, bipContract.address, VRFCoordinatorV2MockContract.address, keyHash, subscriptionId, REQUEST_VRF_PER_WINNER);
        claimContract = await ethers.getContractAt("ClaimFunding", await BionicFundRaising.claimFund())
        await VRFCoordinatorV2MockContract.addConsumer(subscriptionId, BionicFundRaising.address);

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
            await bionicContract.connect(client).approve(BionicFundRaising.address, amount);
            expect(await bionicContract.allowance(client.address, BionicFundRaising.address)).to.equal(amount);
        });
        it("Should permit fundVesting contract to move 10 on behalf of user", async function () {
            let amount = BigNumber.from(10).mul(BigNumber.from(10).pow(bionicDecimals));
            const deadline = ethers.constants.MaxUint256

            const { v, r, s } = await getPermitSignature(
                client,
                bionicContract,
                BionicFundRaising.address,
                amount,
                deadline
            )
            await bionicContract.connect(client).permit(client.address, BionicFundRaising.address, amount, deadline, v, r, s)
            expect(await bionicContract.allowance(client.address, BionicFundRaising.address)).to.equal(amount);
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

    describe("TokenBoundAccount", () => {
        it("should Generate an address for SmartWallet", async () => {
            let res = await tokenBoundContractRegistry.account(tokenBoundImpContract.address,
                network.config.chainId as number, bipContract.address,
                "10", "0");
            expect(res).to.equal(ACCOUNT_ADDRESS);
        })
        it("should deploy a new address for the user based on their token", async () => {
            await network.provider.send("hardhat_mine", ["0x100"]); //mine 256 blocks
            let res = await tokenBoundContractRegistry.createAccount(tokenBoundImpContract.address,
                network.config.chainId as number, bipContract.address,
                "10", "0", []);
            let newAcc = await res.wait();


            expect(newAcc?.events[0]?.args?.account).to.equal(ACCOUNT_ADDRESS);
        })
        it("should permit fundingContract to transfer currencies out of users wallet", async () => {
            const deadline = ethers.constants.MaxUint256;
            const token = await abstractedAccount.token();
            const alreadyPledged = await abstractedAccount.allowances(client.address, BionicFundRaising.address);
            expect(alreadyPledged).to.equal(BigNumber.from(0));
            const amount = BigNumber.from(10);
            const { v, r, s } = await getCurrencyPermitSignature(
                client,
                abstractedAccount,
                bionicContract,
                BionicFundRaising.address,
                alreadyPledged.add(amount),
                deadline
            )


            await expect(abstractedAccount.connect(client).permit(bionicContract.address, BionicFundRaising.address, amount, deadline, v, r, s))
                .to.emit(abstractedAccount, "CurrencyApproval").withArgs(bionicContract.address, BionicFundRaising.address, amount);
            expect(await abstractedAccount.allowance(bionicContract.address, BionicFundRaising.address)).to.equal(alreadyPledged.add(amount));
        })
    });
    describe("FundingRegistry", () => {
        describe("Add", function () {
            const tokenAllocationPerMonth = 100, tokenAllocationMonthCount = 10, targetRaise = PLEDGE_AMOUNT * PLEDGE_AMOUNT
            it("Should fail if the not BROKER", async function () {
                await expect(BionicFundRaising.connect(client)
                    .add(bionicContract.address, PLEDGING_START_TIME, PLEDGING_END_TIME, tokenAllocationPerMonth, tokenAllocationStartTime, tokenAllocationMonthCount, targetRaise, TIER_ALLOCATION, pledgingTiers))
                    .to.be.reverted;
            });
            it("Should allow BROKER to set new projects", async function () {
                expect(await BionicFundRaising.hasRole(await BionicFundRaising.BROKER_ROLE(), owner.address)).to.be.true;
                await expect(BionicFundRaising.add(bionicContract.address, PLEDGING_START_TIME, PLEDGING_END_TIME, tokenAllocationPerMonth, tokenAllocationStartTime, tokenAllocationMonthCount, targetRaise, TIER_ALLOCATION, pledgingTiers))
                    .to.emit(BionicFundRaising, "PoolAdded").withArgs(0)
                    .to.emit(claimContract, "ProjectAdded").withArgs(0, bionicContract.address, tokenAllocationPerMonth, tokenAllocationStartTime, tokenAllocationMonthCount);
            });
            it("Should return same Pool upon request", async () => {
                let pool = await BionicFundRaising.poolInfo(0);
                let poolTiers = await BionicFundRaising.poolIdToTiers(0, 0);

                expect(poolTiers).to.equal(3);
                expect(pool.rewardToken).to.equal(bionicContract.address);
                expect(pool.tokenAllocationStartTime).to.equal(tokenAllocationStartTime);
                expect(pool.pledgingEndTime).to.equal(PLEDGING_END_TIME);
                expect(pool.targetRaise).to.equal(targetRaise);
                // expect(pool.pledgeTiers).to.equal(pledgingTiers);
            })

        });


        describe("pledge", function () {
            // it("Should fail if not sent via TBA", async function () {
            //     await expect(BionicFundRaising.connect(client).pledge(0, 10, 32000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")))
            //         .to.be.revertedWith("Contract does not support TokenBoundAccount");
            // });
            it("Should fail if Pool doesn't Exist", async function () {
                let raw = BionicFundRaising.interface.encodeFunctionData("pledge", [10000, 1000, 32000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")]);
                await expect(abstractedAccount.connect(client).executeCall(BionicFundRaising.address, 0, raw))
                    .to.be.revertedWithCustomError(BionicFundRaising, "LPFRWV__InvalidPool")//("pledge: Invalid PID");
            });
            it("Should fail if not enough amount pledged", async function () {
                let raw = BionicFundRaising.interface.encodeFunctionData("pledge", [0, 0, 32000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")]);
                await expect(abstractedAccount.connect(client).executeCall(BionicFundRaising.address, 0, raw))
                    .to.be.revertedWithCustomError(BionicFundRaising, "LPFRWV__NotValidPledgeAmount").withArgs(0);
            });

            it("Should fail if pledge exceeds the max user share", async function () {
                let raw = BionicFundRaising.interface.encodeFunctionData("pledge", [0, 1001, 32000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")]);
                await expect(abstractedAccount.connect(client).executeCall(BionicFundRaising.address, 0, raw))
                    .to.be.revertedWithCustomError(BionicFundRaising, "LPFRWV__NotValidPledgeAmount").withArgs(1001);
            });
            it("Should fail if Not Enough Stake on the account", async function () {
                let raw = BionicFundRaising.interface.encodeFunctionData("pledge", [0, 1000, 32000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")]);
                await expect(abstractedAccount.connect(client).executeCall(BionicFundRaising.address, 0, raw))
                    .to.be.revertedWithCustomError(BionicFundRaising, "LPFRWV__NotEnoughStake");
            });
            it("Should fail if expired deadline", async function () {
                await bionicContract.transfer(abstractedAccount.address, BionicFundRaising.MINIMUM_BIONIC_STAKE());
                let raw = BionicFundRaising.interface.encodeFunctionData("pledge", [0, 1000, 32000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")]);
                await expect(abstractedAccount.connect(client).executeCall(BionicFundRaising.address, 0, raw))
                    .to.be.revertedWith("CurrencyPermit: expired deadline");
            });
            it("Should fail on invalid signature", async function () {
                let raw = BionicFundRaising.interface.encodeFunctionData("pledge", [0, 1000, 32000000000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")]);
                await expect(abstractedAccount.connect(client).executeCall(BionicFundRaising.address, 0, raw))
                    .to.be.revertedWith("ECDSA: invalid signature");
            });
            it("Should pledge user and permit contract to move amount", async function () {
                const deadline = ethers.constants.MaxUint256;
                for (let i = 0; i < AbstractAccounts.length; i++) {
                    const aac = AbstractAccounts[i];
                    await bionicContract.transfer(aac.address, BionicFundRaising.MINIMUM_BIONIC_STAKE());
                    const alreadyPledged = await BionicFundRaising.userTotalPledge(aac.address);
                    const amount = BigNumber.from(1000);
                    await pledgeBySigner(aac, i == 0 ? client : signers[(i - 1) * 2], usdtContract, BionicFundRaising, amount, deadline, alreadyPledged)
                }
            });

            it("Should fail on updating pledge amount", async function () {
                const deadline = ethers.constants.MaxUint256;
                const alreadyPledged = await BionicFundRaising.userTotalPledge(abstractedAccount.address);
                const amount = BigNumber.from(20);
                // let treasuryAddress = await BionicFundRaising.treasury();
                // const treasuryOldBalance = await usdtContract.balanceOf(treasuryAddress);
                expect(alreadyPledged).to.equal(1000);
                const { v, r, s } = await getCurrencyPermitSignature(
                    client,
                    abstractedAccount,
                    usdtContract,
                    BionicFundRaising.address,
                    amount,
                    deadline
                )
                await network.provider.send("hardhat_mine", ["0x100"]); //mine 256 blocks
                let raw = BionicFundRaising.interface.encodeFunctionData("pledge", [0, amount, deadline, v, r, s]);
                await expect(abstractedAccount.connect(client).executeCall(BionicFundRaising.address, 0, raw))
                    .to.revertedWithCustomError(BionicFundRaising, "LPFRWV__AlreadyPledgedToThisPool");
                // .to.emit(BionicFundRaising, "Pledge").withArgs(abstractedAccount.address, 0, amount)
                // .to.emit(abstractedAccount, "CurrencyApproval").withArgs(usdtContract.address, BionicFundRaising.address, amount)
                // .to.emit(BionicFundRaising, "PledgeFunded").withArgs(abstractedAccount.address, 0, amount);
                // expect(await usdtContract.balanceOf(treasuryAddress)).to.equal(amount.add(treasuryOldBalance))
                // expect(await abstractedAccount.allowance(usdtContract.address, BionicFundRaising.address)).to.equal(0).not.equal(amount);
            });


            it("Should fail to start lottery with non sorting account", async () => {
                await expect(BionicFundRaising.connect(client).draw(0, CALLBACK_GAS_LIMIT_PER_USER))
                    .to.be.revertedWith("AccessControl: account 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 is missing role 0xee105fb4f48cea3e27a2ec9b51034ccdeeca8dc739abb494f43b522e54dd924d");
            })
            it("Should fail to start if tiers haven't been added", async () => {
                await helpers.time.increaseTo(tokenAllocationStartTime);
                await expect(BionicFundRaising.draw(0, CALLBACK_GAS_LIMIT_PER_USER))
                    .to.revertedWithCustomError(BionicFundRaising, "LPFRWV__TiersHaveNotBeenInitialized");
            })

            it("should fail if member hasn't pledged to lottery", async () => {
                let pid = 0, tierId = 0, members = ["0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"];
                await expect(BionicFundRaising.addToTier(pid, tierId, members))
                    .to.revertedWithCustomError(BionicFundRaising, "LPFRWV__TierMembersShouldHaveAlreadyPledged")
                    .withArgs(pid, tierId);
            })
            it("should add user to tier 1", async () => {
                let pid = 0, tierId = 0, members = [abstractedAccount.address];
                await expect(BionicFundRaising.addToTier(pid, tierId, members))
                    .to.emit(BionicFundRaising, "TierInitiated").withArgs(pid, tierId, members);
            })
            it("should fail to add user to other tier", async () => {
                let pid = 0, tierId = 1, members = [abstractedAccount.address];
                await expect(BionicFundRaising.addToTier(pid, tierId, members))
                    .to.revertedWithCustomError(BionicFundRaising, "Raffle__MembersOnlyPermittedInOneTier")
                    .withArgs(members[0], 0, tierId);
            })
            it("should add users to tiers except for the last tier.", async () => {
                let pid = 0, j = 1;
                for (let tierId = 0; tierId < TIER_ALLOCATION.length - 1; tierId++) {
                    const members = AbstractAccounts.slice(j, j + TIER_ALLOCATION[tierId] + 1).map((v) => v.address);
                    j += TIER_ALLOCATION[tierId] + 1
                    await expect(BionicFundRaising.addToTier(pid, tierId, members))
                        .to.emit(BionicFundRaising, "TierInitiated").withArgs(pid, tierId, members);
                }
            })

            it("Should request random numbers for the pool Winners Raffle", async () => {
                await expect(BionicFundRaising.draw(100000, CALLBACK_GAS_LIMIT_PER_USER), "invalid poolId")
                    .to.revertedWithCustomError(BionicFundRaising, "LPFRWV__InvalidPool");

                await expect(BionicFundRaising.draw(0, CALLBACK_GAS_LIMIT_PER_USER))
                    .to.emit(BionicFundRaising, "DrawInitiated").withArgs(0, 1);

                await expect(BionicFundRaising.draw(0, CALLBACK_GAS_LIMIT_PER_USER), "invalid poolId")
                    .to.revertedWithCustomError(BionicFundRaising, "LPFRWV__DrawForThePoolHasAlreadyStarted");
            });

            it("Should Receive Random words and chose winners", async () => {
                const HUNDRED_THOUSAND = ethers.utils.parseUnits("100000", 6);
                const winners = ["0xD4048688ef20f099aF6410f4b7854C66EEaeD3dc",
                    "0x456DBFaf1504b310dE66FC8c9104024cB88d7B99",
                    "0xC888860fd040a139A8Ed3Ee51e6910c93e40a119",
                    "0xb414EE9B78f5dDad334C5b39395Bb36147c95095",
                    "0x8956039ECA16899Db65732c8175ffa440d481F64",
                    "0x389B436278b6d136bA0996c3F4a0Afc680fD79ED",]
                expect(await usdtContract.balanceOf(BionicFundRaising.address)).to.be.equal(0);
                expect(await usdtContract.balanceOf(abstractedAccount.address)).to.be.equal(HUNDRED_THOUSAND.sub(1000));
                await expect(
                    BionicFundRaising.refundLosers(
                        0
                    )
                ).to.revertedWithCustomError(BionicFundRaising, "LPFRWV__LotteryIsPending");

                // simulate callback from the oracle network
                await expect(
                    vrfCoordinatorV2MockContract.fulfillRandomWords(
                        1,
                        BionicFundRaising.address
                    )
                ).to.emit(BionicFundRaising, "WinnersPicked").withArgs(0, winners);
                // simulate callback from the oracle network
                await expect(
                    BionicFundRaising.refundLosers(
                        0
                    )
                )
                    .to.emit(BionicFundRaising, "LotteryRefunded");


                let losers = AbstractAccounts.filter((v, i) => !winners.includes(v.address) && i < 12)
                expect(losers.length).to.equal(5);
                for (const w of winners) {
                    let pledge = await BionicFundRaising.userTotalPledge(w)
                    expect(await usdtContract.balanceOf(w), "winners should have been paid their pledge").to.be.equal(HUNDRED_THOUSAND.sub(pledge));
                }

                for (const l of losers) {
                    expect(await usdtContract.balanceOf(l.address), "losers should get back their pledge deposit").to.be.equal(HUNDRED_THOUSAND);
                }
            });
        });
    })







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
async function getCurrencyPermitSignature(signer: SignerWithAddress, account: TokenBoundAccount, currency: IERC20, spender: string, value: BigNumber, deadline: BigNumber = ethers.constants.MaxUint256) {
    const [nonce, name, version, chainId] = await Promise.all([
        account.nonce(),
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
        unsafeAllow: ['delegatecall']
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
async function deployBionicFundRaising(tokenAddress: string, bionicInvsestorPass: string, vrfCoordinatorV2: string, gaslane: BytesLike, subId: BigNumber, reqVRFPerWinner: boolean) {
    // const IterableMappingLib = await ethers.getContractFactory("IterableMapping");
    // const lib = await IterableMappingLib.deploy();
    // await lib.deployed();
    const UtilsLib = await ethers.getContractFactory("Utils");
    const utils = await UtilsLib.deploy();
    await utils.deployed();
    const BionicFundRaisingContract = await ethers.getContractFactory("BionicFundRaising", {
        libraries: {
            Utils: utils.address
        }
    });
    console.log(`Deploying BionicFundRaising contract...`);
    return await BionicFundRaisingContract.deploy(tokenAddress, USDT_ADDR, bionicInvsestorPass, vrfCoordinatorV2, gaslane, subId, reqVRFPerWinner);
}
async function deployTBA(entryPoinAddress: string, guardianAddress: string) {
    const TokenBoundAccountFactory = await ethers.getContractFactory("TokenBoundAccount");
    let contract = await TokenBoundAccountFactory.deploy(guardianAddress, entryPoinAddress);

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
//     console.log("Deploying TokenBoundAccount contract...");

//     return await ERC6551RegContract.deploy();
// }

async function pledgeBySigner(aac: TokenBoundAccount, signer: SignerWithAddress, usdtContract: ERC20, BionicFundRaising: BionicFundRaising, amount: BigNumber, deadline: BigNumber, alreadyPledged: BigNumber) {
    expect(await aac.owner()).to.equal(signer.address);
    const { v, r, s } = await getCurrencyPermitSignature(
        signer,
        aac,
        usdtContract,
        BionicFundRaising.address,
        amount,
        deadline
    )
    let treasuryAddress = await BionicFundRaising.treasury();
    let oldbalance = await usdtContract.balanceOf(treasuryAddress);
    let raw = BionicFundRaising.interface.encodeFunctionData("pledge", [0, amount, deadline, v, r, s]);
    await expect(aac.connect(signer).executeCall(BionicFundRaising.address, 0, raw))
        .to.emit(BionicFundRaising, "Pledge").withArgs(aac.address, 0, amount)
        .to.emit(aac, "CurrencyApproval").withArgs(usdtContract.address, BionicFundRaising.address, amount)
        .to.emit(BionicFundRaising, "PledgeFunded").withArgs(aac.address, 0, amount);

    expect(oldbalance).to.not.equal(await usdtContract.balanceOf(treasuryAddress));
    expect(await usdtContract.balanceOf(treasuryAddress)).to.equal(oldbalance.add(alreadyPledged.add(amount)))
    expect(await aac.allowance(usdtContract.address, BionicFundRaising.address)).to.equal(0);
}