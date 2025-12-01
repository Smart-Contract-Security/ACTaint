pragma solidity 0.8.17;
import '../Storage/OpenQStorage.sol';
contract OpenQV1 is OpenQStorageV1 {
    constructor() {}
    function initialize() external initializer onlyProxy {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }
    function mintBounty(
        string calldata _bountyId,
        string calldata _organization,
        OpenQDefinitions.InitOperation memory _initOperation
    ) external nonReentrant onlyProxy returns (address) {
        require(
            bountyIdToAddress[_bountyId] == address(0),
            Errors.BOUNTY_ALREADY_EXISTS
        );
        address bountyAddress = bountyFactory.mintBounty(
            _bountyId,
            msg.sender,
            _organization,
            claimManager,
            depositManager,
            _initOperation
        );
        bountyIdToAddress[_bountyId] = bountyAddress;
        emit BountyCreated(
            _bountyId,
            _organization,
            msg.sender,
            bountyAddress,
            block.timestamp,
            bountyType(_bountyId),
            _initOperation.data,
            VERSION_1
        );
        return bountyAddress;
    }
    function setBountyFactory(address _bountyFactory)
        external
        onlyProxy
        onlyOwner
    {
        bountyFactory = BountyFactory(_bountyFactory);
    }
    function setClaimManager(address _claimManager)
        external
        onlyProxy
        onlyOwner
    {
        claimManager = _claimManager;
    }
    function setDepositManager(address _depositManager)
        external
        onlyProxy
        onlyOwner
    {
        depositManager = _depositManager;
    }
    function setTierWinner(
        string calldata _bountyId,
        uint256 _tier,
        string calldata _winner
    ) external {
        IBounty bounty = getBounty(_bountyId);
        require(msg.sender == bounty.issuer(), Errors.CALLER_NOT_ISSUER);
        bounty.setTierWinner(_winner, _tier);
        emit TierWinnerSelected(
            address(bounty),
            bounty.getTierWinners(),
            new bytes(0),
            VERSION_1
        );
    }
    function setFundingGoal(
        string calldata _bountyId,
        address _fundingGoalToken,
        uint256 _fundingGoalVolume
    ) external onlyProxy {
        IBounty bounty = getBounty(_bountyId);
        require(msg.sender == bounty.issuer(), Errors.CALLER_NOT_ISSUER);
        bounty.setFundingGoal(_fundingGoalToken, _fundingGoalVolume);
        emit FundingGoalSet(
            address(bounty),
            _fundingGoalToken,
            _fundingGoalVolume,
            bounty.bountyType(),
            new bytes(0),
            VERSION_1
        );
    }
    function setKycRequired(string calldata _bountyId, bool _kycRequired)
        external
        onlyProxy
    {
        IBounty bounty = getBounty(_bountyId);
        require(msg.sender == bounty.issuer(), Errors.CALLER_NOT_ISSUER);
        bounty.setKycRequired(_kycRequired);
        emit KYCRequiredSet(
            address(bounty),
            _kycRequired,
            bounty.bountyType(),
            new bytes(0),
            VERSION_1
        );
    }
    function setInvoiceRequired(
        string calldata _bountyId,
        bool _invoiceRequired
    ) external onlyProxy {
        IBounty bounty = getBounty(_bountyId);
        require(msg.sender == bounty.issuer(), Errors.CALLER_NOT_ISSUER);
        bounty.setInvoiceRequired(_invoiceRequired);
        emit InvoiceRequiredSet(
            address(bounty),
            _invoiceRequired,
            bounty.bountyType(),
            new bytes(0),
            VERSION_1
        );
    }
    function setSupportingDocumentsRequired(
        string calldata _bountyId,
        bool _supportingDocumentsRequired
    ) external onlyProxy {
        IBounty bounty = getBounty(_bountyId);
        require(msg.sender == bounty.issuer(), Errors.CALLER_NOT_ISSUER);
        bounty.setSupportingDocumentsRequired(_supportingDocumentsRequired);
        emit SupportingDocumentsRequiredSet(
            address(bounty),
            _supportingDocumentsRequired,
            bounty.bountyType(),
            new bytes(0),
            VERSION_1
        );
    }
    function setInvoiceComplete(string calldata _bountyId, bytes calldata _data)
        external
        onlyProxy
    {
        IBounty bounty = getBounty(_bountyId);
        require(
            msg.sender == bounty.issuer() || msg.sender == _oracle,
            Errors.CALLER_NOT_ISSUER_OR_ORACLE
        );
        bounty.setInvoiceComplete(_data);
        emit InvoiceCompleteSet(
            address(bounty),
            bounty.bountyType(),
            bounty.getInvoiceComplete(),
            VERSION_1
        );
    }
    function setSupportingDocumentsComplete(
        string calldata _bountyId,
        bytes calldata _data
    ) external onlyProxy {
        IBounty bounty = getBounty(_bountyId);
        require(
            msg.sender == bounty.issuer() || msg.sender == _oracle,
            Errors.CALLER_NOT_ISSUER_OR_ORACLE
        );
        bounty.setSupportingDocumentsComplete(_data);
        emit SupportingDocumentsCompleteSet(
            address(bounty),
            bounty.bountyType(),
            bounty.getSupportingDocumentsComplete(),
            VERSION_1
        );
    }
    function setPayout(
        string calldata _bountyId,
        address _payoutToken,
        uint256 _payoutVolume
    ) external onlyProxy {
        IBounty bounty = getBounty(_bountyId);
        require(msg.sender == bounty.issuer(), Errors.CALLER_NOT_ISSUER);
        bounty.setPayout(_payoutToken, _payoutVolume);
        emit PayoutSet(
            address(bounty),
            _payoutToken,
            _payoutVolume,
            bounty.bountyType(),
            new bytes(0),
            VERSION_1
        );
    }
    function setPayoutSchedule(
        string calldata _bountyId,
        uint256[] calldata _payoutSchedule
    ) external onlyProxy {
        IBounty bounty = getBounty(_bountyId);
        require(msg.sender == bounty.issuer(), Errors.CALLER_NOT_ISSUER);
        bounty.setPayoutSchedule(_payoutSchedule);
        emit PayoutScheduleSet(
            address(bounty),
            address(0),
            _payoutSchedule,
            bounty.bountyType(),
            new bytes(0),
            VERSION_1
        );
    }
    function setPayoutScheduleFixed(
        string calldata _bountyId,
        uint256[] calldata _payoutSchedule,
        address _payoutTokenAddress
    ) external onlyProxy {
        IBounty bounty = getBounty(_bountyId);
        require(msg.sender == bounty.issuer(), Errors.CALLER_NOT_ISSUER);
        bounty.setPayoutScheduleFixed(_payoutSchedule, _payoutTokenAddress);
        emit PayoutScheduleSet(
            address(bounty),
            _payoutTokenAddress,
            _payoutSchedule,
            bounty.bountyType(),
            new bytes(0),
            VERSION_1
        );
    }
    function closeOngoing(string calldata _bountyId) external {
        require(bountyIsOpen(_bountyId), Errors.CONTRACT_ALREADY_CLOSED);
        require(
            bountyType(_bountyId) == OpenQDefinitions.ONGOING,
            Errors.NOT_AN_ONGOING_CONTRACT
        );
        IBounty bounty = IBounty(payable(bountyIdToAddress[_bountyId]));
        require(msg.sender == bounty.issuer(), Errors.CALLER_NOT_ISSUER);
        bounty.closeOngoing(msg.sender);
        emit BountyClosed(
            _bountyId,
            bountyIdToAddress[_bountyId],
            bounty.organization(),
            address(0),
            block.timestamp,
            bounty.bountyType(),
            new bytes(0),
            VERSION_1
        );
    }
    function bountyIsOpen(string calldata _bountyId)
        public
        view
        returns (bool)
    {
        IBounty bounty = getBounty(_bountyId);
        bool isOpen = bounty.status() == OpenQDefinitions.OPEN;
        return isOpen;
    }
    function bountyType(string calldata _bountyId)
        public
        view
        returns (uint256)
    {
        IBounty bounty = getBounty(_bountyId);
        uint256 _bountyType = bounty.bountyType();
        return _bountyType;
    }
    function bountyAddressToBountyId(address _bountyAddress)
        external
        view
        returns (string memory)
    {
        IBounty bounty = IBounty(payable(_bountyAddress));
        return bounty.bountyId();
    }
    function tierClaimed(string calldata _bountyId, uint256 _tier)
        external
        view
        returns (bool)
    {
        IBounty bounty = getBounty(_bountyId);
        bool _tierClaimed = bounty.tierClaimed(_tier);
        return _tierClaimed;
    }
    function solvent(string calldata _bountyId) external view returns (bool) {
        IBounty bounty = getBounty(_bountyId);
        uint256 balance = bounty.getTokenBalance(bounty.payoutTokenAddress());
        return balance >= bounty.payoutVolume();
    }
    function getBounty(string calldata _bountyId)
        internal
        view
        returns (IBounty)
    {
        address bountyAddress = bountyIdToAddress[_bountyId];
        IBounty bounty = IBounty(bountyAddress);
        return bounty;
    }
    function ongoingClaimed(
        string calldata _bountyId,
        string calldata _claimant,
        string calldata _claimantAsset
    ) external view returns (bool) {
        IBounty bounty = getBounty(_bountyId);
        bytes32 claimId = keccak256(abi.encode(_claimant, _claimantAsset));
        bool _ongoingClaimed = bounty.claimId(claimId);
        return _ongoingClaimed;
    }
    function _authorizeUpgrade(address) internal override onlyOwner {}
    function getImplementation() external view returns (address) {
        return _getImplementation();
    }
    function transferOracle(address _newOracle) external onlyProxy onlyOwner {
        require(_newOracle != address(0), Errors.NO_ZERO_ADDRESS);
        _transferOracle(_newOracle);
    }
    function associateExternalIdToAddress(
        string calldata _externalUserId,
        address _associatedAddress
    ) external onlyOracle {
        string memory formerExternalUserId = addressToExternalUserId[
            _associatedAddress
        ];
        address formerAddress = externalUserIdToAddress[_externalUserId];
        externalUserIdToAddress[formerExternalUserId] = address(0);
        addressToExternalUserId[formerAddress] = '';
        externalUserIdToAddress[_externalUserId] = _associatedAddress;
        addressToExternalUserId[_associatedAddress] = _externalUserId;
        emit ExternalUserIdAssociatedWithAddress(
            _externalUserId,
            _associatedAddress,
            formerExternalUserId,
            formerAddress,
            new bytes(0),
            VERSION_1
        );
    }
}