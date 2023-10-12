# bionic-contracts

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node --fork https://eth-mainnet.alchemyapi.io/v2/<key> --fork-block-number 14390000
npx hardhat run scripts/deploy.ts
```

```
an Abstracted account has been deployed on 0xCfAB0044E6A1CAe46cE2E6996fa6cD9199a8640A
```

list of contracts deployed so fat

| Functionality                                 | Proxy                                      | Implementaion                              | URL                                                                                    |
| --------------------------------------------- | ------------------------------------------ | ------------------------------------------ | -------------------------------------------------------------------------------------- |
| BionicInvestorPass                            | 0xfFD890eBB19277f59f9d0810D464Efd2775df08E | 0x26C1FC685E9A39D00A34e731CAf1BEBA71C4EE61 | https://mumbai.polygonscan.com/address/0x26C1FC685E9A39D00A34e731CAf1BEBA71C4EE61#code |
| Bionic Token                                  | 0xa0262DCE141a5C9574B2Ae8a56494aeFe7A28c8F | 0xcc25bbC5B66F5379eEdD804D7a2efa647B8a008F | https://mumbai.polygonscan.com/address/0xcc25bbC5B66F5379eEdD804D7a2efa647B8a008F#code |
| Token Bound Account                           | -                                          | 0x55FcaE61dF06858DC8115bDDd21B622F0634d8Ac | https://mumbai.polygonscan.com/address/0x55FcaE61dF06858DC8115bDDd21B622F0634d8Ac#code |
| Token Bound Account Factory (ERC6551Registry) | -                                          | 0x02101dfB77FDE026414827Fdc604ddAF224F0921 | https://mumbai.polygonscan.com/address/0x02101dfB77FDE026414827Fdc604ddAF224F0921#code |
| Bionic LaunchPad                              | -                                          | 0x486E0938DE02A54BbCcE7B867e449c9f9bd2fd10 | https://mumbai.polygonscan.com/address/0x486E0938DE02A54BbCcE7B867e449c9f9bd2fd10#code |

```bash

·-----------------------------------------------|---------------------------|--------------|-----------------------------·
|             Solc version: 0.8.20              ·  Optimizer enabled: true  ·  Runs: 1000  ·  Block limit: 30000000 gas  │
················································|···························|··············|······························
|  Methods                                                                                                               │
·························|······················|·············|·············|··············|···············|··············
|  Contract              ·  Method              ·  Min        ·  Max        ·  Avg         ·  # calls      ·  usd (avg)  │
·························|······················|·············|·············|··············|···············|··············
|  Bionic                ·  permit              ·      68025  ·      89508  ·       82347  ·            3  ·          -  │
·························|······················|·············|·············|··············|···············|··············
|  BionicFundRaising      ·  add                 ·          -  ·          -  ·      469704  ·            3  ·          -  │
·························|······················|·············|·············|··············|···············|··············
|  BionicFundRaising      ·  addToTier           ·      88642  ·     159536  ·      127614  ·            6  ·          -  │
·························|······················|·············|·············|··············|···············|··············
|  BionicFundRaising      ·  draw                ·          -  ·          -  ·      350967  ·            2  ·          -  │
·························|······················|·············|·············|··············|···············|··············
|  BionicInvestorPass    ·  safeMint            ·     112928  ·     130028  ·      114492  ·           22  ·          -  │
·························|······················|·············|·············|··············|···············|··············
|  ERC20Upgradeable      ·  approve             ·          -  ·          -  ·       50918  ·            1  ·          -  │
·························|······················|·············|·············|··············|···············|··············
|  ERC20Upgradeable      ·  transfer            ·      51510  ·      63675  ·       52544  ·           12  ·          -  │
·························|······················|·············|·············|··············|···············|··············
|  ERC6551Registry       ·  createAccount       ·      96309  ·      96321  ·       96320  ·           22  ·          -  │
·························|······················|·············|·············|··············|···············|··············
|  TokenBoundAccount     ·  executeCall         ·     138623  ·     290964  ·      266349  ·           48  ·          -  │
·························|······················|·············|·············|··············|···············|··············
|  VRFCoordinatorV2Mock  ·  addConsumer         ·          -  ·          -  ·       71070  ·            1  ·          -  │
·························|······················|·············|·············|··············|···············|··············
|  VRFCoordinatorV2Mock  ·  createSubscription  ·          -  ·          -  ·       67522  ·            2  ·          -  │
·························|······················|·············|·············|··············|···············|··············
|  VRFCoordinatorV2Mock  ·  fulfillRandomWords  ·          -  ·          -  ·      278160  ·            3  ·          -  │
·························|······················|·············|·············|··············|···············|··············
|  VRFCoordinatorV2Mock  ·  fundSubscription    ·          -  ·          -  ·       29309  ·            1  ·          -  │
·························|······················|·············|·············|··············|···············|··············
|  Deployments                                  ·                                          ·  % of limit   ·             │
················································|·············|·············|··············|···············|··············
|  Bionic                                       ·          -  ·          -  ·     2911243  ·        9.7 %  ·          -  │
················································|·············|·············|··············|···············|··············
|  BionicFundRaising                             ·          -  ·          -  ·     4080172  ·       13.6 %  ·          -  │
················································|·············|·············|··············|···············|··············
|  BionicInvestorPass                           ·          -  ·          -  ·     4071479  ·       13.6 %  ·          -  │
················································|·············|·············|··············|···············|··············
|  ERC6551Registry                              ·          -  ·          -  ·      287627  ·          1 %  ·          -  │
················································|·············|·············|··············|···············|··············
|  IterableMapping                              ·          -  ·          -  ·      334972  ·        1.1 %  ·          -  │
················································|·············|·············|··············|···············|··············
|  TokenBoundAccount                            ·          -  ·          -  ·     2315283  ·        7.7 %  ·          -  │
················································|·············|·············|··············|···············|··············
|  Utils                                        ·          -  ·          -  ·      236061  ·        0.8 %  ·          -  │
················································|·············|·············|··············|···············|··············
|  VRFCoordinatorV2Mock                         ·          -  ·          -  ·     1153373  ·        3.8 %  ·          -  │
·-----------------------------------------------|-------------|-------------|--------------|---------------|-------------·


```
