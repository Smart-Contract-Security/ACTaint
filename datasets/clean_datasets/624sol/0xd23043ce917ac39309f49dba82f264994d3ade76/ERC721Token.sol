pragma solidity ^0.4.24;
import "./ERC721.sol";
import "./ERC721BasicToken.sol";
contract ERC721Token is ERC721, ERC721BasicToken {
  string internal name_;
  string internal symbol_;
  mapping(address => uint256[]) internal ownedTokens;
  mapping(uint256 => uint256) internal ownedTokensIndex;
  uint256[] internal allTokens;
  mapping(uint256 => uint256) internal allTokensIndex;
  mapping(uint256 => address) internal tokenURIs;
  function ERC721Token(string _name, string _symbol) public {
    name_ = _name;
    symbol_ = _symbol;
  }
  function name() public view returns (string) {
    return name_;
  }
  function symbol() public view returns (string) {
    return symbol_;
  }
  function tokenURI(uint256 _tokenId) public view returns (address) {
    require(exists(_tokenId));
    return tokenURIs[_tokenId];
  }
  function tokenOfOwnerByIndex(address _owner, uint256 _index) public view returns (uint256) {
    require(_index < balanceOf(_owner));
    return ownedTokens[_owner][_index];
  }
  function totalSupply() public view returns (uint256) {
    return allTokens.length;
  }
  function tokenByIndex(uint256 _index) public view returns (uint256) {
    require(_index < totalSupply());
    return allTokens[_index];
  }
  function _setTokenURI(uint256 _tokenId, address _uri) internal {
    require(exists(_tokenId));
    tokenURIs[_tokenId] = _uri;
  }
  function addTokenTo(address _to, uint256 _tokenId) internal {
    super.addTokenTo(_to, _tokenId);
    uint256 length = ownedTokens[_to].length;
    ownedTokens[_to].push(_tokenId);
    ownedTokensIndex[_tokenId] = length;
  }
  function removeTokenFrom(address _from, uint256 _tokenId) internal {
    super.removeTokenFrom(_from, _tokenId);
    uint256 tokenIndex = ownedTokensIndex[_tokenId];
    uint256 lastTokenIndex = ownedTokens[_from].length.sub(1);
    uint256 lastToken = ownedTokens[_from][lastTokenIndex];
    ownedTokens[_from][tokenIndex] = lastToken;
    ownedTokens[_from][lastTokenIndex] = 0;
    ownedTokens[_from].length--;
    ownedTokensIndex[_tokenId] = 0;
    ownedTokensIndex[lastToken] = tokenIndex;
  }
  function _mint(address _to, uint256 _tokenId) internal {
    super._mint(_to, _tokenId);
    allTokensIndex[_tokenId] = allTokens.length;
    allTokens.push(_tokenId);
  }
}