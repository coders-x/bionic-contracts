// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import "@thirdweb-dev/contracts/smart-wallet/non-upgradeable/Account.sol";
import "@thirdweb-dev/contracts/eip/interface/IERC721.sol";
import "@thirdweb-dev/contracts/eip/interface/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./reference/src/lib/ERC6551AccountLib.sol";
import "./reference/src/interfaces/IERC6551Account.sol";
import "./libs/ICurrencyPermit.sol";

import "hardhat/console.sol";


contract TokenBoundAccount is ICurrencyPermit, IERC6551Account, Context, Account {
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
        keccak256("Permit(address currency,address spender,uint256 value,uint256 nonce,uint256 deadline)");


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
    ) Account(_entrypoint, _factory) {
        _disableInitializers();
    }



    receive() external payable virtual override(Account, IERC6551Account) {}

    /// @notice Returns whether a signer is authorized to perform transactions using the wallet.
    function isValidSigner(address _signer, UserOperation calldata _userOp) public view virtual override returns (bool) {
        AccountPermissionsStorage.Data storage data = AccountPermissionsStorage.accountPermissionsStorage();

        // First, check if the signer is the owner.
        if (_signer==owner()) {
            console.log("owner called: %s",owner());
            return true;
        } else {
            // If not an admin, check restrictions for the role held by the signer.
            bytes32 role = data.roleOfAccount[_signer];
            RoleStatic memory restrictions = data.roleRestrictions[role];

            // // Check if the role is active. If the signer has no role, this condition will revert because both start and end timestamps are `0`.
            // require(
            //     restrictions.startTimestamp <= block.timestamp && block.timestamp < restrictions.endTimestamp,
            //     "Account: role not active."
            // );

            // Extract the function signature from the userOp calldata and check whether the signer is attempting to call `execute` or `executeBatch`.
            bytes4 sig = getFunctionSignature(_userOp.callData);

            if (sig == this.execute.selector) {
                // Extract the `target` and `value` arguments from the calldata for `execute`.
                (address target, uint256 value, bytes memory callData) = decodeExecuteCalldata(_userOp.callData);

                if(_allowances[target][_signer]>0){
                    return true;
                }
                // if(IEIP165(target).supportsInterface(type(IERC20).interfaceId)){
                //         IERC20.transfer.selector
                // };

                // Check if the value is within the allowed range and if the target is approved.
                // require(restrictions.maxValuePerTransaction >= value, "Account: value too high.");
                // require(data.approvedTargets[role].contains(target), "Account: target not approved.");
            } else if (sig == this.executeBatch.selector) {
                // Extract the `target` and `value` array arguments from the calldata for `executeBatch`.
                (address[] memory targets, uint256[] memory values, ) = decodeExecuteBatchCalldata(_userOp.callData);

                // For each target+value pair, check if the value is within the allowed range and if the target is approved.
                for (uint256 i = 0; i < targets.length; i++) {
                    if(_allowances[targets[i]][_signer]>0){
                        return true;
                    }
                    // require(data.approvedTargets[role].contains(targets[i]), "Account: target not approved.");
                    // require(restrictions.maxValuePerTransaction >= values[i], "Account: value too high.");
                }
            } else {
                revert("Account: calling invalid fn.");
            }

            return true;
        }
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
    ) external  onlyAdminOrEntrypoint {
        require(block.timestamp <= deadline, "CurrencyPermit: expired deadline");

        address _signer=owner();
        uint256 n=_useNonce(_signer);
        bytes32 structHash = keccak256(abi.encode(_CURRENCY_PERMIT_TYPEHASH, currency, spender, value, n, deadline));

        bytes32 hash = _hashTypedDataV4(structHash);


        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == _signer, string(abi.encode(signer,"!=",_signer, hash)));
        _approve(currency, spender, value);
    }


    /**
     * @dev See {ICurrencyPermit-nonces}.
     */
    function nonces(address _owner) public view virtual override returns (uint256) {
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
    function allowance(address currency, address spender) public view virtual returns (uint256) {
        return _allowances[currency][spender];
    }

    function owner() public view returns (address) {
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

    function _erc20TransferCheck(
        address _target,
        uint256 value,
        bytes calldata _calldata
    ) internal virtual returns (bool success) {
        success=false;
        if(IERC165(_target).supportsInterface(type(IERC20).interfaceId)){
                if (getFunctionSignature(_calldata)==IERC20.transfer.selector||getFunctionSignature(_calldata)==IERC20.transferFrom.selector){

                }
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
    function _approve(address currency, address spender, uint256 amount) internal  {
        require(currency != address(0), "CurrencyPermit: approve from the zero address");
        require(spender != address(0), "CurrencyPermit: approve to the zero address");

        _allowances[currency][spender] = amount;
        emit CurrencyApproval(currency, spender, amount);
    }

    /**
     * @dev "Consume a nonce": return the current value and increment.
     *
     * _Available since v4.1._
     */
    function _useNonce(address _owner) internal virtual returns (uint256 current) {
        Counters.Counter storage nonce = _nonces[_owner];
        current = nonce.current();
        nonce.increment();
    }
    /*///////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/

    modifier onlyAdminOrEntrypoint() override {
        require(
            _msgSender() == address(entryPoint()) || _msgSender() == owner(),
            "Account: not admin or EntryPoint."
        );
        _;
    }




    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/#storage_gaps
     */
    uint256[49] private __gap;

}