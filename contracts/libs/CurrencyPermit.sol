// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/CurrencyPermit.sol)

pragma solidity >=0.7.0 <0.9.0;

import "./ICurrencyPermit.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


/**
 * @dev Implementation of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * _Available since v3.4._
 *
 * @custom:storage-size 51
 */
abstract contract CurrencyPermit is  EIP712 ,ICurrencyPermit {
    using Counters for Counters.Counter;

    mapping(address => Counters.Counter) private _nonces;

    /**
     * 
     * @notice Keeps the Allowance Per spender over currency
     * @dev currency => spender +> allowed amount
     *  if currency is 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE the spender will have access to the native coin
     */ 
    mapping(address => mapping(address => uint256)) private _allowances;


    // solhint-disable-next-line var-name-mixedcase
    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256("Permit(address currency,address spender,uint256 value,uint256 nonce,uint256 deadline)");



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
    ) external  {
        require(block.timestamp <= deadline, "CurrencyPermit: expired deadline");
        address owner=msg.sender;
        bytes32 structHash = keccak256(abi.encode(_PERMIT_TYPEHASH, currency, spender, value, _useNonce(owner), deadline));

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, string(abi.encodePacked(signer,owner, hash)));

        _approve(currency, spender, value);
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
    function _approve(address currency, address spender, uint256 amount) internal  {
        require(currency != address(0), "CurrencyPermit: approve from the zero address");
        require(spender != address(0), "CurrencyPermit: approve to the zero address");

        _allowances[currency][spender] = amount;
        emit CurrencyApproval(currency, spender, amount);
    }

    /**
     * @dev See {ICurrencyPermit-nonces}.
     */
    function nonces(address owner) public view virtual override returns (uint256) {
        return _nonces[owner].current();
    }

    /**
     * @dev See {ICurrencyPermit-DOMAIN_SEPARATOR}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev "Consume a nonce": return the current value and increment.
     *
     * _Available since v4.1._
     */
    function _useNonce(address owner) internal virtual returns (uint256 current) {
        Counters.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/#storage_gaps
     */
    uint256[49] private __gap;
}
