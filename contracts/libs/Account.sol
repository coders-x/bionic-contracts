// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

// Base
import "@thirdweb-dev/contracts/smart-wallet/utils/BaseAccount.sol";
import "@thirdweb-dev/contracts/smart-wallet/utils/BaseAccountFactory.sol";

// Extensions
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/dynamic-contracts/extension/Initializable.sol";
import "@thirdweb-dev/contracts/dynamic-contracts/extension/ContractMetadata.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@thirdweb-dev/contracts/eip/ERC1271.sol";

// Utils
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";





// ╭━━╮╭━━┳━━━┳━╮╱╭┳━━┳━━━╮
// ┃╭╮┃╰┫┣┫╭━╮┃┃╰╮┃┣┫┣┫╭━╮┃
// ┃╰╯╰╮┃┃┃┃╱┃┃╭╮╰╯┃┃┃┃┃╱╰╯
// ┃╭━╮┃┃┃┃┃╱┃┃┃╰╮┃┃┃┃┃┃╱╭╮
// ┃╰━╯┣┫┣┫╰━╯┃┃╱┃┃┣┫┣┫╰━╯┃
// ╰━━━┻━━┻━━━┻╯╱╰━┻━━┻━━━╯

contract Account is
    Initializable,
    ERC1271,
    Multicall,
    BaseAccount,
    ContractMetadata,
    Context,
    ERC721Holder,
    Ownable,
    ERC1155Holder,
    EIP712
{
    using ECDSA for bytes32;

    /*///////////////////////////////////////////////////////////////
                                State
    //////////////////////////////////////////////////////////////*/

    /// @notice EIP 4337 factory for this contract.
    address public immutable factory;

    /// @notice EIP 4337 Entrypoint contract.
    IEntryPoint private immutable entrypointContract;

    /*///////////////////////////////////////////////////////////////
                    Constructor, Initializer, Modifiers
    //////////////////////////////////////////////////////////////*/

    // solhint-disable-next-line no-empty-blocks
    receive() external payable virtual {}

    constructor(IEntryPoint _entrypoint, address _factory, string memory _name, string memory _version) EIP712(_name, _version) {
        _disableInitializers();
        factory = _factory;
        entrypointContract = _entrypoint;
    }

    /// @notice Initializes the smart contract wallet.
    function initialize(address _defaultAdmin, bytes calldata) public virtual initializer{}

    /// @notice Checks whether the caller is the EntryPoint contract or the admin.
    modifier onlyAdminOrEntrypoint() virtual {
        require(
            _msgSender() == address(entryPoint()) || _msgSender() == owner(),
            "Account: not admin or EntryPoint."
        );
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            View functions
    //////////////////////////////////////////////////////////////*/

    /// @notice See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155Receiver) returns (bool) {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @notice Returns the EIP 4337 entrypoint contract.
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return entrypointContract;
    }

    /// @notice Returns the balance of the account in Entrypoint.
    function getDeposit() public view virtual returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /// @notice Returns whether a signer is authorized to perform transactions using the wallet.
    function isValidSigner(
        address _signer,
        UserOperation calldata /* _userOp */
    ) public view virtual returns (bool) {
        // First, check if the signer is the owner.
        if (_signer == owner()) 
            return true;
        return false;
    }

    /// @notice See EIP-1271
    function isValidSignature(bytes32 _hash, bytes memory _signature)
        public
        view
        virtual
        override
        returns (bytes4 magicValue)
    {
        address signer = _hash.recover(_signature);

        if (signer==owner()) {
            magicValue = MAGICVALUE;
        }
    }

    /*///////////////////////////////////////////////////////////////
                            External functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Executes a transaction (called directly from an admin, or by entryPoint)
    function execute(
        address _target,
        uint256 _value,
        bytes calldata _calldata
    ) external virtual onlyAdminOrEntrypoint {
        _registerOnFactory();
        _call(_target, _value, _calldata);
    }

    /// @notice Executes a sequence transaction (called directly from an admin, or by entryPoint)
    function executeBatch(
        address[] calldata _target,
        uint256[] calldata _value,
        bytes[] calldata _calldata
    ) external virtual onlyAdminOrEntrypoint {
        _registerOnFactory();

        require(_target.length == _calldata.length && _target.length == _value.length, "Account: wrong array lengths.");
        for (uint256 i = 0; i < _target.length; i++) {
            _call(_target[i], _value[i], _calldata[i]);
        }
    }

    /// @notice Deposit funds for this account in Entrypoint.
    function addDeposit() public payable virtual {
        entryPoint().depositTo{ value: msg.value }(address(this));
    }

    /// @notice Withdraw funds for this account from Entrypoint.
    function withdrawDepositTo(address payable withdrawAddress, uint256 amount) public virtual onlyOwner {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    /*///////////////////////////////////////////////////////////////
                        Internal functions
    //////////////////////////////////////////////////////////////*/

    /// @dev Registers the account on the factory if it hasn't been registered yet.
    function _registerOnFactory() internal virtual {
        BaseAccountFactory factoryContract = BaseAccountFactory(factory);
        if (!factoryContract.isRegistered(address(this))) {
            factoryContract.onRegister();
        }
    }

    /// @dev Calls a target contract and reverts if it fails.
    function _call(
        address _target,
        uint256 value,
        bytes memory _calldata
    ) internal virtual returns (bytes memory result) {
        bool success;
        (success, result) = _target.call{ value: value }(_calldata);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function getFunctionSignature(bytes calldata data) internal pure returns (bytes4 functionSelector) {
        require(data.length >= 4, "Data too short");
        return bytes4(data[:4]);
    }

    function decodeExecuteCalldata(bytes calldata data) internal pure returns (address _target, uint256 _value) {
        require(data.length >= 4 + 32 + 32, "Data too short");

        // Decode the address, which is bytes 4 to 35
        _target = abi.decode(data[4:36], (address));

        // Decode the value, which is bytes 36 to 68
        _value = abi.decode(data[36:68], (uint256));
    }

    function decodeExecuteBatchCalldata(bytes calldata data)
        internal
        pure
        returns (
            address[] memory _targets,
            uint256[] memory _values,
            bytes[] memory _callData
        )
    {
        require(data.length >= 4 + 32 + 32 + 32, "Data too short");

        (_targets, _values, _callData) = abi.decode(data[4:], (address[], uint256[], bytes[]));
    }

    /// @notice Validates the signature of a user operation.
    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        address signer = hash.recover(userOp.signature);

        if (!isValidSigner(signer, userOp)) return SIG_VALIDATION_FAILED;
        return 0;
    }


    /// @dev Returns whether contract metadata can be set in the given execution context.
    function _canSetContractURI() internal view virtual override returns (bool) {
        return owner()==_msgSender();
    }
}
