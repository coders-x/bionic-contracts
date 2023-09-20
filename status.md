```bash
Test result: ok. 2 passed; 0 failed; 0 skipped; finished in 486.77s
| ERC6551Registry contract |                 |       |        |       |         |
|--------------------------|-----------------|-------|--------|-------|---------|
| Deployment Cost          | Deployment Size |       |        |       |         |
| 0                        | 0               |       |        |       |         |
| Function Name            | min             | avg   | median | max   | # calls |
| createAccount            | 73860           | 73860 | 73860  | 73860 | 1025    |


| EntryPoint contract |                 |      |        |       |         |
|---------------------|-----------------|------|--------|-------|---------|
| Deployment Cost     | Deployment Size |      |        |       |         |
| 0                   | 0               |      |        |       |         |
| Function Name       | min             | avg  | median | max   | # calls |
| getNonce            | 688             | 1688 | 1688   | 2688  | 2050    |
| incrementNonce      | 611             | 7244 | 611    | 20511 | 3075    |


| contracts/BIP.sol:BionicInvestorPass contract |                 |        |        |        |         |
|-----------------------------------------------|-----------------|--------|--------|--------|---------|
| Deployment Cost                               | Deployment Size |        |        |        |         |
| 3774147                                       | 18964           |        |        |        |         |
| Function Name                                 | min             | avg    | median | max    | # calls |
| balanceOf                                     | 2908            | 2908   | 2908   | 2908   | 1025    |
| initialize                                    | 192962          | 192962 | 192962 | 192962 | 2       |
| ownerOf                                       | 836             | 836    | 836    | 836    | 2050    |
| safeMint                                      | 57146           | 57171  | 57146  | 83046  | 1025    |


| contracts/Bionic.sol:Bionic contract |                 |        |        |        |         |
|--------------------------------------|-----------------|--------|--------|--------|---------|
| Deployment Cost                      | Deployment Size |        |        |        |         |
| 2770690                              | 13953           |        |        |        |         |
| Function Name                        | min             | avg    | median | max    | # calls |
| initialize                           | 245636          | 245636 | 245636 | 245636 | 2       |


| contracts/Launcpad/BionicFundRaising.sol:BionicFundRaising contract |                 |           |           |           |         |
|---------------------------------------------------------------------|-----------------|-----------|-----------|-----------|---------|
| Deployment Cost                                                     | Deployment Size |           |           |           |         |
| 3586279                                                             | 17792           |           |           |           |         |
| Function Name                                                       | min             | avg       | median    | max       | # calls |
| add                                                                 | 424629          | 424629    | 424629    | 424629    | 2       |
| addToTier                                                           | 13905090        | 58210726  | 58210726  | 102516362 | 2       |
| claimFund                                                           | 518             | 518       | 518       | 518       | 2       |
| draw                                                                | 257575783       | 257575783 | 257575783 | 257575783 | 1       |
| getRaffleWinners                                                    | 148895          | 148895    | 148895    | 148895    | 2       |
| pledge                                                              | 140761          | 140832    | 140761    | 214461    | 1025    |
| poolInfo                                                            | 1653            | 1653      | 1653      | 1653      | 2       |
| rawFulfillRandomWords                                               | 99400781        | 99400781  | 99400781  | 99400781  | 1       |


| contracts/Launcpad/Claim.sol:ClaimFunding contract |                 |         |        |          |         |
|----------------------------------------------------|-----------------|---------|--------|----------|---------|
| Deployment Cost                                    | Deployment Size |         |        |          |         |
| 736435                                             | 3657            |         |        |          |         |
| Function Name                                      | min             | avg     | median | max      | # calls |
| addWinningInvestors                                | 211255          | 9233901 | 276955 | 36170442 | 4       |
| batchClaim                                         | 2007            | 52034   | 52034  | 102062   | 2       |
| claimTokens                                        | 1266            | 25772   | 7200   | 50311    | 1011    |
| claimableAmount                                    | 1653            | 2749    | 2752   | 2752     | 502     |
| owner                                              | 377             | 377     | 377    | 377      | 3       |
| registerProjectToken                               | 91635           | 93301   | 93635  | 93635    | 6       |
| s_projectTokens                                    | 895             | 895     | 895    | 895      | 3       |
| s_userClaims                                       | 722             | 722     | 722    | 722      | 4       |


| contracts/Launcpad/Claim.t.sol:ERC20Mock contract |                 |       |        |       |         |
|---------------------------------------------------|-----------------|-------|--------|-------|---------|
| Deployment Cost                                   | Deployment Size |       |        |       |         |
| 632576                                            | 4077            |       |        |       |         |
| Function Name                                     | min             | avg   | median | max   | # calls |
| balanceOf                                         | 582             | 682   | 582    | 2582  | 20      |
| mint                                              | 46550           | 46550 | 46550  | 46550 | 3       |
| transfer                                          | 3010            | 17610 | 24910  | 24910 | 6       |


| contracts/Launcpad/Treasury.sol:Treasury contract |                 |      |        |      |         |
|---------------------------------------------------|-----------------|------|--------|------|---------|
| Deployment Cost                                   | Deployment Size |      |        |      |         |
| 281043                                            | 1468            |      |        |      |         |
| Function Name                                     | min             | avg  | median | max  | # calls |
| withdrawTo                                        | 4220            | 4223 | 4220   | 6220 | 525     |


| contracts/TBA.sol:TokenBoundAccount contract |                 |        |        |        |         |
|----------------------------------------------|-----------------|--------|--------|--------|---------|
| Deployment Cost                              | Deployment Size |        |        |        |         |
| 2228416                                      | 12714           |        |        |        |         |
| Function Name                                | min             | avg    | median | max    | # calls |
| CURRENCY_PERMIT_TYPEHASH                     | 203             | 203    | 203    | 203    | 1025    |
| DOMAIN_SEPARATOR                             | 632             | 632    | 632    | 632    | 1025    |
| executeCall                                  | 149234          | 149305 | 149234 | 222934 | 1025    |
| nonce                                        | 3672            | 3674   | 3672   | 6172   | 1025    |
| permit                                       | 53617           | 53617  | 53617  | 53617  | 1025    |
| token                                        | 1212            | 1212   | 1212   | 1212   | 1025    |
| transferCurrency                             | 6387            | 6404   | 6387   | 23907  | 1025    |


| contracts/libs/Utils.sol:Utils contract |                 |          |          |          |         |
|-----------------------------------------|-----------------|----------|----------|----------|---------|
| Deployment Cost                         | Deployment Size |          |          |          |         |
| 171429                                  | 888             |          |          |          |         |
| Function Name                           | min             | avg      | median   | max      | # calls |
| excludeAddresses                        | 13836084        | 62133587 | 81366384 | 91198293 | 3       |


| contracts/libs/VRFCoordinatorV2Mock.sol:VRFCoordinatorV2Mock contract |                 |          |          |          |         |
|-----------------------------------------------------------------------|-----------------|----------|----------|----------|---------|
| Deployment Cost                                                       | Deployment Size |          |          |          |         |
| 1027879                                                               | 5189            |          |          |          |         |
| Function Name                                                         | min             | avg      | median   | max      | # calls |
| addConsumer                                                           | 47510           | 47510    | 47510    | 47510    | 2       |
| createSubscription                                                    | 46459           | 46459    | 46459    | 46459    | 2       |
| fulfillRandomWords                                                    | 99390242        | 99390242 | 99390242 | 99390242 | 1       |
| fundSubscription                                                      | 3094            | 3094     | 3094     | 3094     | 2       |
| requestRandomWords                                                    | 43290           | 43290    | 43290    | 43290    | 1       |


| test/BionicFundRaising.t.sol:ERC20Mock contract |                 |       |        |       |         |
|-------------------------------------------------|-----------------|-------|--------|-------|---------|
| Deployment Cost                                 | Deployment Size |       |        |       |         |
| 632576                                          | 4077            |       |        |       |         |
| Function Name                                   | min             | avg   | median | max   | # calls |
| balanceOf                                       | 582             | 582   | 582    | 582   | 2001    |
| mint                                            | 24650           | 24692 | 24650  | 46550 | 1026    |
| transfer                                        | 3010            | 8362  | 3010   | 24910 | 2050    |


| test/BionicFundRaising.t.sol:UUPSProxy contract |                 |        |        |        |         |
|-------------------------------------------------|-----------------|--------|--------|--------|---------|
| Deployment Cost                                 | Deployment Size |        |        |        |         |
| 70448                                           | 1169            |        |        |        |         |
| Function Name                                   | min             | avg    | median | max    | # calls |
| balanceOf                                       | 3227            | 3227   | 3227   | 3227   | 1025    |
| initialize                                      | 193275          | 219612 | 219612 | 245949 | 4       |
| ownerOf                                         | 1155            | 1155   | 1155   | 1155   | 2050    |
| safeMint                                        | 57471           | 57500  | 57471  | 87871  | 1025    |

```
