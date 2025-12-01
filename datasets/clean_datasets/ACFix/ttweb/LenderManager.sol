pragma solidity >=0.8.0 <0.9.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "./interfaces/ILenderManager.sol";
import "./interfaces/ITellerV2.sol";
import "./interfaces/IMarketRegistry.sol";
contract LenderManager is
    Initializable,
    OwnableUpgradeable,
    ERC721Upgradeable,
    ILenderManager
{
    IMarketRegistry public immutable marketRegistry;
    constructor(IMarketRegistry _marketRegistry) {
        marketRegistry = _marketRegistry;
    }
    function initialize() external initializer {
        __LenderManager_init();
    }
    function __LenderManager_init() internal onlyInitializing {
        __Ownable_init();
        __ERC721_init("TellerLoan", "TLN");
    }
    function registerLoan(uint256 _bidId, address _newLender)
        public
        override
        onlyOwner
    {
        _mint(_newLender, _bidId);
    }
    function _getLoanMarketId(uint256 _bidId) internal view returns (uint256) {
        return ITellerV2(owner()).getLoanMarketId(_bidId);
    }
    function _hasMarketVerification(address _lender, uint256 _bidId)
        internal
        view
        virtual
        returns (bool isVerified_)
    {
        uint256 _marketId = _getLoanMarketId(_bidId);
        (isVerified_, ) = marketRegistry.isVerifiedLender(_marketId, _lender);
    }
    function _beforeTokenTransfer(address, address to, uint256 tokenId, uint256)
        internal
        override
    {
        require(_hasMarketVerification(to, tokenId), "Not approved by market");
    }
    function _baseURI() internal view override returns (string memory) {
        return "";
    }
}