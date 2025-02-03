// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {AccountV3, IEntryPoint} from "tokenbound/src/AccountV3.sol";
import "tokenbound/src/utils/Errors.sol";
import {ICurrencyPermit} from "./libs/ICurrencyPermit.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
// import "forge-std/console.sol";

error InvalidSigniture();

// ╭━━╮╭━━┳━━━┳━╮╱╭┳━━┳━━━╮
// ┃╭╮┃╰┫┣┫╭━╮┃┃╰╮┃┣┫┣┫╭━╮┃
// ┃╰╯╰╮┃┃┃┃╱┃┃╭╮╰╯┃┃┃┃┃╱╰╯
// ┃╭━╮┃┃┃┃┃╱┃┃┃╰╮┃┃┃┃┃┃╱╭╮
// ┃╰━╯┣┫┣┫╰━╯┃┃╱┃┃┣┫┣┫╰━╯┃
// ╰━━━┻━━┻━━━┻╯╱╰━┻━━┻━━━╯
/// @title ERC6551Account Contract
/// @author Ali Mahdavi (mailto:ali.mahdavi.dev@gmail.com)
/// @dev BionicAccount gives Bionic Platform and BionicInvestorPass(BIP) owner certain Access.
contract BionicAccount is AccountV3, ICurrencyPermit, EIP712 {
    using ECDSA for bytes32;
    /*///////////////////////////////////////////////////////////////
                            States
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Keeps the Allowance Per spender over currency
     * @dev currency => spender +> allowed amount
     *  if currency is 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE the spender will have access to the native coin
     */
    mapping(address => mapping(address => uint256)) public allowances;

    bytes32 public constant CURRENCY_PERMIT_TYPEHASH =
        keccak256(
            "Permit(address currency,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    constructor(
        address entryPoint_,
        address multicallForwarder,
        address erc6551Registry,
        address guardian
    )
        AccountV3(entryPoint_, multicallForwarder, erc6551Registry, guardian)
        EIP712("BionicAccount", "1")
    {}

    // function _contextSuffixLength() internal view override(Context, ERC2771Context) returns (uint256) {
    //     // Add your implementation here
    //     return 20;
    // }
    /**
     * @dev See {ICurrencyPermit-permit}.
     */
    function permit(
        address currency,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(
            block.timestamp <= deadline, // solhint-disable-line not-rely-on-time
            "CurrencyPermit: expired deadline"
        );
        address _signer = owner();
        uint256 n = getNonce();
        bytes32 structHash = keccak256(
            abi.encode(
                CURRENCY_PERMIT_TYPEHASH,
                currency,
                spender,
                value,
                n,
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != _signer) {
            revert InvalidSigniture();
        }
        _approve(currency, spender, value);
    }

    /// @notice will transfer Currency approved to the caller
    /// @dev transferCurrency will allow spender(msg.sender) to transfer the amount of money they already permited to move.
    /// @param currency the erc20 contract address to spend the amount if it's 0xeeee.eeee it will try transfering native token
    /// @param to the address amount will be sent
    /// @param amount the amount of currency wished to be spent
    /// @return bool if transaction was successfull it will return a boolian value of true if it's native value it might fail with revert
    function transferCurrency(
        address currency,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        _spendAllowance(currency, msg.sender, amount);
        if (currency == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            _call(to, amount, msg.data);
        } else {
            return IERC20(currency).transfer(to, amount);
        }
        return true;
    }

    // /// @dev EIP-1271 signature validation. By default, only the owner of the account is permissioned to sign.
    // /// This function can be overriden.
    // function _isValidSignature(
    //     bytes32 hash,
    //     bytes memory signature
    // ) external view override(AccountV3,Signatory) returns (bytes4 magicValue) {
    //     AccountV3._isValidSignature(hash,signature);
    //     // _handleOverrideStatic();

    //     // bool isValid = SignatureChecker.isValidSignatureNow(
    //     //     owner(),
    //     //     hash,
    //     //     signature
    //     // );

    //     // if (isValid) {
    //     //     return IERC1271.isValidSignature.selector;
    //     // }

    //     // return "";
    // }

    /**
     * @dev See {EIP712-DOMAIN_SEPARATOR}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(
        address currency,
        address spender
    ) public view virtual returns (uint256) {
        return allowances[currency][spender];
    }

    /// @dev Executes a low-level call
    function _call(
        address to,
        uint256 value,
        bytes calldata data
    ) internal returns (bytes memory result) {
        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
        _incrementNonce();
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address currency,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(currency, spender);
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "ERC20: insufficient allowance"
            );
            // unchecked {
            _approve(currency, spender, currentAllowance - amount);
            // }
        }
    }
    /// @dev Increments the account nonce if the caller is not the ERC-4337 entry point
    function _incrementNonce() internal {
        if (msg.sender != address(_entryPoint))
            IEntryPoint(_entryPoint).incrementNonce(0);
    }

    // /**
    //  * @dev Sets `amount` as the allowance of `spender` over the owner's `currency` tokens.
    //  *
    //  * This internal function is equivalent to `approve`, and can be used to
    //  * e.g. set automatic allowances for certain subsystems, etc.
    //  *
    //  * Emits an {CurrencyApproval} event.
    //  *
    //  * Requirements:
    //  *
    //  * - `currency` cannot be the zero address. 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE will denote to native coin (eth,matic, and etc.)
    //  * - `spender` cannot be the zero address.
    //  */
    function _approve(
        address currency,
        address spender,
        uint256 amount
    ) internal {
        require(
            currency != address(0),
            "CurrencyPermit: approve currency of zero address"
        );
        require(
            spender != address(0),
            "CurrencyPermit: approve to the zero address"
        );

        allowances[currency][spender] = amount;
        _incrementNonce();
        emit CurrencyApproval(currency, spender, amount);
    }
}
