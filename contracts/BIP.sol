// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@thirdweb-dev/contracts/extension/LazyMint.sol";
import "@thirdweb-dev/contracts/extension/DropSinglePhase.sol";
import "@thirdweb-dev/contracts/lib/CurrencyTransferLib.sol";

error BIP__Deprecated();
error BIP__AccountRescueSignitureOutDated();
error BIP__InvalidSigniture();

contract BionicInvestorPass is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ERC721BurnableUpgradeable,
    UUPSUpgradeable,
    EIP712,
    LazyMint,
    DropSinglePhase
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // Mapping from token ID to guardian address
    mapping(uint256 => address) private _guardians;
    bytes32 public constant ACCOUNT_RESCUE_TYPEHASH =
        keccak256(
            "AccountRescueApprove(address to,uint256 tokenId,uint256 deadline)"
        );
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    CountersUpgradeable.Counter private _tokenIdCounter;
    address private platformFeeRecipient;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() EIP712("BIP", "1") {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("Bionic Investor Pass", "BIP");
        __ERC721URIStorage_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC721Burnable_init();
        __UUPSUpgradeable_init();

        platformFeeRecipient = msg.sender;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        // _pause();//don't allow transfers only claim //todo fix _mint issue
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Safely mints a new token, assigning it to the specified address, with a given guardian and URI.
     * @param to The recipient address to receive the minted token.
     * @param guardian The guardian address associated with the minted token.
     * @param uri The URI for the metadata of the minted token.
     * @dev Only callable by an address with the MINTER_ROLE role.
     */
    function safeMint(
        address to,
        address guardian,
        string memory uri
    ) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        _guardians[tokenId] = guardian;
    }

    function transferFrom(
        address,
        address,
        uint256
    ) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
        revert BIP__Deprecated();
    }

    function safeTransferFrom(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
        revert BIP__Deprecated();
    }

    function accountRescueApprove(
        address to,
        uint tokenId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (block.timestamp > deadline) {
            revert BIP__AccountRescueSignitureOutDated();
        }

        bytes32 structHash = keccak256(
            abi.encode(ACCOUNT_RESCUE_TYPEHASH, to, tokenId, deadline)
        );
        address signer = ECDSA.recover(_hashTypedDataV4(structHash), v, r, s);
        if (signer != _guardians[tokenId]) {
            revert BIP__InvalidSigniture();
        }

        _safeTransfer(super._ownerOf(tokenId), to, tokenId, "");
    }

    /**
     * @dev See {EIP712-DOMAIN_SEPARATOR}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     */
    function guardianOf(uint256 tokenId) external view returns (address) {
        return _guardians[tokenId];
    }

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(
            ERC721Upgradeable,
            ERC721URIStorageUpgradeable,
            AccessControlUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        require(this.balanceOf(to) == 0, "already have been MINTED Membership");
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    // The following functions are overrides required by Solidity.

    function _burn(
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    function _canLazyMint() internal view virtual override returns (bool) {
        return hasRole(MINTER_ROLE, msg.sender);
    }

    /// @dev Collects and distributes the primary sale value of NFTs being claimed.
    function _collectPriceOnClaim(
        address _primarySaleRecipient,
        uint256 _quantityToClaim,
        address _currency,
        uint256 _pricePerToken
    ) internal virtual override {
        if (_pricePerToken == 0) {
            return;
        }

        address saleRecipient = _primarySaleRecipient == address(0)
            ? platformFeeRecipient
            : _primarySaleRecipient;

        uint256 totalPrice = _quantityToClaim * _pricePerToken;

        if (_currency == CurrencyTransferLib.NATIVE_TOKEN) {
            if (msg.value != totalPrice) {
                revert("!Price");
            }
        }

        CurrencyTransferLib.transferCurrency(
            _currency,
            _msgSender(),
            saleRecipient,
            totalPrice
        );
    }

    function _transferTokensOnClaim(
        address _to,
        uint256 _quantityBeingClaimed
    ) internal virtual override returns (uint256 startTokenId) {
        startTokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(_to, _quantityBeingClaimed);
    }

    function _canSetClaimConditions()
        internal
        view
        virtual
        override
        returns (bool)
    {
        return hasRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}
