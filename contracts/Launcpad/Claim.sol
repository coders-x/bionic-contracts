// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";




error ErrInvalidProject();  //"Project token not registered. Contact admin to add project tokens"
error ErrNothingToClaim();
error ErrNotEnoughTokenLeft(address token); //"Not enough tokens available for claiming. Please try Again"

contract ClaimingContract is Ownable {
    using SafeMath for uint256;

    uint256 constant MONTH_IN_SECONDS = 2629746; // Approx 1 month 

    struct UserClaim {
        uint256 lastClaimMonth; // Month when the user last claimed tokens
        uint256 totalTokensClaimed; // Total tokens claimed by the user
    }
    struct ProjectToken {
        IERC20 token; // The token that users can claim
        uint256 monthlyAmount; // Amount of tokens users can claim per month
        uint256 startMonth; // firstMonth token is claimable
        uint256 totalMonths; // number of months allocation will go on
    }

    // User's claim history for each project token useraddress => tokenAddress => UserClaim
    mapping(address => mapping(address => UserClaim)) public s_userClaims;
    // Add more project tokens here
    mapping(address => ProjectToken) public s_projectTokens;


    event ProjectAdded(IERC20 token, uint256 monthlyAmount, uint256 startMonth, uint256 endMonth);
    event TokensClaimed(address indexed user, address indexed projectToken, uint256 month, uint256 amount);



    modifier projectExists(address projectToken) {
        if(s_projectTokens[projectToken].monthlyAmount == 0){
            revert ErrInvalidProject();
        }
        _;
    }

    constructor() {}

    // Owner can register a new project token with claim parameters
    function registerProjectToken(
        address projectTokenAddress,
        uint256 claimAmount,
        uint256 startMonth,
        uint256 totalMonths
    ) external onlyOwner {
        s_projectTokens[projectTokenAddress] = ProjectToken(IERC20(projectTokenAddress), claimAmount, startMonth,totalMonths);
        emit ProjectAdded(IERC20(projectTokenAddress), claimAmount, startMonth,totalMonths);
    }

    //TODO change this to batch add the lottery winners
    function signUpForProject(address projectToken) external projectExists(projectToken) {
        require(s_userClaims[_msgSender()][projectToken].lastClaimMonth == 0, "User is already signed up for this project.");
        s_userClaims[_msgSender()][projectToken] = UserClaim(1, 0); // Start from month 1
    }

    // Users can claim tokens for the current month for a specific project token
    function claimTokens(address projectToken) external projectExists(projectToken) {
        UserClaim storage userClaim = s_userClaims[_msgSender()][projectToken];
        if(userClaim.lastClaimMonth == 0){
            revert ErrNothingToClaim();
            // require(userClaim.lastClaimMonth > 0, "User is not signed up for this project.");
        }
        if(userClaim.lastClaimMonth > s_projectTokens[projectToken].totalMonths){
            revert ErrNothingToClaim();
            // require(userClaim.lastClaimMonth <= s_projectTokens[projectToken].totalMonths, "Claiming period has ended.");
        }
        if(userClaim.totalTokensClaimed.add(s_projectTokens[projectToken].monthlyAmount) >
            s_projectTokens[projectToken].totalMonths.mul(s_projectTokens[projectToken].monthlyAmount)){
            revert ErrNothingToClaim();
            // require(
            //     userClaim.totalTokensClaimed.add(s_projectTokens[projectToken].monthlyAmount) <=
            //         s_projectTokens[projectToken].totalMonths.mul(s_projectTokens[projectToken].monthlyAmount),
            //     "Tokens already claimed for all months."
            // );
        }

        

        // Calculate the amount to claim for the current month
        uint256 currentMonth = getClaimableMonthsCount(s_projectTokens[projectToken].startMonth,userClaim.lastClaimMonth);
        uint256 tokensToClaim = s_projectTokens[projectToken].monthlyAmount*currentMonth;

        // Ensure we have enough tokens available for claiming
        if(s_projectTokens[projectToken].token.balanceOf(address(this)) < tokensToClaim){
            revert ErrNotEnoughTokenLeft(projectToken);
            // require(
            //     s_projectTokens[projectToken].token.balanceOf(address(this)) >= tokensToClaim,
            //     "Not enough tokens available for claiming. Please try Again"
            // );
        }

        // Update user's claim data
        userClaim.lastClaimMonth++;
        userClaim.totalTokensClaimed.add(tokensToClaim);

        // Transfer tokens to the user
        s_projectTokens[projectToken].token.transfer(_msgSender(), tokensToClaim);

        emit TokensClaimed(_msgSender(), projectToken, currentMonth, tokensToClaim);
    }

    function batchClaim() external {
        //todo
        // Project[] storage projects = s_userProjects[msg.sender];
        // uint256 currentMonth = getCurrentMonth();

        // uint256 totalClaimed;

        // for(uint i = 0; i < projects.length; i++) {
        // Project storage project = projects[i];
        
        // if(currentMonth >= project.startMonth && currentMonth <= project.endMonth) {
        //     uint256 monthsSinceLastClaim = currentMonth - project.lastClaimMonth;

        //     if(monthsSinceLastClaim > 0) {
        //     uint256 amountToClaim = monthsSinceLastClaim * project.monthlyAmount;
        //     project.lastClaimMonth = currentMonth;

        //     project.token.transfer(msg.sender, amountToClaim);
        //     totalClaimed += amountToClaim;

        //     emit TokensClaimed(msg.sender, project.token, amountToClaim);
        //     }
        // }
        // }

        // require(totalClaimed > 0, "NothingToClaim");
    }



    function getClaimableMonthsCount(uint256 startMonth, uint256 lastClaimedMonth) internal view returns (uint256) {
        return ((block.timestamp-startMonth) / MONTH_IN_SECONDS)-lastClaimedMonth; 
    }

    function getCurrentMonth() internal view returns (uint256) {
        return block.timestamp / MONTH_IN_SECONDS; 
    }
}
