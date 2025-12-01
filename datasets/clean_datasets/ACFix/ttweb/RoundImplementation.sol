pragma solidity 0.8.17;
import "./IRoundImplementation.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../settings/AlloSettings.sol";
import "../votingStrategy/IVotingStrategy.sol";
import "../payoutStrategy/IPayoutStrategy.sol";
import "../utils/MetaPtr.sol";
contract RoundImplementation is IRoundImplementation, AccessControlEnumerable, Initializable {
  string public constant VERSION = "1.0.0";
  using Address for address;
  using SafeERC20 for IERC20;
  bytes32 public constant ROUND_OPERATOR_ROLE = keccak256("ROUND_OPERATOR");
  event MatchAmountUpdated(uint256 newAmount);
  event RoundFeePercentageUpdated(uint32 roundFeePercentage);
  event RoundFeeAddressUpdated(address roundFeeAddress);
  event RoundMetaPtrUpdated(MetaPtr oldMetaPtr, MetaPtr newMetaPtr);
  event ApplicationMetaPtrUpdated(MetaPtr oldMetaPtr, MetaPtr newMetaPtr);
  event ApplicationsStartTimeUpdated(uint256 oldTime, uint256 newTime);
  event ApplicationsEndTimeUpdated(uint256 oldTime, uint256 newTime);
  event RoundStartTimeUpdated(uint256 oldTime, uint256 newTime);
  event RoundEndTimeUpdated(uint256 oldTime, uint256 newTime);
  event ProjectsMetaPtrUpdated(MetaPtr oldMetaPtr, MetaPtr newMetaPtr);
  event NewProjectApplication(bytes32 indexed projectID, uint256 applicationIndex, MetaPtr applicationMetaPtr);
  event PayFeeAndEscrowFundsToPayoutContract(uint256 matchAmountAfterFees, uint protocolFeeAmount, uint roundFeeAmount);
  event ApplicationStatusesUpdated(uint256 indexed index, uint256 indexed status);
  modifier roundHasNotEnded() {
    require(block.timestamp <= roundEndTime, "Round: Round has ended");
     _;
  }
  modifier roundHasEnded() {
    require(block.timestamp > roundEndTime, "Round: Round has not ended");
    _;
  }
  AlloSettings public alloSettings;
  IVotingStrategy public votingStrategy;
  IPayoutStrategy public payoutStrategy;
  uint256 public applicationsStartTime;
  uint256 public applicationsEndTime;
  uint256 public roundStartTime;
  uint256 public roundEndTime;
  uint256 public matchAmount;
  address public token;
  uint32 public roundFeePercentage;
  address payable public roundFeeAddress;
  MetaPtr public roundMetaPtr;
  MetaPtr public applicationMetaPtr;
  struct InitAddress {
    IVotingStrategy votingStrategy; 
    IPayoutStrategy payoutStrategy; 
  }
  struct InitRoundTime {
    uint256 applicationsStartTime; 
    uint256 applicationsEndTime; 
    uint256 roundStartTime; 
    uint256 roundEndTime; 
  }
  struct InitMetaPtr {
    MetaPtr roundMetaPtr; 
    MetaPtr applicationMetaPtr; 
  }
  struct InitRoles {
    address[] adminRoles; 
    address[] roundOperators; 
  }
  struct Application {
    bytes32 projectID;
    uint256 applicationIndex;
    MetaPtr metaPtr;
  }
  uint256 public nextApplicationIndex;
  Application[] public applications;
  mapping(bytes32 => uint256[]) public applicationsIndexesByProjectID;
  mapping(uint256 => uint256) public applicationStatusesBitMap;
  function initialize(
    bytes calldata encodedParameters,
    address _alloSettings
  ) external initializer {
    (
      InitAddress memory _initAddress,
      InitRoundTime memory _initRoundTime,
      uint256 _matchAmount,
      address _token,
      uint32 _roundFeePercentage,
      address payable _roundFeeAddress,
      InitMetaPtr memory _initMetaPtr,
      InitRoles memory _initRoles
    ) = abi.decode(
      encodedParameters, (
      (InitAddress),
      (InitRoundTime),
      uint256,
      address,
      uint32,
      address,
      (InitMetaPtr),
      (InitRoles)
    ));
    require(
      _initRoundTime.applicationsStartTime >= block.timestamp,
      "Round: Time has already passed"
    );
    require(
      _initRoundTime.applicationsEndTime > _initRoundTime.applicationsStartTime,
      "Round: App end is before app start"
    );
    require(
      _initRoundTime.roundEndTime >= _initRoundTime.applicationsEndTime,
      "Round: Round end is before app end"
    );
    require(
      _initRoundTime.roundEndTime > _initRoundTime.roundStartTime,
      "Round: Round end is before round start"
    );
    require(
      _initRoundTime.roundStartTime >= _initRoundTime.applicationsStartTime,
      "Round: Round start is before app start"
    );
    alloSettings = AlloSettings(_alloSettings);
    votingStrategy = _initAddress.votingStrategy;
    payoutStrategy = _initAddress.payoutStrategy;
    applicationsStartTime = _initRoundTime.applicationsStartTime;
    applicationsEndTime = _initRoundTime.applicationsEndTime;
    roundStartTime = _initRoundTime.roundStartTime;
    roundEndTime = _initRoundTime.roundEndTime;
    token = _token;
    votingStrategy.init();
    payoutStrategy.init();
    matchAmount = _matchAmount;
    roundFeePercentage = _roundFeePercentage;
    roundFeeAddress = _roundFeeAddress;
    roundMetaPtr = _initMetaPtr.roundMetaPtr;
    applicationMetaPtr = _initMetaPtr.applicationMetaPtr;
    for (uint256 i = 0; i < _initRoles.adminRoles.length; ++i) {
      _grantRole(DEFAULT_ADMIN_ROLE, _initRoles.adminRoles[i]);
    }
    for (uint256 i = 0; i < _initRoles.roundOperators.length; ++i) {
      _grantRole(ROUND_OPERATOR_ROLE, _initRoles.roundOperators[i]);
    }
  }
  function updateMatchAmount(uint256 newAmount) external roundHasNotEnded onlyRole(ROUND_OPERATOR_ROLE) {
    require(newAmount > matchAmount, "Round: Lesser than current match amount");
    matchAmount = newAmount;
    emit MatchAmountUpdated(newAmount);
  }
  function updateRoundFeePercentage(uint32 newFeePercentage) external roundHasNotEnded onlyRole(ROUND_OPERATOR_ROLE) {
    roundFeePercentage = newFeePercentage;
    emit RoundFeePercentageUpdated(roundFeePercentage);
  }
  function updateRoundFeeAddress(address payable newFeeAddress) external roundHasNotEnded onlyRole(ROUND_OPERATOR_ROLE) {
    roundFeeAddress = newFeeAddress;
    emit RoundFeeAddressUpdated(roundFeeAddress);
  }
  function updateRoundMetaPtr(MetaPtr memory newRoundMetaPtr) external roundHasNotEnded onlyRole(ROUND_OPERATOR_ROLE) {
    emit RoundMetaPtrUpdated(roundMetaPtr, newRoundMetaPtr);
    roundMetaPtr = newRoundMetaPtr;
  }
  function updateApplicationMetaPtr(MetaPtr memory newApplicationMetaPtr) external roundHasNotEnded onlyRole(ROUND_OPERATOR_ROLE) {
    emit ApplicationMetaPtrUpdated(applicationMetaPtr, newApplicationMetaPtr);
    applicationMetaPtr = newApplicationMetaPtr;
  }
  function updateStartAndEndTimes(
    uint256 newApplicationsStartTime,
    uint256 newApplicationsEndTime,
    uint256 newRoundStartTime,
    uint256 newRoundEndTime
  ) external roundHasNotEnded onlyRole(ROUND_OPERATOR_ROLE) {
    require(newApplicationsStartTime < newApplicationsEndTime, "Round: Application end is before application start");
    require(newRoundStartTime < newRoundEndTime, "Round: Round end is before round start");
    require(newApplicationsStartTime <= newRoundStartTime, "Round: Round start is before application start");
    require(newApplicationsEndTime <= newRoundEndTime, "Round: Round end is before application end");
    require(block.timestamp <= newApplicationsStartTime, "Round: Time has already passed");
    if (
      applicationsStartTime >= block.timestamp &&
      newApplicationsStartTime != applicationsStartTime
    ) {
      emit ApplicationsStartTimeUpdated(applicationsStartTime, newApplicationsStartTime);
      applicationsStartTime = newApplicationsStartTime;
    }
    if (
      applicationsEndTime >= block.timestamp &&
      newApplicationsEndTime != applicationsEndTime
    ) {
      emit ApplicationsEndTimeUpdated(applicationsEndTime, newApplicationsEndTime);
      applicationsEndTime = newApplicationsEndTime;
    }
    if (
      roundStartTime >= block.timestamp &&
      newRoundStartTime != roundStartTime
    ) {
      emit RoundStartTimeUpdated(roundStartTime, newRoundStartTime);
      roundStartTime = newRoundStartTime;
    }
    if (
      roundEndTime >= block.timestamp &&
      newRoundEndTime != roundEndTime
    ) {
      emit RoundEndTimeUpdated(roundEndTime, newRoundEndTime);
      roundEndTime = newRoundEndTime;
    }
  }
  function applyToRound(bytes32 projectID, MetaPtr calldata newApplicationMetaPtr) external {
    require(
      applicationsStartTime <= block.timestamp  &&
      block.timestamp <= applicationsEndTime,
      "Round: Applications period not started or over"
    );
    applications.push(Application(projectID, nextApplicationIndex, newApplicationMetaPtr));
    applicationsIndexesByProjectID[projectID].push(nextApplicationIndex);
    emit NewProjectApplication(projectID, nextApplicationIndex, newApplicationMetaPtr);
    nextApplicationIndex++;
  }
  function getApplicationIndexesByProjectID(bytes32 projectID) external view returns(uint256[] memory) {
    return applicationsIndexesByProjectID[projectID];
  }
  function setApplicationStatuses(ApplicationStatus[] memory statuses) external roundHasNotEnded onlyRole(ROUND_OPERATOR_ROLE) {
    for (uint256 i = 0; i < statuses.length;) {
      uint256 rowIndex = statuses[i].index;
      uint256 fullRow = statuses[i].statusRow;
      applicationStatusesBitMap[rowIndex] = fullRow;
      emit ApplicationStatusesUpdated(rowIndex, fullRow);
      unchecked {
        i++;
      }
    }
  }
  function getApplicationStatus(uint256 applicationIndex) external view returns(uint256) {
    require(applicationIndex < applications.length, "Round: Application does not exist");
    uint256 rowIndex = applicationIndex / 128;
    uint256 colIndex = (applicationIndex % 128) * 2;
    uint256 currentRow = applicationStatusesBitMap[rowIndex];
    uint256 status = (currentRow >> colIndex) & 3;
    return status;
  }
  function vote(bytes[] memory encodedVotes) external payable {
    require(
      roundStartTime <= block.timestamp &&
      block.timestamp <= roundEndTime,
      "Round: Round is not active"
    );
    votingStrategy.vote{value: msg.value}(encodedVotes, msg.sender);
  }
  function setReadyForPayout() external payable roundHasEnded onlyRole(ROUND_OPERATOR_ROLE) {
    uint256 fundsInContract = _getTokenBalance(token);
    uint32 denominator = alloSettings.DENOMINATOR();
    uint256 protocolFeeAmount = (matchAmount * alloSettings.protocolFeePercentage()) / denominator;
    uint256 roundFeeAmount = (matchAmount * roundFeePercentage) / denominator;
    uint256 neededFunds = matchAmount + protocolFeeAmount + roundFeeAmount;
    require(fundsInContract >= neededFunds, "Round: Not enough funds in contract");
    if (protocolFeeAmount > 0) {
      address payable protocolTreasury = alloSettings.protocolTreasury();
      _transferAmount(protocolTreasury, protocolFeeAmount, token);
    }
    if (roundFeeAmount > 0) {
      _transferAmount(roundFeeAddress, roundFeeAmount, token);
    }
    fundsInContract = _getTokenBalance(token);
    if (token == address(0)) {
      payoutStrategy.setReadyForPayout{value: fundsInContract}();
    } else {
      IERC20(token).safeTransfer(address(payoutStrategy), fundsInContract);
      payoutStrategy.setReadyForPayout();
    }
    emit PayFeeAndEscrowFundsToPayoutContract(fundsInContract, protocolFeeAmount, roundFeeAmount);
  }
  function withdraw(address tokenAddress, address payable recipent) external onlyRole(ROUND_OPERATOR_ROLE) {
    require(tokenAddress != token, "Round: Cannot withdraw round token");
    _transferAmount(recipent, _getTokenBalance(tokenAddress), tokenAddress);
  }
  function _getTokenBalance(address tokenAddress) private view returns (uint256) {
    if (tokenAddress == address(0)) {
      return address(this).balance;
    } else {
      return IERC20(tokenAddress).balanceOf(address(this));
    }
  }
  function _transferAmount(address payable _recipient, uint256 _amount, address _tokenAddress) private {
    if (_tokenAddress == address(0)) {
      Address.sendValue(_recipient, _amount);
    } else {
      IERC20(_tokenAddress).safeTransfer(_recipient, _amount);
    }
  }
  receive() external payable {}
}