// TestContract.t.sol
pragma solidity >=0.7.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {DSTest} from "ds-test/test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./Claim.sol";

contract ClaimingContractTest is DSTest,Test {
  uint256 public constant MONTH_IN_SECONDS = 2629746;// Approx 1 month (assuming 15 seconds per block)

  ClaimFunding private claimingContract; 
  ERC20Mock private rewardToken; 
  ERC20Mock private rewardToken2; 
  address private owner=address(this);
  address[] private  winners=[address(1),address(2),address(3)];

  function setUp() public {
    claimingContract = new ClaimFunding();
    rewardToken = new ERC20Mock("REWARD TOKEN", "RWRD");
    rewardToken2 = new ERC20Mock("REWARD2 TOKEN", "RWRD2");
  }

  function registerProject() public {
    claimingContract.registerProjectToken(
      address(rewardToken), 
      10, 
      100,
      12 // a year
    );
  }


  function testRegisterProject() public {
    registerProject();

    (IERC20 token,uint256 amount,uint256 start,uint256 end) = claimingContract.s_projectTokens(address(rewardToken));
    assertEq(address(token),address(rewardToken));
    assertEq(amount, 10);
    assertEq(start, 100);
    assertEq(end, start+(12 *  MONTH_IN_SECONDS));
  }

  function testAddUserAndClaim() public {
    registerProject();
    uint256 time=200;


    //invalid project
    vm.expectRevert(ErrInvalidProject.selector);
    claimingContract.claimTokens(address(0));

    //nothing to claim not winner of project
    vm.expectRevert(ErrNotEligible.selector);
    claimingContract.claimTokens(address(rewardToken));


    //add winners and send transactions as winner0
    claimingContract.addWinningInvestors(address(rewardToken),winners);
    vm.startPrank(winners[0]);

    //nothing to claim not in the window
    vm.expectRevert(abi.encodePacked(ErrClaimingIsNotAllowedYet.selector, uint(100)));
    claimingContract.claimTokens(address(rewardToken));
    vm.warp(time);


    vm.expectRevert(ErrNothingToClaim.selector);
    claimingContract.claimTokens(address(rewardToken));

    time+=MONTH_IN_SECONDS;
    vm.warp(time);


    // vm.expectRevert(abi.encodePacked(ErrNotEnoughTokenLeft.selector, address(rewardToken)));
    vm.expectRevert(abi.encodePacked(hex"3a60250c0000000000000000000000002e234dae75c793f67a35089c9d99245e1c58470b"));
    claimingContract.claimTokens(address(rewardToken));
    vm.stopPrank();

    //Fund The Claiming Contract
    uint totalBalance=10000;
    rewardToken.mint(address(claimingContract), totalBalance);


    //claim for a month
    vm.startPrank(winners[0]);
    claimingContract.claimTokens(address(rewardToken));

    (uint256 lastMonth,uint256 totalTokenClaimed) = claimingContract.s_userClaims(winners[0], address(rewardToken));
    assertEq(lastMonth, time-199); 
    assertEq(totalTokenClaimed, 10);
    assertEq(rewardToken.balanceOf(address(claimingContract)), totalBalance-=10);
    assertEq(rewardToken.balanceOf(address(winners[0])), 10);


    //claim for 3 months
    time+=MONTH_IN_SECONDS*3;
    vm.warp(time);
    claimingContract.claimTokens(address(rewardToken));

    (lastMonth,totalTokenClaimed) = claimingContract.s_userClaims(winners[0], address(rewardToken));
    assertEq(lastMonth, time-199); 
    assertEq(totalTokenClaimed, 40);
    assertEq(rewardToken.balanceOf(address(claimingContract)), totalBalance-=30);
    assertEq(rewardToken.balanceOf(address(winners[0])), 40);


    vm.expectRevert(ErrNothingToClaim.selector);
    claimingContract.claimTokens(address(rewardToken));



    //claim for other winner 4 month claim
    vm.startPrank(winners[1]);
    claimingContract.claimTokens(address(rewardToken));

    (lastMonth,totalTokenClaimed) = claimingContract.s_userClaims(winners[1], address(rewardToken));
    assertEq(lastMonth, time-199); 
    assertEq(totalTokenClaimed, 40);
    assertEq(rewardToken.balanceOf(address(claimingContract)), totalBalance-=40);
    assertEq(rewardToken.balanceOf(address(winners[1])), 40);

    //claim for remaining months 4-12=8
    // time+=MONTH_IN_SECONDS*12;
    vm.warp(time+(MONTH_IN_SECONDS*12));
    vm.startPrank(winners[1]);
    claimingContract.claimTokens(address(rewardToken));

    (lastMonth,totalTokenClaimed) = claimingContract.s_userClaims(winners[1], address(rewardToken));
    assertEq(lastMonth, (time+(MONTH_IN_SECONDS*8))-199); 
    assertEq(totalTokenClaimed, 120);
    assertEq(rewardToken.balanceOf(address(claimingContract)), totalBalance-=80);
    assertEq(rewardToken.balanceOf(address(winners[1])), 120);

    vm.expectRevert(ErrNothingToClaim.selector);
    claimingContract.claimTokens(address(rewardToken));
  }

  function testBatchClaim() public {
    // vm.warp(100);
    claimingContract.registerProjectToken(
      address(rewardToken), 
      10, 
      200,
      12 // a year
    );
    claimingContract.registerProjectToken(
      address(rewardToken2), 
      20, 
      400,
      6 //6 month
    );
    //Fund The Claiming Contract
    uint totalBalance=10000;
    rewardToken.mint(address(claimingContract), totalBalance);
    rewardToken2.mint(address(claimingContract), totalBalance);
    
    //add winners and send transactions as winner0
    claimingContract.addWinningInvestors(address(rewardToken),winners);
    claimingContract.addWinningInvestors(address(rewardToken2),winners);
    vm.startPrank(winners[0]);



    vm.expectRevert(abi.encodePacked(ErrClaimingIsNotAllowedYet.selector, uint(200)));
    claimingContract.batchClaim();


    uint256 time=MONTH_IN_SECONDS*3;
    vm.warp(time);


    // vm.expectRevert(ErrNothingToClaim.selector);
    claimingContract.batchClaim();


    assertEq(rewardToken.balanceOf(address(claimingContract)), totalBalance-10*2);
    assertEq(rewardToken.balanceOf(address(winners[0])), 10*2);
    assertEq(rewardToken2.balanceOf(address(claimingContract)), totalBalance-20*2);
    assertEq(rewardToken2.balanceOf(address(winners[0])), 20*2);

  }
}




contract ERC20Mock is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}