pragma solidity ^0.4.24;
library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}
pragma solidity ^0.4.24;
library AddressUtils {
  function isContract(address addr) internal view returns (bool) {
    uint256 size;
    assembly { size := extcodesize(addr) }  // solium-disable-line security/no-inline-assembly
    return size > 0;
  }
}
pragma solidity ^0.4.24;
contract DelegateProxy {
  function delegatedFwd(address _dst, bytes _calldata) internal {
    require(isContract(_dst));
    assembly {
      let result := delegatecall(sub(gas, 10000), _dst, add(_calldata, 0x20), mload(_calldata), 0, 0)
      let size := returndatasize
      let ptr := mload(0x40)
      returndatacopy(ptr, 0, size)
      switch result case 0 {revert(ptr, size)}
      default {return (ptr, size)}
    }
  }
  function isContract(address _target) internal view returns (bool) {
    uint256 size;
    assembly {size := extcodesize(_target)}
    return size > 0;
  }
}
pragma solidity ^0.4.13;
contract DSAuthority {
  function canCall(
    address src, address dst, bytes4 sig
  ) public view returns (bool);
}
contract DSAuthEvents {
  event LogSetAuthority (address indexed authority);
  event LogSetOwner     (address indexed owner);
}
contract DSAuth is DSAuthEvents {
  DSAuthority  public  authority;
  address      public  owner;
  function DSAuth() public {
    owner = msg.sender;
    LogSetOwner(msg.sender);
  }
  function setOwner(address owner_)
  public
  auth
  {
    owner = owner_;
    LogSetOwner(owner);
  }
  function setAuthority(DSAuthority authority_)
  public
  auth
  {
    authority = authority_;
    LogSetAuthority(authority);
  }
  modifier auth {
    require(isAuthorized(msg.sender, msg.sig));
    _;
  }
  function isAuthorized(address src, bytes4 sig) internal view returns (bool) {
    if (src == address(this)) {
      return true;
    } else if (src == owner) {
      return true;
    } else if (authority == DSAuthority(0)) {
      return false;
    } else {
      return authority.canCall(src, this, sig);
    }
  }
}
pragma solidity ^0.4.24;
contract ERC721Basic {
  event Transfer(address indexed _from, address indexed _to, uint256 _tokenId, uint256 _timestamp);
  event Approval(address indexed _owner, address indexed _approved, uint256 _tokenId);
  event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
  function balanceOf(address _owner) public view returns (uint256 _balance);
  function ownerOf(uint256 _tokenId) public view returns (address _owner);
  function exists(uint256 _tokenId) public view returns (bool _exists);
  function approve(address _to, uint256 _tokenId) public;
  function getApproved(uint256 _tokenId) public view returns (address _operator);
  function setApprovalForAll(address _operator, bool _approved) public;
  function isApprovedForAll(address _owner, address _operator) public view returns (bool);
  function transferFrom(address _from, address _to, uint256 _tokenId) public;
  function safeTransferFrom(address _from, address _to, uint256 _tokenId) public;
  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId,
    bytes _data
  )
  public;
}
pragma solidity ^0.4.24;
contract ERC721Enumerable is ERC721Basic {
  function totalSupply() public view returns (uint256);
  function tokenOfOwnerByIndex(address _owner, uint256 _index) public view returns (uint256 _tokenId);
  function tokenByIndex(uint256 _index) public view returns (uint256);
}
contract ERC721Metadata is ERC721Basic {
  function name() public view returns (string _name);
  function symbol() public view returns (string _symbol);
  function tokenURI(uint256 _tokenId) public view returns (address);
}
contract ERC721 is ERC721Basic, ERC721Enumerable, ERC721Metadata {
}
pragma solidity ^0.4.24;
contract ERC721BasicToken is ERC721Basic {
  using SafeMath for uint256;
  using AddressUtils for address;
  bytes4 constant ERC721_RECEIVED = 0xf0b9e5ba;
  mapping (uint256 => address) internal tokenOwner;
  mapping (uint256 => address) internal tokenApprovals;
  mapping (address => uint256) internal ownedTokensCount;
  mapping (address => mapping (address => bool)) internal operatorApprovals;
  modifier onlyOwnerOf(uint256 _tokenId) {
    require(ownerOf(_tokenId) == msg.sender);
    _;
  }
  modifier canTransfer(uint256 _tokenId) {
    require(isApprovedOrOwner(msg.sender, _tokenId));
    _;
  }
  function balanceOf(address _owner) public view returns (uint256) {
    require(_owner != address(0));
    return ownedTokensCount[_owner];
  }
  function ownerOf(uint256 _tokenId) public view returns (address) {
    address owner = tokenOwner[_tokenId];
    require(owner != address(0));
    return owner;
  }
  function exists(uint256 _tokenId) public view returns (bool) {
    address owner = tokenOwner[_tokenId];
    return owner != address(0);
  }
  function approve(address _to, uint256 _tokenId) public {
    address owner = ownerOf(_tokenId);
    require(_to != owner);
    require(msg.sender == owner || isApprovedForAll(owner, msg.sender));
    if (getApproved(_tokenId) != address(0) || _to != address(0)) {
      tokenApprovals[_tokenId] = _to;
      Approval(owner, _to, _tokenId);
    }
  }
  function getApproved(uint256 _tokenId) public view returns (address) {
    return tokenApprovals[_tokenId];
  }
  function setApprovalForAll(address _to, bool _approved) public {
    require(_to != msg.sender);
    operatorApprovals[msg.sender][_to] = _approved;
    ApprovalForAll(msg.sender, _to, _approved);
  }
  function isApprovedForAll(address _owner, address _operator) public view returns (bool) {
    return operatorApprovals[_owner][_operator];
  }
  function transferFrom(address _from, address _to, uint256 _tokenId) public canTransfer(_tokenId) {
    require(_from != address(0));
    require(_to != address(0));

    clearApproval(_from, _tokenId);
    removeTokenFrom(_from, _tokenId);
    addTokenTo(_to, _tokenId);

    Transfer(_from, _to, _tokenId, now);
  }
  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId
  )
  public
  canTransfer(_tokenId)
  {
    safeTransferFrom(_from, _to, _tokenId, "");
  }
  function safeTransferFrom(
    address _from,
    address _to,
    uint256 _tokenId,
    bytes _data
  )
  public
  canTransfer(_tokenId)
  {
    transferFrom(_from, _to, _tokenId);
    require(checkAndCallSafeTransfer(_from, _to, _tokenId, _data));
  }
  function isApprovedOrOwner(address _spender, uint256 _tokenId) internal view returns (bool) {
    address owner = ownerOf(_tokenId);
    return _spender == owner || getApproved(_tokenId) == _spender || isApprovedForAll(owner, _spender);
  }
  function _mint(address _to, uint256 _tokenId) internal {
    require(_to != address(0));
    addTokenTo(_to, _tokenId);
    Transfer(address(0), _to, _tokenId, now);
  }
  function _burn(address _owner, uint256 _tokenId) internal {
    clearApproval(_owner, _tokenId);
    removeTokenFrom(_owner, _tokenId);
    Transfer(_owner, address(0), _tokenId, now);
  }
  function clearApproval(address _owner, uint256 _tokenId) internal {
    require(ownerOf(_tokenId) == _owner);
    if (tokenApprovals[_tokenId] != address(0)) {
      tokenApprovals[_tokenId] = address(0);
      Approval(_owner, address(0), _tokenId);
    }
  }
  function addTokenTo(address _to, uint256 _tokenId) internal {
    require(tokenOwner[_tokenId] == address(0));
    tokenOwner[_tokenId] = _to;
    ownedTokensCount[_to] = ownedTokensCount[_to].add(1);
  }
  function removeTokenFrom(address _from, uint256 _tokenId) internal {
    require(ownerOf(_tokenId) == _from);
    ownedTokensCount[_from] = ownedTokensCount[_from].sub(1);
    tokenOwner[_tokenId] = address(0);
  }
  function checkAndCallSafeTransfer(
    address _from,
    address _to,
    uint256 _tokenId,
    bytes _data
  )
  internal
  returns (bool)
  {
    if (!_to.isContract()) {
      return true;
    }
    bytes4 retval = ERC721Receiver(_to).onERC721Received(_from, _tokenId, _data);
    return (retval == ERC721_RECEIVED);
  }
}
pragma solidity ^0.4.21;
contract ERC721Receiver {
  bytes4 constant ERC721_RECEIVED = 0xf0b9e5ba;
  function onERC721Received(address _from, uint256 _tokenId, bytes _data) public returns(bytes4);
}
pragma solidity ^0.4.21;
contract ERC721Holder is ERC721Receiver {
  function onERC721Received(address, uint256, bytes) public returns(bytes4) {
    return ERC721_RECEIVED;
  }
}
pragma solidity ^0.4.24;
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
pragma solidity ^0.4.24;
contract EternalDb is DSAuth {
  enum Types {UInt, String, Address, Bytes, Bytes32, Boolean, Int}
  event EternalDbEvent(bytes32[] records, uint[] values, uint timestamp);
  function EternalDb(){
  }
  mapping(bytes32 => uint) UIntStorage;
  function getUIntValue(bytes32 record) constant returns (uint){
    return UIntStorage[record];
  }
  function getUIntValues(bytes32[] records) constant returns (uint[] results){
    results = new uint[](records.length);
    for (uint i = 0; i < records.length; i++) {
      results[i] = UIntStorage[records[i]];
    }
  }
  function setUIntValue(bytes32 record, uint value)
  auth
  {
    UIntStorage[record] = value;
    bytes32[] memory records = new bytes32[](1);
    records[0] = record;
    uint[] memory values = new uint[](1);
    values[0] = value;
    emit EternalDbEvent(records, values, now);
  }
  function setUIntValues(bytes32[] records, uint[] values)
  auth
  {
    for (uint i = 0; i < records.length; i++) {
      UIntStorage[records[i]] = values[i];
    }
    emit EternalDbEvent(records, values, now);
  }
  function deleteUIntValue(bytes32 record)
  auth
  {
    delete UIntStorage[record];
  }
  mapping(bytes32 => string) StringStorage;
  function getStringValue(bytes32 record) constant returns (string){
    return StringStorage[record];
  }
  function setStringValue(bytes32 record, string value)
  auth
  {
    StringStorage[record] = value;
  }
  function deleteStringValue(bytes32 record)
  auth
  {
    delete StringStorage[record];
  }
  mapping(bytes32 => address) AddressStorage;
  function getAddressValue(bytes32 record) constant returns (address){
    return AddressStorage[record];
  }
  function setAddressValues(bytes32[] records, address[] values)
  auth
  {
    for (uint i = 0; i < records.length; i++) {
      AddressStorage[records[i]] = values[i];
    }
  }
  function setAddressValue(bytes32 record, address value)
  auth
  {
    AddressStorage[record] = value;
  }
  function deleteAddressValue(bytes32 record)
  auth
  {
    delete AddressStorage[record];
  }
  mapping(bytes32 => bytes) BytesStorage;

  function getBytesValue(bytes32 record) constant returns (bytes){
    return BytesStorage[record];
  }
  function setBytesValue(bytes32 record, bytes value)
  auth
  {
    BytesStorage[record] = value;
  }
  function deleteBytesValue(bytes32 record)
  auth
  {
    delete BytesStorage[record];
  }
  mapping(bytes32 => bytes32) Bytes32Storage;
  function getBytes32Value(bytes32 record) constant returns (bytes32){
    return Bytes32Storage[record];
  }
  function getBytes32Values(bytes32[] records) constant returns (bytes32[] results){
    results = new bytes32[](records.length);
    for (uint i = 0; i < records.length; i++) {
      results[i] = Bytes32Storage[records[i]];
    }
  }
  function setBytes32Value(bytes32 record, bytes32 value)
  auth
  {
    Bytes32Storage[record] = value;
  }
  function setBytes32Values(bytes32[] records, bytes32[] values)
  auth
  {
    for (uint i = 0; i < records.length; i++) {
      Bytes32Storage[records[i]] = values[i];
    }
  }
  function deleteBytes32Value(bytes32 record)
  auth
  {
    delete Bytes32Storage[record];
  }
  mapping(bytes32 => bool) BooleanStorage;
  function getBooleanValue(bytes32 record) constant returns (bool){
    return BooleanStorage[record];
  }
  function getBooleanValues(bytes32[] records) constant returns (bool[] results){
    results = new bool[](records.length);
    for (uint i = 0; i < records.length; i++) {
      results[i] = BooleanStorage[records[i]];
    }
  }
  function setBooleanValue(bytes32 record, bool value)
  auth
  {
    BooleanStorage[record] = value;
  }
  function setBooleanValues(bytes32[] records, bool[] values)
  auth
  {
    for (uint i = 0; i < records.length; i++) {
      BooleanStorage[records[i]] = values[i];
    }
  }
  function deleteBooleanValue(bytes32 record)
  auth
  {
    delete BooleanStorage[record];
  }
  mapping(bytes32 => int) IntStorage;

  function getIntValue(bytes32 record) constant returns (int){
    return IntStorage[record];
  }
  function getIntValues(bytes32[] records) constant returns (int[] results){
    results = new int[](records.length);
    for (uint i = 0; i < records.length; i++) {
      results[i] = IntStorage[records[i]];
    }
  }
  function setIntValue(bytes32 record, int value)
  auth
  {
    IntStorage[record] = value;
  }
  function setIntValues(bytes32[] records, int[] values)
  auth
  {
    for (uint i = 0; i < records.length; i++) {
      IntStorage[records[i]] = values[i];
    }
  }
  function deleteIntValue(bytes32 record)
  auth
  {
    delete IntStorage[record];
  }
}
pragma solidity ^0.4.24;
contract MemeToken is ERC721Token {
  Registry public registry;
  modifier onlyRegistryEntry() {
    require(registry.isRegistryEntry(msg.sender),"MemeToken: onlyRegistryEntry failed");
    _;
  }
  function MemeToken(Registry _registry)
  ERC721Token("MemeToken", "MEME")
  {
    registry = _registry;
  }
  function mint(address _to, uint256 _tokenId)
  onlyRegistryEntry
  public
  {
    super._mint(_to, _tokenId);
    tokenURIs[_tokenId] = msg.sender;
  }
  function safeTransferFromMulti(
    address _from,
    address _to,
    uint256[] _tokenIds,
    bytes _data
  ) {
    for (uint i = 0; i < _tokenIds.length; i++) {
      safeTransferFrom(_from, _to, _tokenIds[i], _data);
    }
  }
}
pragma solidity ^0.4.24;
contract MutableForwarder is DelegateProxy, DSAuth {
  address public target = 0xBEeFbeefbEefbeEFbeEfbEEfBEeFbeEfBeEfBeef;
  function setTarget(address _target) public auth {
    target = _target;
  }
  function() payable {
    delegatedFwd(target, msg.data);
  }
}
pragma solidity ^0.4.24;
contract Registry is DSAuth {
  address private dummyTarget; 
  bytes32 public constant challengePeriodDurationKey = keccak256(abi.encodePacked("challengePeriodDuration"));
  bytes32 public constant commitPeriodDurationKey = keccak256(abi.encodePacked("commitPeriodDuration"));
  bytes32 public constant revealPeriodDurationKey = keccak256(abi.encodePacked("revealPeriodDuration"));
  bytes32 public constant depositKey = keccak256(abi.encodePacked("deposit"));
  bytes32 public constant challengeDispensationKey = keccak256(abi.encodePacked("challengeDispensation"));
  bytes32 public constant voteQuorumKey = keccak256(abi.encodePacked("voteQuorum"));
  bytes32 public constant maxTotalSupplyKey = keccak256(abi.encodePacked("maxTotalSupply"));
  bytes32 public constant maxAuctionDurationKey = keccak256(abi.encodePacked("maxAuctionDuration"));
  event MemeConstructedEvent(address registryEntry, uint version, address creator, bytes metaHash, uint totalSupply, uint deposit, uint challengePeriodEnd);
  event MemeMintedEvent(address registryEntry, uint version, address creator, uint tokenStartId, uint tokenEndId, uint totalMinted);
  event ChallengeCreatedEvent(address registryEntry, uint version, address challenger, uint commitPeriodEnd, uint revealPeriodEnd, uint rewardPool, bytes metahash);
  event VoteCommittedEvent(address registryEntry, uint version, address voter, uint amount);
  event VoteRevealedEvent(address registryEntry, uint version, address voter, uint option);
  event VoteAmountClaimedEvent(address registryEntry, uint version, address voter);
  event VoteRewardClaimedEvent(address registryEntry, uint version, address voter, uint amount);
  event ChallengeRewardClaimedEvent(address registryEntry, uint version, address challenger, uint amount);
  event ParamChangeConstructedEvent(address registryEntry, uint version, address creator, address db, string key, uint value, uint deposit, uint challengePeriodEnd);
  event ParamChangeAppliedEvent(address registryEntry, uint version);
  EternalDb public db;
  bool private wasConstructed;
  function construct(EternalDb _db)
  external
  {
    require(address(_db) != 0x0, "Registry: Address can't be 0x0");

    db = _db;
    wasConstructed = true;
    owner = msg.sender;
  }
  modifier onlyFactory() {
    require(isFactory(msg.sender), "Registry: Sender should be factory");
    _;
  }
  modifier onlyRegistryEntry() {
    require(isRegistryEntry(msg.sender), "Registry: Sender should registry entry");
    _;
  }
  modifier notEmergency() {
    require(!isEmergency(),"Registry: Emergency mode is enable");
    _;
  }
  function setFactory(address _factory, bool _isFactory)
  external
  auth
  {
    db.setBooleanValue(keccak256(abi.encodePacked("isFactory", _factory)), _isFactory);
  }
  function addRegistryEntry(address _registryEntry)
  external
  onlyFactory
  notEmergency
  {
    db.setBooleanValue(keccak256(abi.encodePacked("isRegistryEntry", _registryEntry)), true);
  }
  function setEmergency(bool _isEmergency)
  external
  auth
  {
    db.setBooleanValue("isEmergency", _isEmergency);
  }
  function fireMemeConstructedEvent(uint version, address creator, bytes metaHash, uint totalSupply, uint deposit, uint challengePeriodEnd)
  public
  onlyRegistryEntry
  {
    emit MemeConstructedEvent(msg.sender, version, creator, metaHash, totalSupply, deposit, challengePeriodEnd);
  }
  function fireMemeMintedEvent(uint version, address creator, uint tokenStartId, uint tokenEndId, uint totalMinted)
  public
  onlyRegistryEntry
  {
    emit MemeMintedEvent(msg.sender, version, creator, tokenStartId, tokenEndId, totalMinted);
  }
  function fireChallengeCreatedEvent(uint version, address challenger, uint commitPeriodEnd, uint revealPeriodEnd, uint rewardPool, bytes metahash)
  public
  onlyRegistryEntry
  {
    emit ChallengeCreatedEvent(msg.sender, version,  challenger, commitPeriodEnd, revealPeriodEnd, rewardPool, metahash);
  }
  function fireVoteCommittedEvent(uint version, address voter, uint amount)
  public
  onlyRegistryEntry
  {
    emit VoteCommittedEvent(msg.sender, version, voter, amount);
  }
  function fireVoteRevealedEvent(uint version, address voter, uint option)
  public
  onlyRegistryEntry
  {
    emit VoteRevealedEvent(msg.sender, version, voter, option);
  }
  function fireVoteAmountClaimedEvent(uint version, address voter)
  public
  onlyRegistryEntry
  {
    emit VoteAmountClaimedEvent(msg.sender, version, voter);
  }
  function fireVoteRewardClaimedEvent(uint version, address voter, uint amount)
  public
  onlyRegistryEntry
  {
    emit VoteRewardClaimedEvent(msg.sender, version, voter, amount);
  }
  function fireChallengeRewardClaimedEvent(uint version, address challenger, uint amount)
  public
  onlyRegistryEntry
  {
    emit ChallengeRewardClaimedEvent(msg.sender, version, challenger, amount);
  }
  function fireParamChangeConstructedEvent(uint version, address creator, address db, string key, uint value, uint deposit, uint challengePeriodEnd)
  public
  onlyRegistryEntry
  {
    emit ParamChangeConstructedEvent(msg.sender, version, creator, db, key, value, deposit, challengePeriodEnd);
  }
  function fireParamChangeAppliedEvent(uint version)
  public
  onlyRegistryEntry
  {
    emit ParamChangeAppliedEvent(msg.sender, version);
  }
  function isFactory(address factory) public constant returns (bool) {
    return db.getBooleanValue(keccak256(abi.encodePacked("isFactory", factory)));
  }
  function isRegistryEntry(address registryEntry) public constant returns (bool) {
    return db.getBooleanValue(keccak256(abi.encodePacked("isRegistryEntry", registryEntry)));
  }
  function isEmergency() public constant returns (bool) {
    return db.getBooleanValue("isEmergency");
  }
}
