pragma solidity ^0.4.24;
import "./DSAuth.sol";
import "./EternalDb.sol";
import "./MutableForwarder.sol"; 
contract Registry is DSAuth {
  address private dummyTarget; 
  bytes32 public constant challengePeriodDurationKey = sha3("challengePeriodDuration");
  bytes32 public constant commitPeriodDurationKey = sha3("commitPeriodDuration");
  bytes32 public constant revealPeriodDurationKey = sha3("revealPeriodDuration");
  bytes32 public constant depositKey = sha3("deposit");
  bytes32 public constant challengeDispensationKey = sha3("challengeDispensation");
  bytes32 public constant voteQuorumKey = sha3("voteQuorum");
  bytes32 public constant maxTotalSupplyKey = sha3("maxTotalSupply");
  bytes32 public constant maxAuctionDurationKey = sha3("maxAuctionDuration");
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
    db.setBooleanValue(sha3("isFactory", _factory), _isFactory);
  }
  function addRegistryEntry(address _registryEntry)
  external
  onlyFactory
  notEmergency
  {
    db.setBooleanValue(sha3("isRegistryEntry", _registryEntry), true);
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
    return db.getBooleanValue(sha3("isFactory", factory));
  }
  function isRegistryEntry(address registryEntry) public constant returns (bool) {
    return db.getBooleanValue(sha3("isRegistryEntry", registryEntry));
  }
  function isEmergency() public constant returns (bool) {
    return db.getBooleanValue("isEmergency");
  }
}