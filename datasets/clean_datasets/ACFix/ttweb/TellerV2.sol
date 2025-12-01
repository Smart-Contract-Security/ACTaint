pragma solidity >=0.8.0 <0.9.0;
import "./ProtocolFee.sol";
import "./TellerV2Storage.sol";
import "./TellerV2Context.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "./interfaces/IMarketRegistry.sol";
import "./interfaces/IReputationManager.sol";
import "./interfaces/ITellerV2.sol";
import { Collateral } from "./interfaces/escrow/ICollateralEscrowV1.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/NumbersLib.sol";
import { BokkyPooBahsDateTimeLibrary as BPBDTL } from "./libraries/DateTimeLib.sol";
import { V2Calculations, PaymentCycleType } from "./libraries/V2Calculations.sol";
error ActionNotAllowed(uint256 bidId, string action, string message);
error PaymentNotMinimum(uint256 bidId, uint256 payment, uint256 minimumOwed);
contract TellerV2 is
    ITellerV2,
    OwnableUpgradeable,
    ProtocolFee,
    PausableUpgradeable,
    TellerV2Storage,
    TellerV2Context
{
    using Address for address;
    using SafeERC20 for ERC20;
    using NumbersLib for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    event SubmittedBid(
        uint256 indexed bidId,
        address indexed borrower,
        address receiver,
        bytes32 indexed metadataURI
    );
    event AcceptedBid(uint256 indexed bidId, address indexed lender);
    event CancelledBid(uint256 indexed bidId);
    event MarketOwnerCancelledBid(uint256 indexed bidId);
    event LoanRepayment(uint256 indexed bidId);
    event LoanRepaid(uint256 indexed bidId);
    event LoanLiquidated(uint256 indexed bidId, address indexed liquidator);
    event FeePaid(
        uint256 indexed bidId,
        string indexed feeType,
        uint256 indexed amount
    );
    modifier pendingBid(uint256 _bidId, string memory _action) {
        if (bids[_bidId].state != BidState.PENDING) {
            revert ActionNotAllowed(_bidId, _action, "Bid must be pending");
        }
        _;
    }
    modifier acceptedLoan(uint256 _bidId, string memory _action) {
        if (bids[_bidId].state != BidState.ACCEPTED) {
            revert ActionNotAllowed(_bidId, _action, "Loan must be accepted");
        }
        _;
    }
    uint8 public constant CURRENT_CODE_VERSION = 9;
    uint32 public constant LIQUIDATION_DELAY = 86400; 
    constructor(address trustedForwarder) TellerV2Context(trustedForwarder) {}
    function initialize(
        uint16 _protocolFee,
        address _marketRegistry,
        address _reputationManager,
        address _lenderCommitmentForwarder,
        address _collateralManager,
        address _lenderManager
    ) external initializer {
        __ProtocolFee_init(_protocolFee);
        __Pausable_init();
        require(
            _lenderCommitmentForwarder.isContract(),
            "LenderCommitmentForwarder must be a contract"
        );
        lenderCommitmentForwarder = _lenderCommitmentForwarder;
        require(
            _marketRegistry.isContract(),
            "MarketRegistry must be a contract"
        );
        marketRegistry = IMarketRegistry(_marketRegistry);
        require(
            _reputationManager.isContract(),
            "ReputationManager must be a contract"
        );
        reputationManager = IReputationManager(_reputationManager);
        require(
            _collateralManager.isContract(),
            "CollateralManager must be a contract"
        );
        collateralManager = ICollateralManager(_collateralManager);
        _setLenderManager(_lenderManager);
    }
    function setLenderManager(address _lenderManager)
        external
        reinitializer(8)
        onlyOwner
    {
        _setLenderManager(_lenderManager);
    }
    function _setLenderManager(address _lenderManager)
        internal
        onlyInitializing
    {
        require(
            _lenderManager.isContract(),
            "LenderManager must be a contract"
        );
        lenderManager = ILenderManager(_lenderManager);
    }
    function getMetadataURI(uint256 _bidId)
        public
        view
        returns (string memory metadataURI_)
    {
        metadataURI_ = uris[_bidId];
        if (
            keccak256(abi.encodePacked(metadataURI_)) ==
            0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 
        ) {
            uint256 convertedURI = uint256(bids[_bidId]._metadataURI);
            metadataURI_ = StringsUpgradeable.toHexString(convertedURI, 32);
        }
    }
    function setReputationManager(address _reputationManager) public onlyOwner {
        reputationManager = IReputationManager(_reputationManager);
    }
    function submitBid(
        address _lendingToken,
        uint256 _marketplaceId,
        uint256 _principal,
        uint32 _duration,
        uint16 _APR,
        string calldata _metadataURI,
        address _receiver
    ) public override whenNotPaused returns (uint256 bidId_) {
        bidId_ = _submitBid(
            _lendingToken,
            _marketplaceId,
            _principal,
            _duration,
            _APR,
            _metadataURI,
            _receiver
        );
    }
    function submitBid(
        address _lendingToken,
        uint256 _marketplaceId,
        uint256 _principal,
        uint32 _duration,
        uint16 _APR,
        string calldata _metadataURI,
        address _receiver,
        Collateral[] calldata _collateralInfo
    ) public override whenNotPaused returns (uint256 bidId_) {
        bidId_ = _submitBid(
            _lendingToken,
            _marketplaceId,
            _principal,
            _duration,
            _APR,
            _metadataURI,
            _receiver
        );
        bool validation = collateralManager.commitCollateral(
            bidId_,
            _collateralInfo
        );
        require(
            validation == true,
            "Collateral balance could not be validated"
        );
    }
    function _submitBid(
        address _lendingToken,
        uint256 _marketplaceId,
        uint256 _principal,
        uint32 _duration,
        uint16 _APR,
        string calldata _metadataURI,
        address _receiver
    ) internal virtual returns (uint256 bidId_) {
        address sender = _msgSenderForMarket(_marketplaceId);
        (bool isVerified, ) = marketRegistry.isVerifiedBorrower(
            _marketplaceId,
            sender
        );
        require(isVerified, "Not verified borrower");
        require(
            !marketRegistry.isMarketClosed(_marketplaceId),
            "Market is closed"
        );
        bidId_ = bidId;
        Bid storage bid = bids[bidId];
        bid.borrower = sender;
        bid.receiver = _receiver != address(0) ? _receiver : bid.borrower;
        bid.marketplaceId = _marketplaceId;
        bid.loanDetails.lendingToken = ERC20(_lendingToken);
        bid.loanDetails.principal = _principal;
        bid.loanDetails.loanDuration = _duration;
        bid.loanDetails.timestamp = uint32(block.timestamp);
        (bid.terms.paymentCycle, bidPaymentCycleType[bidId]) = marketRegistry
            .getPaymentCycle(_marketplaceId);
        bid.terms.APR = _APR;
        bidDefaultDuration[bidId] = marketRegistry.getPaymentDefaultDuration(
            _marketplaceId
        );
        bidExpirationTime[bidId] = marketRegistry.getBidExpirationTime(
            _marketplaceId
        );
        bid.paymentType = marketRegistry.getPaymentType(_marketplaceId);
        bid.terms.paymentCycleAmount = V2Calculations
            .calculatePaymentCycleAmount(
                bid.paymentType,
                bidPaymentCycleType[bidId],
                _principal,
                _duration,
                bid.terms.paymentCycle,
                _APR
            );
        uris[bidId] = _metadataURI;
        bid.state = BidState.PENDING;
        emit SubmittedBid(
            bidId,
            bid.borrower,
            bid.receiver,
            keccak256(abi.encodePacked(_metadataURI))
        );
        borrowerBids[bid.borrower].push(bidId);
        bidId++;
    }
    function cancelBid(uint256 _bidId) external {
        if (
            _msgSenderForMarket(bids[_bidId].marketplaceId) !=
            bids[_bidId].borrower
        ) {
            revert ActionNotAllowed({
                bidId: _bidId,
                action: "cancelBid",
                message: "Only the bid owner can cancel!"
            });
        }
        _cancelBid(_bidId);
    }
    function marketOwnerCancelBid(uint256 _bidId) external {
        if (
            _msgSender() !=
            marketRegistry.getMarketOwner(bids[_bidId].marketplaceId)
        ) {
            revert ActionNotAllowed({
                bidId: _bidId,
                action: "marketOwnerCancelBid",
                message: "Only the market owner can cancel!"
            });
        }
        _cancelBid(_bidId);
        emit MarketOwnerCancelledBid(_bidId);
    }
    function _cancelBid(uint256 _bidId)
        internal
        virtual
        pendingBid(_bidId, "cancelBid")
    {
        bids[_bidId].state = BidState.CANCELLED;
        emit CancelledBid(_bidId);
    }
    function lenderAcceptBid(uint256 _bidId)
        external
        override
        pendingBid(_bidId, "lenderAcceptBid")
        whenNotPaused
        returns (
            uint256 amountToProtocol,
            uint256 amountToMarketplace,
            uint256 amountToBorrower
        )
    {
        Bid storage bid = bids[_bidId];
        address sender = _msgSenderForMarket(bid.marketplaceId);
        (bool isVerified, ) = marketRegistry.isVerifiedLender(
            bid.marketplaceId,
            sender
        );
        require(isVerified, "Not verified lender");
        require(
            !marketRegistry.isMarketClosed(bid.marketplaceId),
            "Market is closed"
        );
        require(!isLoanExpired(_bidId), "Bid has expired");
        bid.loanDetails.acceptedTimestamp = uint32(block.timestamp);
        bid.loanDetails.lastRepaidTimestamp = uint32(block.timestamp);
        bid.state = BidState.ACCEPTED;
        bid.lender = sender;
        collateralManager.deployAndDeposit(_bidId);
        amountToProtocol = bid.loanDetails.principal.percent(protocolFee());
        amountToMarketplace = bid.loanDetails.principal.percent(
            marketRegistry.getMarketplaceFee(bid.marketplaceId)
        );
        amountToBorrower =
            bid.loanDetails.principal -
            amountToProtocol -
            amountToMarketplace;
        bid.loanDetails.lendingToken.safeTransferFrom(
            sender,
            owner(),
            amountToProtocol
        );
        bid.loanDetails.lendingToken.safeTransferFrom(
            sender,
            marketRegistry.getMarketFeeRecipient(bid.marketplaceId),
            amountToMarketplace
        );
        bid.loanDetails.lendingToken.safeTransferFrom(
            sender,
            bid.receiver,
            amountToBorrower
        );
        lenderVolumeFilled[address(bid.loanDetails.lendingToken)][sender] += bid
            .loanDetails
            .principal;
        totalVolumeFilled[address(bid.loanDetails.lendingToken)] += bid
            .loanDetails
            .principal;
        _borrowerBidsActive[bid.borrower].add(_bidId);
        emit AcceptedBid(_bidId, sender);
        emit FeePaid(_bidId, "protocol", amountToProtocol);
        emit FeePaid(_bidId, "marketplace", amountToMarketplace);
    }
    function claimLoanNFT(uint256 _bidId)
        external
        acceptedLoan(_bidId, "claimLoanNFT")
        whenNotPaused
    {
        Bid storage bid = bids[_bidId];
        address sender = _msgSenderForMarket(bid.marketplaceId);
        require(sender == bid.lender, "only lender can claim NFT");
        lenderManager.registerLoan(_bidId, sender);
        bid.lender = address(lenderManager);
    }
    function repayLoanMinimum(uint256 _bidId)
        external
        acceptedLoan(_bidId, "repayLoan")
    {
        (
            uint256 owedPrincipal,
            uint256 duePrincipal,
            uint256 interest
        ) = V2Calculations.calculateAmountOwed(
                bids[_bidId],
                block.timestamp,
                bidPaymentCycleType[_bidId]
            );
        _repayLoan(
            _bidId,
            Payment({ principal: duePrincipal, interest: interest }),
            owedPrincipal + interest,
            true
        );
    }
    function repayLoanFull(uint256 _bidId)
        external
        acceptedLoan(_bidId, "repayLoan")
    {
        (uint256 owedPrincipal, , uint256 interest) = V2Calculations
            .calculateAmountOwed(
                bids[_bidId],
                block.timestamp,
                bidPaymentCycleType[_bidId]
            );
        _repayLoan(
            _bidId,
            Payment({ principal: owedPrincipal, interest: interest }),
            owedPrincipal + interest,
            true
        );
    }
    function repayLoan(uint256 _bidId, uint256 _amount)
        external
        acceptedLoan(_bidId, "repayLoan")
    {
        (
            uint256 owedPrincipal,
            uint256 duePrincipal,
            uint256 interest
        ) = V2Calculations.calculateAmountOwed(
                bids[_bidId],
                block.timestamp,
                bidPaymentCycleType[_bidId]
            );
        uint256 minimumOwed = duePrincipal + interest;
        if (_amount < minimumOwed) {
            revert PaymentNotMinimum(_bidId, _amount, minimumOwed);
        }
        _repayLoan(
            _bidId,
            Payment({ principal: _amount - interest, interest: interest }),
            owedPrincipal + interest,
            true
        );
    }
    function pauseProtocol() public virtual onlyOwner whenNotPaused {
        _pause();
    }
    function unpauseProtocol() public virtual onlyOwner whenPaused {
        _unpause();
    }
    function liquidateLoanFull(uint256 _bidId)
        external
        acceptedLoan(_bidId, "liquidateLoan")
    {
        require(isLoanLiquidateable(_bidId), "Loan must be liquidateable.");
        Bid storage bid = bids[_bidId];
        (uint256 owedPrincipal, , uint256 interest) = V2Calculations
            .calculateAmountOwed(
                bid,
                block.timestamp,
                bidPaymentCycleType[_bidId]
            );
        _repayLoan(
            _bidId,
            Payment({ principal: owedPrincipal, interest: interest }),
            owedPrincipal + interest,
            false
        );
        bid.state = BidState.LIQUIDATED;
        address liquidator = _msgSenderForMarket(bid.marketplaceId);
        collateralManager.liquidateCollateral(_bidId, liquidator);
        emit LoanLiquidated(_bidId, liquidator);
    }
    function _repayLoan(
        uint256 _bidId,
        Payment memory _payment,
        uint256 _owedAmount,
        bool _shouldWithdrawCollateral
    ) internal virtual {
        Bid storage bid = bids[_bidId];
        uint256 paymentAmount = _payment.principal + _payment.interest;
        RepMark mark = reputationManager.updateAccountReputation(
            bid.borrower,
            _bidId
        );
        if (paymentAmount >= _owedAmount) {
            paymentAmount = _owedAmount;
            bid.state = BidState.PAID;
            _borrowerBidsActive[bid.borrower].remove(_bidId);
            if (_shouldWithdrawCollateral) {
                collateralManager.withdraw(_bidId);
            }
            emit LoanRepaid(_bidId);
        } else {
            emit LoanRepayment(_bidId);
        }
        address lender = getLoanLender(_bidId);
        bid.loanDetails.lendingToken.safeTransferFrom(
            _msgSenderForMarket(bid.marketplaceId),
            lender,
            paymentAmount
        );
        bid.loanDetails.totalRepaid.principal += _payment.principal;
        bid.loanDetails.totalRepaid.interest += _payment.interest;
        bid.loanDetails.lastRepaidTimestamp = uint32(block.timestamp);
        if (mark != RepMark.Good) {
            reputationManager.updateAccountReputation(bid.borrower, _bidId);
        }
    }
    function calculateAmountOwed(uint256 _bidId)
        public
        view
        returns (Payment memory owed)
    {
        if (bids[_bidId].state != BidState.ACCEPTED) return owed;
        (uint256 owedPrincipal, , uint256 interest) = V2Calculations
            .calculateAmountOwed(
                bids[_bidId],
                block.timestamp,
                bidPaymentCycleType[_bidId]
            );
        owed.principal = owedPrincipal;
        owed.interest = interest;
    }
    function calculateAmountOwed(uint256 _bidId, uint256 _timestamp)
        public
        view
        returns (Payment memory owed)
    {
        Bid storage bid = bids[_bidId];
        if (
            bid.state != BidState.ACCEPTED ||
            bid.loanDetails.acceptedTimestamp >= _timestamp
        ) return owed;
        (uint256 owedPrincipal, , uint256 interest) = V2Calculations
            .calculateAmountOwed(bid, _timestamp, bidPaymentCycleType[_bidId]);
        owed.principal = owedPrincipal;
        owed.interest = interest;
    }
    function calculateAmountDue(uint256 _bidId)
        public
        view
        returns (Payment memory due)
    {
        if (bids[_bidId].state != BidState.ACCEPTED) return due;
        (, uint256 duePrincipal, uint256 interest) = V2Calculations
            .calculateAmountOwed(
                bids[_bidId],
                block.timestamp,
                bidPaymentCycleType[_bidId]
            );
        due.principal = duePrincipal;
        due.interest = interest;
    }
    function calculateAmountDue(uint256 _bidId, uint256 _timestamp)
        public
        view
        returns (Payment memory due)
    {
        Bid storage bid = bids[_bidId];
        if (
            bids[_bidId].state != BidState.ACCEPTED ||
            bid.loanDetails.acceptedTimestamp >= _timestamp
        ) return due;
        (, uint256 duePrincipal, uint256 interest) = V2Calculations
            .calculateAmountOwed(bid, _timestamp, bidPaymentCycleType[_bidId]);
        due.principal = duePrincipal;
        due.interest = interest;
    }
    function calculateNextDueDate(uint256 _bidId)
        public
        view
        returns (uint32 dueDate_)
    {
        Bid storage bid = bids[_bidId];
        if (bids[_bidId].state != BidState.ACCEPTED) return dueDate_;
        uint32 lastRepaidTimestamp = lastRepaidTimestamp(_bidId);
        if (bidPaymentCycleType[_bidId] == PaymentCycleType.Monthly) {
            uint256 lastPaymentCycle = BPBDTL.diffMonths(
                bid.loanDetails.acceptedTimestamp,
                lastRepaidTimestamp
            );
            if (
                BPBDTL.getDay(lastRepaidTimestamp) >
                BPBDTL.getDay(bid.loanDetails.acceptedTimestamp)
            ) {
                lastPaymentCycle += 2;
            } else {
                lastPaymentCycle += 1;
            }
            dueDate_ = uint32(
                BPBDTL.addMonths(
                    bid.loanDetails.acceptedTimestamp,
                    lastPaymentCycle
                )
            );
        } else if (bidPaymentCycleType[_bidId] == PaymentCycleType.Seconds) {
            dueDate_ =
                bid.loanDetails.acceptedTimestamp +
                bid.terms.paymentCycle;
            uint32 delta = lastRepaidTimestamp -
                bid.loanDetails.acceptedTimestamp;
            if (delta > 0) {
                uint32 repaymentCycle = uint32(
                    Math.ceilDiv(delta, bid.terms.paymentCycle)
                );
                dueDate_ += (repaymentCycle * bid.terms.paymentCycle);
            }
        }
        uint32 endOfLoan = bid.loanDetails.acceptedTimestamp +
            bid.loanDetails.loanDuration;
        if (dueDate_ > endOfLoan) {
            dueDate_ = endOfLoan;
        }
    }
    function isPaymentLate(uint256 _bidId) public view override returns (bool) {
        if (bids[_bidId].state != BidState.ACCEPTED) return false;
        return uint32(block.timestamp) > calculateNextDueDate(_bidId);
    }
    function isLoanDefaulted(uint256 _bidId)
        public
        view
        override
        returns (bool)
    {
        return _canLiquidateLoan(_bidId, 0);
    }
    function isLoanLiquidateable(uint256 _bidId)
        public
        view
        override
        returns (bool)
    {
        return _canLiquidateLoan(_bidId, LIQUIDATION_DELAY);
    }
    function _canLiquidateLoan(uint256 _bidId, uint32 _liquidationDelay)
        internal
        view
        returns (bool)
    {
        Bid storage bid = bids[_bidId];
        if (bid.state != BidState.ACCEPTED) return false;
        if (bidDefaultDuration[_bidId] == 0) return false;
        return (uint32(block.timestamp) -
            _liquidationDelay -
            lastRepaidTimestamp(_bidId) >
            bidDefaultDuration[_bidId]);
    }
    function getBidState(uint256 _bidId)
        external
        view
        override
        returns (BidState)
    {
        return bids[_bidId].state;
    }
    function getBorrowerActiveLoanIds(address _borrower)
        external
        view
        override
        returns (uint256[] memory)
    {
        return _borrowerBidsActive[_borrower].values();
    }
    function getBorrowerLoanIds(address _borrower)
        external
        view
        returns (uint256[] memory)
    {
        return borrowerBids[_borrower];
    }
    function isLoanExpired(uint256 _bidId) public view returns (bool) {
        Bid storage bid = bids[_bidId];
        if (bid.state != BidState.PENDING) return false;
        if (bidExpirationTime[_bidId] == 0) return false;
        return (uint32(block.timestamp) >
            bid.loanDetails.timestamp + bidExpirationTime[_bidId]);
    }
    function lastRepaidTimestamp(uint256 _bidId) public view returns (uint32) {
        return V2Calculations.lastRepaidTimestamp(bids[_bidId]);
    }
    function getLoanBorrower(uint256 _bidId)
        public
        view
        returns (address borrower_)
    {
        borrower_ = bids[_bidId].borrower;
    }
    function getLoanLender(uint256 _bidId)
        public
        view
        returns (address lender_)
    {
        lender_ = bids[_bidId].lender;
        if (lender_ == address(lenderManager)) {
            return lenderManager.ownerOf(_bidId);
        }
    }
    function getLoanLendingToken(uint256 _bidId)
        external
        view
        returns (address token_)
    {
        token_ = address(bids[_bidId].loanDetails.lendingToken);
    }
    function getLoanMarketId(uint256 _bidId)
        external
        view
        returns (uint256 _marketId)
    {
        _marketId = bids[_bidId].marketplaceId;
    }
    function getLoanSummary(uint256 _bidId)
        external
        view
        returns (
            address borrower,
            address lender,
            uint256 marketId,
            address principalTokenAddress,
            uint256 principalAmount,
            uint32 acceptedTimestamp,
            BidState bidState
        )
    {
        Bid storage bid = bids[_bidId];
        borrower = bid.borrower;
        lender = bid.lender;
        marketId = bid.marketplaceId;
        principalTokenAddress = address(bid.loanDetails.lendingToken);
        principalAmount = bid.loanDetails.principal;
        acceptedTimestamp = bid.loanDetails.acceptedTimestamp;
        bidState = bid.state;
    }
    function _msgSender()
        internal
        view
        virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (address sender)
    {
        sender = ERC2771ContextUpgradeable._msgSender();
    }
    function _msgData()
        internal
        view
        virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }
}