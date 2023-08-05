// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/ERC20Permit.sol)

pragma solidity >=0.7.0 <0.9.0;

// import "./ICurrencyPermit.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// /**
//  * @dev Implementation of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
//  * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
//  *
//  * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
//  * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
//  * need to send a transaction, and thus is not required to hold Ether at all.
//  *
//  * _Available since v3.4._
//  *
//  * @custom:storage-size 51
//  */
// abstract contract CurrencyPermitUpgradeable is Initializable, ERC20Upgradeable, ICurrencyPermit, EIP712Upgradeable {
//     using CountersUpgradeable for CountersUpgradeable.Counter;

//     mapping(address => CountersUpgradeable.Counter) private _nonces;

//     /**
//      *
//      * @notice Keeps the Allowance Per spender over currency
//      * @dev currency => spender +> allowed amount
//      *  if currency is 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE the spender will have access to the native coin
//      */
//     mapping(address => mapping(address => uint256)) private _allowances;

//     // solhint-disable-next-line var-name-mixedcase
//     bytes32 private constant _PERMIT_TYPEHASH =
//         keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
//     /**
//      * @dev In previous versions `_PERMIT_TYPEHASH` was declared as `immutable`.
//      * However, to ensure consistency with the upgradeable transpiler, we will continue
//      * to reserve a slot.
//      * @custom:oz-renamed-from _PERMIT_TYPEHASH
//      */
//     // solhint-disable-next-line var-name-mixedcase
//     bytes32 private _PERMIT_TYPEHASH_DEPRECATED_SLOT;

//     /**
//      * @dev Initializes the {EIP712} domain separator using the `name` parameter, and setting `version` to `"1"`.
//      *
//      * It's a good idea to use the same `name` that is defined as the ERC20 token name.
//      */
//     function __ERC20Permit_init(string memory name) internal onlyInitializing {
//         __EIP712_init_unchained(name, "1");
//     }

//     function __ERC20Permit_init_unchained(string memory) internal onlyInitializing {}

//     /**
//      * @dev See {IERC20Permit-permit}.
//      */
//     function permit(
//         address owner,
//         address spender,
//         uint256 value,
//         uint256 deadline,
//         uint8 v,
//         bytes32 r,
//         bytes32 s
//     ) public virtual override {
//         require(block.timestamp <= deadline, "ERC20Permit: expired deadline");

//         bytes32 structHash = keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));

//         bytes32 hash = _hashTypedDataV4(structHash);

//         address signer = ECDSAUpgradeable.recover(hash, v, r, s);
//         require(signer == owner, string(abi.encodePacked(signer,owner, hash)));

//         _approve(owner, spender, value);
//     }

//     /**
//      * @dev See {IERC20Permit-nonces}.
//      */
//     function nonces(address owner) public view virtual override returns (uint256) {
//         return _nonces[owner].current();
//     }

//     /**
//      * @dev See {IERC20Permit-DOMAIN_SEPARATOR}.
//      */
//     // solhint-disable-next-line func-name-mixedcase
//     function DOMAIN_SEPARATOR() external view override returns (bytes32) {
//         return _domainSeparatorV4();
//     }

//     /**
//      * @dev "Consume a nonce": return the current value and increment.
//      *
//      * _Available since v4.1._
//      */
//     function _useNonce(address owner) internal virtual returns (uint256 current) {
//         CountersUpgradeable.Counter storage nonce = _nonces[owner];
//         current = nonce.current();
//         nonce.increment();
//     }

//     /**
//      * @dev This empty reserved space is put in place to allow future versions to add new
//      * variables without shifting down storage in the inheritance chain.
//      * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
//      */
//     uint256[49] private __gap;
// }
