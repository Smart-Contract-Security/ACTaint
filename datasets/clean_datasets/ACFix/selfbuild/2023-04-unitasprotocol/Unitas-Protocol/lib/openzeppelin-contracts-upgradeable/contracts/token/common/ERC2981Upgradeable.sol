pragma solidity ^0.8.0;
import "../../interfaces/IERC2981Upgradeable.sol";
import "../../utils/introspection/ERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";
abstract contract ERC2981Upgradeable is Initializable, IERC2981Upgradeable, ERC165Upgradeable {
    function __ERC2981_init() internal onlyInitializing {
    }
    function __ERC2981_init_unchained() internal onlyInitializing {
    }
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }
    RoyaltyInfo private _defaultRoyaltyInfo;
    mapping(uint256 => RoyaltyInfo) private _tokenRoyaltyInfo;
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165Upgradeable, ERC165Upgradeable) returns (bool) {
        return interfaceId == type(IERC2981Upgradeable).interfaceId || super.supportsInterface(interfaceId);
    }
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) public view virtual override returns (address, uint256) {
        RoyaltyInfo memory royalty = _tokenRoyaltyInfo[_tokenId];
        if (royalty.receiver == address(0)) {
            royalty = _defaultRoyaltyInfo;
        }
        uint256 royaltyAmount = (_salePrice * royalty.royaltyFraction) / _feeDenominator();
        return (royalty.receiver, royaltyAmount);
    }
    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }
    function _setDefaultRoyalty(address receiver, uint96 feeNumerator) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: invalid receiver");
        _defaultRoyaltyInfo = RoyaltyInfo(receiver, feeNumerator);
    }
    function _deleteDefaultRoyalty() internal virtual {
        delete _defaultRoyaltyInfo;
    }
    function _setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: Invalid parameters");
        _tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    }
    function _resetTokenRoyalty(uint256 tokenId) internal virtual {
        delete _tokenRoyaltyInfo[tokenId];
    }
    uint256[48] private __gap;
}