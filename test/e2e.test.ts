import { BigNumber } from "@ethersproject/bignumber";
import { expect } from "chai";
import { ethers, upgrades, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, utils } from "ethers";
import { IERC20Permit, ERC6551Registry, LaunchPoolFundRaisingWithVesting } from "../typechain-types";

const ENTRY_POINT = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",
    ERC6551RegAddr = "0x02101dfB77FDE026414827Fdc604ddAF224F0921",
    PLEDGING_END_BLOCK = 40000000;

describe("e2e", function () {
    let bionicContract: Contract | any, bipContract: Contract | any, fundWithVesting: LaunchPoolFundRaisingWithVesting,
        tokenBoundContract: Contract | any, tokenBoundContractRegistry: ERC6551Registry;
    let owner: SignerWithAddress;
    let client: SignerWithAddress;
    let bionicDecimals: number;
    before(async () => {
        [owner, client] = await ethers.getSigners();
        bionicContract = await deployBionic();
        bipContract = await deployBIP();
        tokenBoundContractRegistry = await ethers.getContractAt("ERC6551Registry", ERC6551RegAddr);
        tokenBoundContract = await deployTBA();
        fundWithVesting = await deployFundWithVesting(bionicContract.address);
        bionicDecimals = await bionicContract.decimals();
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
        let accountAddress = "0xcBe55885F8C8d48dD729c336dba3f29a15d5F436";
        it("should Generate an address for SmartWallet", async () => {
            let res = await tokenBoundContractRegistry.account(tokenBoundContract.address,
                network.config.chainId as number, bipContract.address,
                "0", "0");
            expect(res).to.equal(accountAddress);
        })
        it("should deploy a new address for the user based on their token", async () => {
            let balance = await owner.getBalance();
            await network.provider.send("hardhat_mine", ["0x100"]); //mine 256 blocks
            let res = await tokenBoundContractRegistry.createAccount(tokenBoundContract.address,
                network.config.chainId as number, bipContract.address,
                "0", "0", []);
            let newAcc = await res.wait();
            expect(newAcc?.events[0]?.args?.account).to.equal(accountAddress);
        })
    });
    describe("FundingRegistry", () => {
        describe("Add", function () {
            it("Should fail if the not BROKER", async function () {
                await expect(fundWithVesting.connect(client).add(bionicContract.address, 0, PLEDGING_END_BLOCK, 1000000000, 1000, false))
                    .to.be.reverted;
            });
            it("Should allow BROKER to set new projects", async function () {
                expect(await fundWithVesting.hasRole(await fundWithVesting.BROKER_ROLE(), owner.address)).to.be.true;
                await expect(fundWithVesting.add(bionicContract.address, 0, PLEDGING_END_BLOCK, 1000000000, 1000, false))
                    .to.emit(fundWithVesting, "PoolAdded").withArgs(0);
            });
            it("Should return same Pool upon request", async () => {
                let pool = await fundWithVesting.poolInfo(0);
                expect(pool.rewardToken).to.equal(bionicContract.address);
                expect(pool.tokenAllocationStartBlock).to.equal(0);
                expect(pool.pledgingEndBlock).to.equal(PLEDGING_END_BLOCK);
                expect(pool.targetRaise).to.equal(1000000000);
                expect(pool.maxPledgingAmountPerUser).to.equal(1000);
            })
        });


        describe("pledge", function () {
            it("Should fail if Pool doesn't Exist", async function () {
                await expect(fundWithVesting.connect(client).pledge(10000, 10, 32000, 0, utils.formatBytes32String("0"), utils.formatBytes32String("0")))
                    .to.be.revertedWith("pledge: Invalid PID");
            });
            it("Should fail if expired deadline", async function () {
                await expect(fundWithVesting.connect(client).pledge(0, 10, 32000, 0, utils.formatBytes32String("0"), utils.formatBytes32String("0")))
                    .to.be.revertedWith("ERC20Permit: expired deadline");
            });
            it("Should fail if not enough amount pledged", async function () {
                await expect(fundWithVesting.connect(client).pledge(0, 0, 32000, 0, utils.formatBytes32String("0"), utils.formatBytes32String("0")))
                    .to.be.revertedWith("pledge: No pledge specified");
            });
            it("Should fail if pledge exceeds the max user share", async function () {
                await expect(fundWithVesting.connect(client).pledge(0, 1001, 32000, 0, utils.formatBytes32String("0"), utils.formatBytes32String("0")))
                    .to.be.revertedWith("pledge: can not exceed max staking amount per user");
            });
            it("Should fail on invalid signature", async function () {
                await expect(fundWithVesting.connect(client).pledge(0, 10, 32000000000, 0, utils.formatBytes32String("0"), utils.formatBytes32String("0")))
                    .to.be.revertedWith("ECDSA: invalid signature");
            });
            it("Should pledge user and permit contract to move amount", async function () {
                const deadline = ethers.constants.MaxUint256;
                const alreadyPledged = await fundWithVesting.userTotalPledge(client.address);
                expect(alreadyPledged).to.equal(0);
                const amount = BigNumber.from(10);
                const { v, r, s } = await getPermitSignature(
                    client,
                    bionicContract,
                    fundWithVesting.address,
                    alreadyPledged.add(amount),
                    deadline
                )

                expect(await fundWithVesting.connect(client).pledge(0, amount, deadline, v, r, s))
                    .to.emit(fundWithVesting, "Pledge").withArgs(client.address, amount)
                    .to.emit(bionicContract, "Approval").withArgs(client.address, fundWithVesting.address, alreadyPledged.add(amount));
                expect(await bionicContract.allowance(client.address, fundWithVesting.address)).to.equal(alreadyPledged.add(amount));
            });

            it("Should add on user pledge and permit contract with new amount", async function () {
                const deadline = ethers.constants.MaxUint256;
                const alreadyPledged = await fundWithVesting.userTotalPledge(client.address);
                expect(alreadyPledged).to.not.equal(BigNumber.from(0));
                const amount = BigNumber.from(10);
                const { v, r, s } = await getPermitSignature(
                    client,
                    bionicContract,
                    fundWithVesting.address,
                    alreadyPledged.add(amount),
                    deadline
                )
                await network.provider.send("hardhat_mine", ["0x100"]); //mine 256 blocks
                expect(await fundWithVesting.connect(client).pledge(0, amount, deadline, v, r, s))
                    .to.emit(fundWithVesting, "Pledge").withArgs(client.address, amount)
                    .to.emit(bionicContract, "Approval").withArgs(client.address, fundWithVesting.address, alreadyPledged.add(amount));
                expect(await bionicContract.allowance(client.address, fundWithVesting.address)).to.equal(alreadyPledged.add(amount)).not.equal(amount);
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
                verifyingContract: token.address,
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
async function deployFundWithVesting(tokenAddress: string) {
    const BIPContract = await ethers.getContractFactory("LaunchPoolFundRaisingWithVesting");
    console.log("Deploying LaunchPoolFundRaisingWithVesting contract...");
    return await BIPContract.deploy(tokenAddress);
}
async function deployTBA() {
    const TBAContract = await ethers.getContractFactory("TokenBoundAccount");
    console.log("Deploying TokenBoundAccount contract...");

    return await TBAContract.deploy(ENTRY_POINT, ERC6551RegAddr);
}
// async function deployERC6551Registry() {
//     const ERC6551RegContract = await ethers.getContractFactory("ERC6551Registry");
//     console.log("Deploying TokenBoundAccount contract...");

//     return await ERC6551RegContract.deploy();
// }