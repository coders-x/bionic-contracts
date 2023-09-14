// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {IERC6551Account} from "erc6551/interfaces/IERC6551Account.sol";
import {ERC6551AccountLib} from "erc6551/lib/ERC6551AccountLib.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import {BaseAccount as BaseERC4337Account, IEntryPoint, UserOperation} from "tokenbound/lib/account-abstraction/contracts/core/BaseAccount.sol";
import {IAccountGuardian} from "tokenbound/src/interfaces/IAccountGuardian.sol";

import {ICurrencyPermit} from "./libs/ICurrencyPermit.sol";

import "hardhat/console.sol";

error NotAuthorized();
error InvalidInput();
error AccountLocked();
error ExceedsMaxLockTime();
error UntrustedImplementation();
error OwnershipCycle();

// ╭━━╮╭━━┳━━━┳━╮╱╭┳━━┳━━━╮
// ┃╭╮┃╰┫┣┫╭━╮┃┃╰╮┃┣┫┣┫╭━╮┃
// ┃╰╯╰╮┃┃┃┃╱┃┃╭╮╰╯┃┃┃┃┃╱╰╯
// ┃╭━╮┃┃┃┃┃╱┃┃┃╰╮┃┃┃┃┃┃╱╭╮
// ┃╰━╯┣┫┣┫╰━╯┃┃╱┃┃┣┫┣┫╰━╯┃
// ╰━━━┻━━┻━━━┻╯╱╰━┻━━┻━━━╯
/// @title ERC6551Account Contract 
/// @author Ali Mahdavi (mailto:ali.mahdavi.dev@gmail.com)
/// @notice Fork of Account.sol from TokenBouand
/// @dev TokenBoundAccount that gives Bionic Platform and BionicInvestorPass(BIP) owner certain Access.
contract TokenBoundAccount is
    ICurrencyPermit,
    IERC165,
    IERC1271,
    EIP712,
    IERC6551Account,
    IERC721Receiver,
    IERC1155Receiver,
    UUPSUpgradeable,
    BaseERC4337Account
{
    using ECDSA for bytes32;

    /*///////////////////////////////////////////////////////////////
                            States
    //////////////////////////////////////////////////////////////*/
    /// @dev ERC-4337 entry point address
    address public immutable _entryPoint;

    /// @dev AccountGuardian contract address
    address public immutable guardian;

    /**
     * @notice Keeps the Allowance Per spender over currency
     * @dev currency => spender +> allowed amount
     *  if currency is 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE the spender will have access to the native coin
     */
    mapping(address => mapping(address => uint256)) public allowances;
    /// @dev mapping from owner => selector => implementation
    mapping(address => mapping(bytes4 => address)) public overrides;

    /// @dev mapping from owner => caller => has permissions
    mapping(address => mapping(address => bool)) public permissions;

        // solhint-disable-next-line var-name-mixedcase
    bytes32 private constant _CURRENCY_PERMIT_TYPEHASH =
        keccak256(
            "Permit(address currency,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    /*///////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/
    event OverrideUpdated(
        address owner,
        bytes4 selector,
        address implementation
    );

    event PermissionUpdated(address owner, address caller, bool hasPermission);


    /*///////////////////////////////////////////////////////////////
                            modifiers
    //////////////////////////////////////////////////////////////*/
    /// @dev reverts if caller is not the owner of the account
    modifier onlyOwner() {
        if (msg.sender != owner()) revert NotAuthorized();
        _;
    }

    /// @dev reverts if caller is not authorized to execute on this account
    modifier onlyAuthorized() {
        if (!isAuthorized(msg.sender)) revert NotAuthorized();
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            Constructor
    //////////////////////////////////////////////////////////////*/
    constructor(address _guardian, address entryPoint_) EIP712("BionicAccount","1") {
        if (_guardian == address(0) || entryPoint_ == address(0))
            revert InvalidInput();

        _entryPoint = entryPoint_;
        guardian = _guardian;
    }

    /// @dev allows eth transfers by default, but allows account owner to override
    receive() external payable {
        _handleOverride();
    }

    /// @dev allows account owner to add additional functions to the account via an override
    fallback() external payable {
        _handleOverride();
    }

    /// @dev executes a low-level call against an account if the caller is authorized to make calls
    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable onlyAuthorized returns (bytes memory) {
        emit TransactionExecuted(to, value, data);

        _incrementNonce();

        return _call(to, value, data);
    }

    /// @dev sets the implementation address for a given function call
    function setOverrides(
        bytes4[] calldata selectors,
        address[] calldata implementations
    ) external {
        address _owner = owner();
        if (msg.sender != _owner) revert NotAuthorized();

        uint256 length = selectors.length;

        if (implementations.length != length) revert InvalidInput();

        for (uint256 i = 0; i < length; i++) {
            overrides[_owner][selectors[i]] = implementations[i];
            emit OverrideUpdated(_owner, selectors[i], implementations[i]);
        }

        _incrementNonce();
    }

    /// @dev grants a given caller execution permissions
    function setPermissions(
        address[] calldata callers,
        bool[] calldata _permissions
    ) external {
        address _owner = owner();
        if (msg.sender != _owner) revert NotAuthorized();

        uint256 length = callers.length;

        if (_permissions.length != length) revert InvalidInput();

        for (uint256 i = 0; i < length; i++) {
            permissions[_owner][callers[i]] = _permissions[i];
            emit PermissionUpdated(_owner, callers[i], _permissions[i]);
        }

        _incrementNonce();
    }


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
        console.log("block.timestamp <= deadline");

        require(
            block.timestamp <= deadline,        // solhint-disable-line not-rely-on-time
            "CurrencyPermit: expired deadline"
        );
        address _signer = owner();
        console.log("signer %s",_signer);
        uint256 n = nonce();
        console.log("nonce %s",n);
        bytes32 structHash = keccak256(
            abi.encode(
                _CURRENCY_PERMIT_TYPEHASH,
                currency,
                spender,
                value,
                n,
                deadline
            )
        );
        console.log("structHash");
        console.logBytes32(structHash);


        bytes32 hash = _hashTypedDataV4(structHash);
        console.log("hash");
        console.logBytes32(hash);
        address signer = ECDSA.recover(hash, v, r, s);
        console.log("signer %s",signer);
        require(
            signer == _signer,
            string(abi.encode(signer, "!=", _signer, hash))
        );
        console.log("==> %s",string(abi.encode(signer, "!=", _signer, hash)));
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
        if (currency==address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)){
            _call(to, amount,msg.data);
        }else{
            return IERC20(currency).transfer(to, amount);
        }
        _incrementNonce();
        return true;
    }




    /// @dev EIP-1271 signature validation. By default, only the owner of the account is permissioned to sign.
    /// This function can be overriden.
    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        returns (bytes4 magicValue)
    {
        _handleOverrideStatic();

        bool isValid = SignatureChecker.isValidSignatureNow(
            owner(),
            hash,
            signature
        );

        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }

        return "";
    }

    /// @dev Returns the EIP-155 chain ID, token contract address, and token ID for the token that
    /// owns this account.
    function token()
        external
        view
        returns (
            uint256 chainId,
            address tokenContract,
            uint256 tokenId
        )
    {
        return ERC6551AccountLib.token();
    }

    /// @dev Returns the current account nonce
    function nonce() public view override(ICurrencyPermit, IERC6551Account) returns (uint256) {
        console.log("trying to get nonce");
        try IEntryPoint(_entryPoint).getNonce(address(this), 0) returns (uint256 n) {
            console.log("got nonce %s",n);
            return n;
        } catch  (bytes memory reason){
            console.log("!!!Failed");
            console.logBytes(reason);
        }
    }

    /// @dev Increments the account nonce if the caller is not the ERC-4337 entry point
    function _incrementNonce() internal {
        if (msg.sender != _entryPoint)
            IEntryPoint(_entryPoint).incrementNonce(0);
    }

    /// @dev Return the ERC-4337 entry point address
    function entryPoint() public view override returns (IEntryPoint) {
        return IEntryPoint(_entryPoint);
    }
    /**
     * @dev See {ICurrencyPermit-DOMAIN_SEPARATOR}.
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
        console.log("checking allowence for %s on %s",spender,currency);
        return allowances[currency][spender];
    }

    /// @dev Returns the owner of the ERC-721 token which owns this account. By default, the owner
    /// of the token has full permissions on the account.
    function owner() public view returns (address) {
        (
            uint256 chainId,
            address tokenContract,
            uint256 tokenId
        ) = ERC6551AccountLib.token();

        if (chainId != block.chainid) return address(0);

        return IERC721(tokenContract).ownerOf(tokenId);
    }

    /// @dev Returns the authorization status for a given caller
    function isAuthorized(address caller) public view returns (bool) {
        // authorize entrypoint for 4337 transactions
        if (caller == _entryPoint) return true;

        (
            uint256 chainId,
            address tokenContract,
            uint256 tokenId
        ) = ERC6551AccountLib.token();
        address _owner = IERC721(tokenContract).ownerOf(tokenId);

        // authorize token owner
        if (caller == _owner) return true;

        // authorize caller if owner has granted permissions
        if (permissions[_owner][caller]) return true;

        // authorize trusted cross-chain executors if not on native chain
        if (
            chainId != block.chainid &&
            IAccountGuardian(guardian).isTrustedExecutor(caller)
        ) return true;

        return false;
    }

    /// @dev Returns true if a given interfaceId is supported by this account. This method can be
    /// extended by an override.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        bool defaultSupport = interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC6551Account).interfaceId;

        if (defaultSupport) return true;

        // if not supported by default, check override
        _handleOverrideStatic();

        return false;
    }

    /// @dev Allows ERC-721 tokens to be received so long as they do not cause an ownership cycle.
    /// This function can be overriden.
    function onERC721Received(
        address,
        address,
        uint256 receivedTokenId,
        bytes memory
    ) public view override returns (bytes4) {
        _handleOverrideStatic();

        (
            uint256 chainId,
            address tokenContract,
            uint256 tokenId
        ) = ERC6551AccountLib.token();

        if (
            chainId == block.chainid &&
            tokenContract == msg.sender &&
            tokenId == receivedTokenId
        ) revert OwnershipCycle();

        return this.onERC721Received.selector;
    }

    /// @dev Allows ERC-1155 tokens to be received. This function can be overriden.
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public view override returns (bytes4) {
        _handleOverrideStatic();

        return this.onERC1155Received.selector;
    }

    /// @dev Allows ERC-1155 token batches to be received. This function can be overriden.
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public view override returns (bytes4) {
        _handleOverrideStatic();

        return this.onERC1155BatchReceived.selector;
    }


    /*///////////////////////////////////////////////////////////////
                            Internal Functions
    //////////////////////////////////////////////////////////////*/
    /// @dev Contract upgrades can only be performed by the owner and the new implementation must
    /// be trusted
    function _authorizeUpgrade(address newImplementation)
        internal
        view
        override
        onlyOwner
    {
        bool isTrusted = IAccountGuardian(guardian).isTrustedImplementation(
            newImplementation
        );
        if (!isTrusted) revert UntrustedImplementation();
    }

    /// @dev Validates a signature for a given ERC-4337 operation
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view override returns (uint256 validationData) {
        bool isValid = this.isValidSignature(
            userOpHash.toEthSignedMessageHash(),
            userOp.signature
        ) == IERC1271.isValidSignature.selector;

        if (isValid) {
            return 0;
        }

        return 1;
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
    }

    /// @dev Executes a low-level call to the implementation if an override is set
    function _handleOverride() internal {
        address implementation = overrides[owner()][msg.sig];

        if (implementation != address(0)) {
            bytes memory result = _call(implementation, msg.value, msg.data);
            assembly {
                return(add(result, 32), mload(result))
            }
        }
    }

    /// @dev Executes a low-level static call
    function _callStatic(address to, bytes calldata data)
        internal
        view
        returns (bytes memory result)
    {
        bool success;
        (success, result) = to.staticcall(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /// @dev Executes a low-level static call to the implementation if an override is set
    function _handleOverrideStatic() internal view {
        address implementation = overrides[owner()][msg.sig];

        if (implementation != address(0)) {
            bytes memory result = _callStatic(implementation, msg.data);
            assembly {
                return(add(result, 32), mload(result))
            }
        }
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
        emit CurrencyApproval(currency, spender, amount);
    }
}
