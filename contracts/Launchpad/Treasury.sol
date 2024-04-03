// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Treasury {
    using SafeERC20 for IERC20;

    address immutable stakingContract;

    constructor(address _stakingContract) {
        if (_stakingContract == address(0)) {
            revert("Treasury: staking contract is the zero address");
        }
        stakingContract = _stakingContract;
    }

    function withdrawTo(
        IERC20 _token,
        address _recipient,
        uint256 _amount
    ) external {
        require(
            msg.sender == stakingContract,
            "Treasury.withdrawTo: Only staking contract"
        );
        _token.safeTransfer(_recipient, _amount);
    }

    function tokenBalance(IERC20 _token) external view returns (uint256) {
        return _token.balanceOf(address(this));
    }
}
