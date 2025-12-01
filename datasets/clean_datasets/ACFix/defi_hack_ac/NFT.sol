pragma solidity 0.5.17;
import "@openzeppelin/contracts/token/ERC721/ERC721Metadata.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
contract NFT is ERC721Metadata, Ownable {
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
    string internal _contractURI;
    string internal _tokenName;
    string internal _tokenSymbol;
    function init(
        address newOwner,
        string calldata tokenName,
        string calldata tokenSymbol
    ) external {
        _transferOwnership(newOwner);
        _tokenName = tokenName;
        _tokenSymbol = tokenSymbol;
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
        _registerInterface(_INTERFACE_ID_ERC165);
        _registerInterface(_INTERFACE_ID_ERC721);
    }
    function name() external view returns (string memory) {
        return _tokenName;
    }
    function symbol() external view returns (string memory) {
        return _tokenSymbol;
    }
    function contractURI() external view returns (string memory) {
        return _contractURI;
    }
    function mint(address to, uint256 tokenId) external onlyOwner {
        _safeMint(to, tokenId);
    }
    function burn(uint256 tokenId) external onlyOwner {
        _burn(tokenId);
    }
    function setContractURI(string calldata newURI) external onlyOwner {
        _contractURI = newURI;
    }
    function setTokenURI(uint256 tokenId, string calldata newURI)
        external
        onlyOwner
    {
        _setTokenURI(tokenId, newURI);
    }
    function setBaseURI(string calldata newURI) external onlyOwner {
        _setBaseURI(newURI);
    }
}