import { BigNumber } from "@ethersproject/bignumber";
import { expect } from "chai";
import { ethers, upgrades, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { IERC20Permit, ERC6551Registry, LaunchPoolFundRaisingWithVesting, ERC20, TokenBoundAccount, BionicInvestorPass, Bionic, IERC20, VRFCoordinatorV2Mock }
    from "../typechain-types";
import { BytesLike } from "ethers";



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
    ERC6551_REGISTERY_ADDR = "0x02101dfB77FDE026414827Fdc604ddAF224F0921",
    USDT_ADDR = "0x015cCFEe0249836D7C36C10C81a60872c64748bC", // on polygon network
    USDT_WHALE = "0xd8781f9a20e07ac0539cc0cbc112c65188658816", // on polygon network
    ACCOUNT_ADDRESS = "0xcBe55885F8C8d48dD729c336dba3f29a15d5F436",
    CALLBACK_GAS_LIMIT = 100000,
    WINNERS_COUNT = 5,
    PLEDGING_END_TIME = 40000000;

describe("e2e", function () {
    let bionicContract: Bionic, bipContract: BionicInvestorPass, fundWithVesting: LaunchPoolFundRaisingWithVesting,
        tokenBoundImpContract: TokenBoundAccount, abstractedAccount: TokenBoundAccount, usdtContract: ERC20,
        tokenBoundContractRegistry: ERC6551Registry;
    let owner: SignerWithAddress;
    let client: SignerWithAddress;
    let bionicDecimals: number;
    before(async () => {
        [owner, client] = await ethers.getSigners();
        bionicContract = await deployBionic();
        bipContract = await deployBIP();
        tokenBoundContractRegistry = await ethers.getContractAt("ERC6551Registry", ERC6551_REGISTERY_ADDR);
        usdtContract = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", USDT_ADDR);
        tokenBoundImpContract = await deployTBA();
        bionicDecimals = await bionicContract.decimals();
        abstractedAccount = await ethers.getContractAt("TokenBoundAccount", ACCOUNT_ADDRESS);


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


        // setup VRF_MOCK
        //replace with FWV contract
        let { VRFCoordinatorV2MockContract, subscriptionId } = await deployVRFCoordinatorV2Mock();

        const keyHash =
            NETWORK_CONFIG["keyHash"] ||
            "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc"

        // const RaffleFactory = await ethers.getContractFactory(
        //     "Raffle"
        // )
        // const raffleContract = await RaffleFactory
        //     .deploy(VRFCoordinatorV2MockContract.address, keyHash, subscriptionId, WINNERS_COUNT, CALLBACK_GAS_LIMIT, true);

        fundWithVesting = await deployFundWithVesting(bionicContract.address, bipContract.address, VRFCoordinatorV2MockContract.address, keyHash, subscriptionId, CALLBACK_GAS_LIMIT, true);
        await VRFCoordinatorV2MockContract.addConsumer(subscriptionId, fundWithVesting.address)

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
            await bionicContract.connect(client).approve(fundWithVesting.address, amount);
            expect(await bionicContract.allowance(client.address, fundWithVesting.address)).to.equal(amount);
        });
        it("Should permit fundVesting contract to move 10 on behalf of user", async function () {
            let amount = BigNumber.from(10).mul(BigNumber.from(10).pow(bionicDecimals));
            const deadline = ethers.constants.MaxUint256

            const { v, r, s } = await getPermitSignature(
                client,
                bionicContract,
                fundWithVesting.address,
                amount,
                deadline
            )
            await bionicContract.connect(client).permit(client.address, fundWithVesting.address, amount, deadline, v, r, s)
            expect(await bionicContract.allowance(client.address, fundWithVesting.address)).to.equal(amount);
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
            let res = await bipContract.safeMint(client.address, "https://linktoNFT.com");
            let r = await res.wait()
            expect(r.events[0].args[0]).to.equal('0x0000000000000000000000000000000000000000')
            expect(BigNumber.from(r.events[0].args[2])).to.equal(BigNumber.from(0))
        });
    });

    describe("TokenBoundAccount", () => {
        it("should Generate an address for SmartWallet", async () => {
            let res = await tokenBoundContractRegistry.account(tokenBoundImpContract.address,
                network.config.chainId as number, bipContract.address,
                "0", "0");
            expect(res).to.equal(ACCOUNT_ADDRESS);
        })
        it("should deploy a new address for the user based on their token", async () => {
            await network.provider.send("hardhat_mine", ["0x100"]); //mine 256 blocks
            let res = await tokenBoundContractRegistry.createAccount(tokenBoundImpContract.address,
                network.config.chainId as number, bipContract.address,
                "0", "0", []);
            let newAcc = await res.wait();
            expect(newAcc?.events[0]?.args?.account).to.equal(ACCOUNT_ADDRESS);
        })
        it("should permit fundingContract to transfer currencies out of users wallet", async () => {
            const deadline = ethers.constants.MaxUint256;
            const alreadyPledged = await abstractedAccount.allowance(client.address, fundWithVesting.address);
            expect(alreadyPledged).to.equal(BigNumber.from(0));
            const amount = BigNumber.from(10);
            const { v, r, s } = await getCurrencyPermitSignature(
                client,
                abstractedAccount,
                bionicContract,
                fundWithVesting.address,
                alreadyPledged.add(amount),
                deadline
            )


            await expect(abstractedAccount.connect(client).permit(bionicContract.address, fundWithVesting.address, amount, deadline, v, r, s))
                .to.emit(abstractedAccount, "CurrencyApproval").withArgs(bionicContract.address, fundWithVesting.address, amount);
            expect(await abstractedAccount.allowance(bionicContract.address, fundWithVesting.address)).to.equal(alreadyPledged.add(amount));
        })
    });
    describe("FundingRegistry", () => {
        describe("Add", function () {
            it("Should fail if the not BROKER", async function () {
                await expect(fundWithVesting.connect(client).add(bionicContract.address, 0, PLEDGING_END_TIME, 1000000000, 1000, WINNERS_COUNT, false))
                    .to.be.reverted;
            });
            it("Should allow BROKER to set new projects", async function () {
                expect(await fundWithVesting.hasRole(await fundWithVesting.BROKER_ROLE(), owner.address)).to.be.true;
                await expect(fundWithVesting.add(bionicContract.address, 0, PLEDGING_END_TIME, 1000000000, 1000, WINNERS_COUNT, false))
                    .to.emit(fundWithVesting, "PoolAdded").withArgs(0);
            });
            it("Should return same Pool upon request", async () => {
                let pool = await fundWithVesting.poolInfo(0);
                expect(pool.rewardToken).to.equal(bionicContract.address);
                expect(pool.tokenAllocationStartTime).to.equal(0);
                expect(pool.pledgingEndTime).to.equal(PLEDGING_END_TIME);
                expect(pool.targetRaise).to.equal(1000000000);
                expect(pool.maxPledgingAmountPerUser).to.equal(1000);
            })

        });


        describe("pledge", function () {
            it("Should fail if not sent via TBA", async function () {
                await expect(fundWithVesting.connect(client).pledge(0, 10, 32000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")))
                    .to.be.revertedWith("Contract does not support TokenBoundAccount");
            });
            it("Should fail if Pool doesn't Exist", async function () {
                let raw = fundWithVesting.interface.encodeFunctionData("pledge", [10000, 10, 32000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")]);
                await expect(abstractedAccount.connect(client).executeCall(fundWithVesting.address, 0, raw))
                    .to.be.revertedWith("pledge: Invalid PID")//("pledge: Invalid PID");
            });
            it("Should fail if not enough amount pledged", async function () {
                let raw = fundWithVesting.interface.encodeFunctionData("pledge", [0, 0, 32000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")]);
                await expect(abstractedAccount.connect(client).executeCall(fundWithVesting.address, 0, raw))
                    .to.be.revertedWith("pledge: No pledge specified");
            });

            it("Should fail if pledge exceeds the max user share", async function () {
                let raw = fundWithVesting.interface.encodeFunctionData("pledge", [0, 1001, 32000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")]);
                await expect(abstractedAccount.connect(client).executeCall(fundWithVesting.address, 0, raw))
                    .to.be.revertedWith("pledge: can not exceed max staking amount per user");
            });
            it("Should fail if expired deadline", async function () {
                let raw = fundWithVesting.interface.encodeFunctionData("pledge", [0, 10, 32000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")]);
                await expect(abstractedAccount.connect(client).executeCall(fundWithVesting.address, 0, raw))
                    .to.be.revertedWith("CurrencyPermit: expired deadline");
            });
            it("Should fail on invalid signature", async function () {
                let raw = fundWithVesting.interface.encodeFunctionData("pledge", [0, 10, 32000000000, 0, ethers.utils.formatBytes32String("0"), ethers.utils.formatBytes32String("0")]);
                await expect(abstractedAccount.connect(client).executeCall(fundWithVesting.address, 0, raw))
                    .to.be.revertedWith("ECDSA: invalid signature");
            });
            it("Should pledge user and permit contract to move amount", async function () {
                const deadline = ethers.constants.MaxUint256;
                const alreadyPledged = await fundWithVesting.userTotalPledge(abstractedAccount.address);
                expect(alreadyPledged).to.equal(0);
                const amount = BigNumber.from(10);
                const { v, r, s } = await getCurrencyPermitSignature(
                    client,
                    abstractedAccount,
                    usdtContract,
                    fundWithVesting.address,
                    alreadyPledged.add(amount),
                    deadline
                )

                let raw = fundWithVesting.interface.encodeFunctionData("pledge", [0, amount, deadline, v, r, s]);
                await expect(abstractedAccount.connect(client).executeCall(fundWithVesting.address, 0, raw))
                    .to.emit(fundWithVesting, "Pledge").withArgs(abstractedAccount.address, 0, amount)
                    .to.emit(abstractedAccount, "CurrencyApproval").withArgs(usdtContract.address, fundWithVesting.address, alreadyPledged.add(amount));
                expect(await abstractedAccount.allowance(usdtContract.address, fundWithVesting.address)).to.equal(alreadyPledged.add(amount));
            });

            it("Should add on user pledge and permit contract with new amount", async function () {
                const deadline = ethers.constants.MaxUint256;
                const alreadyPledged = await fundWithVesting.userTotalPledge(abstractedAccount.address);
                expect(alreadyPledged).to.not.equal(BigNumber.from(0));
                const amount = BigNumber.from(10);
                const { v, r, s } = await getCurrencyPermitSignature(
                    client,
                    abstractedAccount,
                    usdtContract,
                    fundWithVesting.address,
                    alreadyPledged.add(amount),
                    deadline
                )
                await network.provider.send("hardhat_mine", ["0x100"]); //mine 256 blocks
                let raw = fundWithVesting.interface.encodeFunctionData("pledge", [0, amount, deadline, v, r, s]);
                await expect(abstractedAccount.connect(client).executeCall(fundWithVesting.address, 0, raw))
                    .to.emit(fundWithVesting, "Pledge").withArgs(abstractedAccount.address, 0, amount)
                    .to.emit(abstractedAccount, "CurrencyApproval").withArgs(usdtContract.address, fundWithVesting.address, alreadyPledged.add(amount));
                expect(await abstractedAccount.allowance(usdtContract.address, fundWithVesting.address)).to.equal(alreadyPledged.add(amount)).not.equal(amount);
            });

            it("Should fail to start lottery with non sorting account", async () => {
                await expect(fundWithVesting.connect(client).draw(0))
                    .to.be.revertedWith("AccessControl: account 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 is missing role 0xee105fb4f48cea3e27a2ec9b51034ccdeeca8dc739abb494f43b522e54dd924d");
            })

            it("Should request random numbers for the pool Winners Raffle", async () => {
                await expect(fundWithVesting.draw(100000), "invalid poolId")
                    .to.revertedWithCustomError(fundWithVesting, "LPFRWV__InvalidPool");
                // await expect(fundWithVesting.draw(100000), "invalid poolId")
                //     .to.revertedWithCustomError(fundWithVesting, "LPFRWV__PoolIsOnPledgingPhase");

                await expect(fundWithVesting.draw(0))
                    .to.emit(fundWithVesting, "DrawInitiated").withArgs(0, 1);

                await expect(fundWithVesting.draw(0), "invalid poolId")
                    .to.revertedWithCustomError(fundWithVesting, "LPFRWV__DrawForThePoolHasAlreadyStarted");

            })


            // it("Should be able to move funds it's been allowed", async () => {
            //     const HUNDRED_THOUSAND = ethers.utils.parseUnits("100000", 6);

            //     expect(await usdtContract.balanceOf(fundWithVesting.address)).to.be.equal(0);
            //     expect(await usdtContract.balanceOf(abstractedAccount.address)).to.be.equal(HUNDRED_THOUSAND);
            //     let allowed = await abstractedAccount.allowance(usdtContract.address, fundWithVesting.address);
            //     let balance = await usdtContract.balanceOf(abstractedAccount.address)
            //     await expect(fundWithVesting.draw(0))
            //         .to.emit(fundWithVesting, "PledgeFunded").withArgs(abstractedAccount.address, 0, allowed);
            //     expect(await usdtContract.balanceOf(fundWithVesting.address)).to.be.equal(allowed);
            //     expect(await usdtContract.balanceOf(abstractedAccount.address)).to.be.equal(HUNDRED_THOUSAND.sub(allowed));
            // })


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
        account.nonces(signer.address),
        "Account",
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
async function deployFundWithVesting(tokenAddress: string, bionicInvsestorPass: string, vrfCoordinatorV2: string, gaslane: BytesLike, subId: BigNumber, cbGasLimit: number, reqVRFPerWinner: boolean) {
    const Lib = await ethers.getContractFactory("IterableMapping");
    const lib = await Lib.deploy();
    await lib.deployed();
    const FundWithVestingContract = await ethers.getContractFactory("LaunchPoolFundRaisingWithVesting", {
        libraries: {
            IterableMapping: lib.address
        }
    });
    console.log(`Deploying LaunchPoolFundRaisingWithVesting contract...`);
    return await FundWithVestingContract.deploy(tokenAddress, USDT_ADDR, bionicInvsestorPass, vrfCoordinatorV2, gaslane, subId, cbGasLimit, reqVRFPerWinner);
}
async function deployTBA() {
    const TBAContract = await ethers.getContractFactory("TokenBoundAccount");
    console.log("Deploying TokenBoundAccount contract...");

    return await TBAContract.deploy(ENTRY_POINT, ERC6551_REGISTERY_ADDR);
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

    const fundAmount = NETWORK_CONFIG["fundAmount"] || "1000000000000000000"
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