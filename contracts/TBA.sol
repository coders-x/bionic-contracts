// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import {IERC721,IERC165} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {ERC6551AccountLib} from "erc6551/src/lib/ERC6551AccountLib.sol";
import {IERC6551Account} from "erc6551/src/interfaces/IERC6551Account.sol";
import {ICurrencyPermit} from "./libs/ICurrencyPermit.sol";
import {Account,IEntryPoint,Ownable,ECDSA} from "./libs/Account.sol";

// ╭━━╮╭━━┳━━━┳━╮╱╭┳━━┳━━━╮
// ┃╭╮┃╰┫┣┫╭━╮┃┃╰╮┃┣┫┣┫╭━╮┃
// ┃╰╯╰╮┃┃┃┃╱┃┃╭╮╰╯┃┃┃┃┃╱╰╯
// ┃╭━╮┃┃┃┃┃╱┃┃┃╰╮┃┃┃┃┃┃╱╭╮
// ┃╰━╯┣┫┣┫╰━╯┃┃╱┃┃┣┫┣┫╰━╯┃
// ╰━━━┻━━┻━━━┻╯╱╰━┻━━┻━━━╯
/// @title ERC6551Account Contract 
/// @author Ali Mahdavi (mailto:ali.mahdavi.dev@gmail.com)
/// @notice Fork of TokenBoundAccount.sol from Thirdweb
/// @dev TokenBoundAccount that gives Bionic Platform and BionicInvestorPass(BIP) owner certain Access.
abstract contract TokenBoundAccount is
    ICurrencyPermit,
    IERC6551Account,
    IERC165,
    Account
{
    /*///////////////////////////////////////////////////////////////
                            States
    //////////////////////////////////////////////////////////////*/
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
    bytes32 private constant _CURRENCY_PERMIT_TYPEHASH =
        keccak256(
            "Permit(address currency,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    /*///////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/

    event TokenBoundAccountCreated(address indexed account, bytes indexed data);

    /*///////////////////////////////////////////////////////////////
                            Constructor
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes once when a contract is created to initialize state variables
     *
     * @param _entrypoint - 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
     * @param _factory - The factory contract address to issue token Bound accounts
     *
     */
    constructor(
        IEntryPoint _entrypoint,
        address _factory
    ) Account(_entrypoint, _factory,"BionicAccount","1") {} //solhint-disable-line no-empty-blocks

    receive() external payable virtual override(Account, IERC6551Account) {} //solhint-disable-line no-empty-blocks

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

        require(
            block.timestamp <= deadline,        // solhint-disable-line not-rely-on-time
            "CurrencyPermit: expired deadline"
        );
        address _signer = owner();
        uint256 n = _useNonce(_signer);
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


        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        require(
            signer == _signer,
            string(abi.encode(signer, "!=", _signer, hash))
        );
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
        address spender = _msgSender();
        _spendAllowance(currency, spender, amount);
        if (currency==address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)){
            _call(to, amount, "");
        }else{
            return IERC20(currency).transfer(to, amount);
        }
        return true;
    }

    /**
     * @dev See {ICurrencyPermit-nonces}.
     */
    function nonces(
        address _owner
    ) public view virtual override returns (uint256) {
        return _nonces[_owner].current();
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
        return _allowances[currency][spender];
    }

    function owner() public view override (Ownable) returns (address) {
        (
            uint256 chainId,
            address tokenContract,
            uint256 tokenId
        ) = ERC6551AccountLib.token();

        if (chainId != block.chainid) return address(0);

        return IERC721(tokenContract).ownerOf(tokenId);
    }

    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable onlyAdminOrEntrypoint returns (bytes memory result) {
        return _call(to, value, data);
    }

    /// @notice Withdraw funds for this account from Entrypoint.
    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) public virtual override {
        require(owner() == _msgSender(), "Account: not NFT owner");
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    function token()
        external
        view
        returns (uint256 chainId, address tokenContract, uint256 tokenId)
    {
        return ERC6551AccountLib.token();
    }

    function nonce() external view returns (uint256) {
        return getNonce();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, Account) returns (bool) {
        return interfaceId == type(IERC6551Account).interfaceId || super.supportsInterface(interfaceId);
    }

    /*///////////////////////////////////////////////////////////////
                            Internal Functions
    //////////////////////////////////////////////////////////////*/
    function _call(
        address _target,
        uint256 value,
        bytes memory _calldata
    ) internal virtual override returns (bytes memory result) {
        bool success;
        (success, result) = _target.call{value: value}(_calldata);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
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

        _allowances[currency][spender] = amount;
        emit CurrencyApproval(currency, spender, amount);
    }

    /**
     * @dev "Consume a nonce": return the current value and increment.
     *
     * _Available since v4.1._
     */
    function _useNonce(
        address _owner
    ) internal virtual returns (uint256 current) {
        Counters.Counter storage n = _nonces[_owner];
        current = n.current();
        n.increment();
    }

    /*///////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/#storage_gaps
     */
    uint256[49] private __gap;
}
