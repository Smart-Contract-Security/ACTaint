pragma solidity 0.8.17;
import "./IRoundFactory.sol";
import "./IRoundImplementation.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../utils/MetaPtr.sol";
contract RoundFactory is IRoundFactory, OwnableUpgradeable {
  string public constant VERSION = "0.2.0";
  address public roundImplementation;
  address public alloSettings;
  event AlloSettingsUpdated(address alloSettings);
  event RoundImplementationUpdated(address roundImplementation);
  event RoundCreated(
    address indexed roundAddress,
    address indexed ownedBy,
    address indexed roundImplementation
  );
  function initialize() external initializer {
    __Context_init_unchained();
    __Ownable_init_unchained();
  }
  function updateAlloSettings(address newAlloSettings) external onlyOwner {
    alloSettings = newAlloSettings;
    emit AlloSettingsUpdated(alloSettings);
  }
  function updateRoundImplementation(address payable newRoundImplementation) external onlyOwner {
    require(newRoundImplementation != address(0), "roundImplementation is 0x");
    roundImplementation = newRoundImplementation;
    emit RoundImplementationUpdated(roundImplementation);
  }
  function create(
    bytes calldata encodedParameters,
    address ownedBy
  ) external returns (address) {
    require(roundImplementation != address(0), "roundImplementation is 0x");
    require(alloSettings != address(0), "alloSettings is 0x");
    address clone = ClonesUpgradeable.clone(roundImplementation);
    emit RoundCreated(clone, ownedBy, payable(roundImplementation));
    IRoundImplementation(payable(clone)).initialize(
      encodedParameters,
      alloSettings
    );
    return clone;
  }
}