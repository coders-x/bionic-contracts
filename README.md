# bionic-contracts

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```

```
Successfully verified contract BionicInvestorPass on Etherscan.
https://mumbai.polygonscan.com/address/0x26C1FC685E9A39D00A34e731CAf1BEBA71C4EE61#code
Verifying proxy: 0xfFD890eBB19277f59f9d0810D464Efd2775df08E
Contract at 0xfFD890eBB19277f59f9d0810D464Efd2775df08E already verified.
Linking proxy 0xfFD890eBB19277f59f9d0810D464Efd2775df08E with implementation
Successfully linked proxy to implementation.
```

list of contracts deployed so fat

| Functionality      | Proxy | Implementaion| URL|
| ----------- | ----------- |----------- |----------- |
| BionicInvestorPass      | 0xfFD890eBB19277f59f9d0810D464Efd2775df08E       | 0x26C1FC685E9A39D00A34e731CAf1BEBA71C4EE61 | https://mumbai.polygonscan.com/address/0x26C1FC685E9A39D00A34e731CAf1BEBA71C4EE61#code| 
| Bionic Token      | 0xa0262DCE141a5C9574B2Ae8a56494aeFe7A28c8F       | 0xcc25bbC5B66F5379eEdD804D7a2efa647B8a008F | https://mumbai.polygonscan.com/address/0xcc25bbC5B66F5379eEdD804D7a2efa647B8a008F#code |