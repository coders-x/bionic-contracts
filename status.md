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
| balanceOf                            | 761             | 761    | 761    | 761    | 1025    |
| initialize                           | 245636          | 245636 | 245636 | 245636 | 2       |
| transfer                             | 28328           | 28336  | 28328  | 37128  | 1025    |


| contracts/Launcpad/BionicPoolRegistry.sol:BionicPoolRegistry contract |                 |           |           |           |         |
|---------------------------------------------------------------------|-----------------|-----------|-----------|-----------|---------|
| Deployment Cost                                                     | Deployment Size |           |           |           |         |
| 3686799                                                             | 18294           |           |           |           |         |
| Function Name                                                       | min             | avg       | median    | max       | # calls |
| MINIMUM_BIONIC_STAKE                                                | 669             | 669       | 669       | 669       | 1025    |
| add                                                                 | 424703          | 424703    | 424703    | 424703    | 2       |
| addToTier                                                           | 13905106        | 58210742  | 58210742  | 102516378 | 2       |
| claimFund                                                           | 526             | 526       | 526       | 526       | 2       |
| draw                                                                | 257576023       | 257576023 | 257576023 | 257576023 | 1       |
| getRaffleWinners                                                    | 148903          | 148903    | 148903    | 148903    | 2       |
| pledge                                                              | 142358          | 142431    | 142358    | 218058    | 1025    |
| poolInfo                                                            | 1664            | 1664      | 1664      | 1664      | 2       |
| rawFulfillRandomWords                                               | 23812174        | 23812174  | 23812174  | 23812174  | 1       |


| contracts/Launcpad/Claim.sol:ClaimFunding contract |                 |         |        |          |         |
|----------------------------------------------------|-----------------|---------|--------|----------|---------|
| Deployment Cost                                    | Deployment Size |         |        |          |         |
| 736435                                             | 3657            |         |        |          |         |
| Function Name                                      | min             | avg     | median | max      | # calls |
| addWinningInvestors                                | 211255          | 9233903 | 276955 | 36170450 | 4       |
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


| contracts/TBA.sol:TokenBoundAccount contract |                 |        |        |        |         |
|----------------------------------------------|-----------------|--------|--------|--------|---------|
| Deployment Cost                              | Deployment Size |        |        |        |         |
| 2228416                                      | 12714           |        |        |        |         |
| Function Name                                | min             | avg    | median | max    | # calls |
| CURRENCY_PERMIT_TYPEHASH                     | 203             | 203    | 203    | 203    | 1025    |
| DOMAIN_SEPARATOR                             | 632             | 632    | 632    | 632    | 1025    |
| executeCall                                  | 150831          | 150904 | 150831 | 226531 | 1025    |
| nonce                                        | 3672            | 3674   | 3672   | 6172   | 1025    |
| permit                                       | 53617           | 53617  | 53617  | 53617  | 1025    |
| token                                        | 1212            | 1212   | 1212   | 1212   | 1025    |
| transferCurrency                             | 6387            | 6404   | 6387   | 23907  | 1025    |


| contracts/libs/Utils.sol:Utils contract |                 |          |          |          |         |
|-----------------------------------------|-----------------|----------|----------|----------|---------|
| Deployment Cost                         | Deployment Size |          |          |          |         |
| 171429                                  | 888             |          |          |          |         |
| Function Name                           | min             | avg      | median   | max      | # calls |
| excludeAddresses                        | 13836084        | 52517188 | 52517188 | 91198293 | 2       |


| contracts/libs/VRFCoordinatorV2Mock.sol:VRFCoordinatorV2Mock contract |                 |          |          |          |         |
|-----------------------------------------------------------------------|-----------------|----------|----------|----------|---------|
| Deployment Cost                                                       | Deployment Size |          |          |          |         |
| 1027879                                                               | 5189            |          |          |          |         |
| Function Name                                                         | min             | avg      | median   | max      | # calls |
| addConsumer                                                           | 47510           | 47510    | 47510    | 47510    | 2       |
| createSubscription                                                    | 46459           | 46459    | 46459    | 46459    | 2       |
| fulfillRandomWords                                                    | 23801635        | 23801635 | 23801635 | 23801635 | 1       |
| fundSubscription                                                      | 3094            | 3094     | 3094     | 3094     | 2       |
| requestRandomWords                                                    | 43290           | 43290    | 43290    | 43290    | 1       |


| test/BionicPoolRegistry.t.sol:ERC20Mock contract |                 |       |        |       |         |
|-------------------------------------------------|-----------------|-------|--------|-------|---------|
| Deployment Cost                                 | Deployment Size |       |        |       |         |
| 632576                                          | 4077            |       |        |       |         |
| Function Name                                   | min             | avg   | median | max   | # calls |
| balanceOf                                       | 582             | 582   | 582    | 582   | 2001    |
| mint                                            | 24650           | 24692 | 24650  | 46550 | 1026    |
| transfer                                        | 3010            | 10204 | 3010   | 24910 | 1525    |


| test/BionicPoolRegistry.t.sol:UUPSProxy contract |                 |        |        |        |         |
|-------------------------------------------------|-----------------|--------|--------|--------|---------|
| Deployment Cost                                 | Deployment Size |        |        |        |         |
| 70448                                           | 1169            |        |        |        |         |
| Function Name                                   | min             | avg    | median | max    | # calls |
| balanceOf                                       | 1080            | 2153   | 2153   | 3227   | 2050    |
| initialize                                      | 193275          | 219612 | 219612 | 245949 | 4       |
| ownerOf                                         | 1155            | 1155   | 1155   | 1155   | 2050    |
| safeMint                                        | 57471           | 57500  | 57471  | 87871  | 1025    |
| transfer                                        | 28650           | 28662  | 28650  | 41950  | 1025    |
```
