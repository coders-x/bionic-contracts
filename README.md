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
| Token Bound Account                           | -                                          | 0x34278B198852CCCD6Bd535eb08E45620dcf9ca3b | https://mumbai.polygonscan.com/address/0x34278B198852CCCD6Bd535eb08E45620dcf9ca3b#code |
| Token Bound Account Factory (ERC6551Registry) | -                                          | 0x02101dfB77FDE026414827Fdc604ddAF224F0921 | https://mumbai.polygonscan.com/address/0x02101dfB77FDE026414827Fdc604ddAF224F0921#code |

<!-- |                   Solc version: 0.8.20                    |  Optimizer enabled: true  |  Runs: 1000  |  Block limit: 30000000 gas  │
|-----------|----------------------||-----------||---------------------- -->
