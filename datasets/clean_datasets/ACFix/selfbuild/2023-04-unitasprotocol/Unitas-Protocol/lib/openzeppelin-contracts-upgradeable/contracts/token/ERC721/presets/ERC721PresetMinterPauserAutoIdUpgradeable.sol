pragma solidity ^0.8.0;
import "../ERC721Upgradeable.sol";
import "../extensions/ERC721EnumerableUpgradeable.sol";
import "../extensions/ERC721BurnableUpgradeable.sol";
import "../extensions/ERC721PausableUpgradeable.sol";
import "../../../access/AccessControlEnumerableUpgradeable.sol";
import "../../../utils/ContextUpgradeable.sol";
import "../../../utils/CountersUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";
contract ERC721PresetMinterPauserAutoIdUpgradeable is
    Initializable, ContextUpgradeable,
    AccessControlEnumerableUpgradeable,
    ERC721EnumerableUpgradeable,
    ERC721BurnableUpgradeable,
    ERC721PausableUpgradeable
{
    function initialize(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) public virtual initializer {
        __ERC721PresetMinterPauserAutoId_init(name, symbol, baseTokenURI);
    }
    using CountersUpgradeable for CountersUpgradeable.Counter;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    CountersUpgradeable.Counter private _tokenIdTracker;
    string private _baseTokenURI;
    function __ERC721PresetMinterPauserAutoId_init(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) internal onlyInitializing {
        __ERC721_init_unchained(name, symbol);
        __Pausable_init_unchained();
        __ERC721PresetMinterPauserAutoId_init_unchained(name, symbol, baseTokenURI);
    }
    function __ERC721PresetMinterPauserAutoId_init_unchained(
        string memory,
        string memory,
        string memory baseTokenURI
    ) internal onlyInitializing {
        _baseTokenURI = baseTokenURI;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
    function mint(address to) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have minter role to mint");
        _mint(to, _tokenIdTracker.current());
        _tokenIdTracker.increment();
    }
    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have pauser role to pause");
        _pause();
    }
    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have pauser role to unpause");
        _unpause();
    }
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721PausableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
    function _beforeConsecutiveTokenTransfer(
        address from,
        address to,
        uint256 first,
        uint96 size
    ) internal virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721PausableUpgradeable) {
        super._beforeConsecutiveTokenTransfer(from, to, first, size);
    }
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerableUpgradeable, ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    uint256[48] private __gap;
}