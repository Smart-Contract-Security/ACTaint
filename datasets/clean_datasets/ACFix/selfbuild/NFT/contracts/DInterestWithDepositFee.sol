pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./libs/DecMath.sol";
import "./moneymarkets/IMoneyMarket.sol";
import "./models/fee/IFeeModel.sol";
import "./models/interest/IInterestModel.sol";
import "./NFT.sol";
import "./rewards/MPHMinter.sol";
import "./models/interest-oracle/IInterestOracle.sol";
contract DInterestWithDepositFee is ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using DecMath for uint256;
    using SafeERC20 for ERC20;
    using Address for address;
    uint256 internal constant PRECISION = 10**18;
    uint256 internal constant ONE = 10**18;
    uint256 internal constant EXTRA_PRECISION = 10**27; 
    struct Deposit {
        uint256 amount; 
        uint256 maturationTimestamp; 
        uint256 interestOwed; 
        uint256 initialMoneyMarketIncomeIndex; 
        bool active; 
        bool finalSurplusIsNegative;
        uint256 finalSurplusAmount; 
        uint256 mintMPHAmount; 
        uint256 depositTimestamp; 
    }
    Deposit[] internal deposits;
    uint256 public latestFundedDepositID; 
    uint256 public unfundedUserDepositAmount; 
    struct Funding {
        uint256 fromDepositID;
        uint256 toDepositID;
        uint256 recordedFundedDepositAmount; 
        uint256 recordedMoneyMarketIncomeIndex; 
        uint256 creationTimestamp; 
    }
    Funding[] internal fundingList;
    uint256
        public sumOfRecordedFundedDepositAndInterestAmountDivRecordedIncomeIndex;
    uint256 public MinDepositPeriod; 
    uint256 public MaxDepositPeriod; 
    uint256 public MinDepositAmount; 
    uint256 public MaxDepositAmount; 
    uint256 public DepositFee; 
    uint256 public totalDeposit;
    uint256 public totalInterestOwed;
    IMoneyMarket public moneyMarket;
    ERC20 public stablecoin;
    IFeeModel public feeModel;
    IInterestModel public interestModel;
    IInterestOracle public interestOracle;
    NFT public depositNFT;
    NFT public fundingNFT;
    MPHMinter public mphMinter;
    event EDeposit(
        address indexed sender,
        uint256 indexed depositID,
        uint256 amount,
        uint256 maturationTimestamp,
        uint256 interestAmount,
        uint256 mintMPHAmount
    );
    event EWithdraw(
        address indexed sender,
        uint256 indexed depositID,
        uint256 indexed fundingID,
        bool early,
        uint256 takeBackMPHAmount
    );
    event EFund(
        address indexed sender,
        uint256 indexed fundingID,
        uint256 deficitAmount
    );
    event ESetParamAddress(
        address indexed sender,
        string indexed paramName,
        address newValue
    );
    event ESetParamUint(
        address indexed sender,
        string indexed paramName,
        uint256 newValue
    );
    struct DepositLimit {
        uint256 MinDepositPeriod;
        uint256 MaxDepositPeriod;
        uint256 MinDepositAmount;
        uint256 MaxDepositAmount;
        uint256 DepositFee;
    }
    constructor(
        DepositLimit memory _depositLimit,
        address _moneyMarket, 
        address _stablecoin, 
        address _feeModel, 
        address _interestModel, 
        address _interestOracle, 
        address _depositNFT, 
        address _fundingNFT, 
        address _mphMinter 
    ) public {
        require(
            _moneyMarket.isContract() &&
                _stablecoin.isContract() &&
                _feeModel.isContract() &&
                _interestModel.isContract() &&
                _interestOracle.isContract() &&
                _depositNFT.isContract() &&
                _fundingNFT.isContract() &&
                _mphMinter.isContract(),
            "DInterest: An input address is not a contract"
        );
        moneyMarket = IMoneyMarket(_moneyMarket);
        stablecoin = ERC20(_stablecoin);
        feeModel = IFeeModel(_feeModel);
        interestModel = IInterestModel(_interestModel);
        interestOracle = IInterestOracle(_interestOracle);
        depositNFT = NFT(_depositNFT);
        fundingNFT = NFT(_fundingNFT);
        mphMinter = MPHMinter(_mphMinter);
        require(
            moneyMarket.stablecoin() == _stablecoin,
            "DInterest: moneyMarket.stablecoin() != _stablecoin"
        );
        require(
            interestOracle.moneyMarket() == _moneyMarket,
            "DInterest: interestOracle.moneyMarket() != _moneyMarket"
        );
        require(
            _depositLimit.MaxDepositPeriod > 0 &&
                _depositLimit.MaxDepositAmount > 0,
            "DInterest: An input uint256 is 0"
        );
        require(
            _depositLimit.MinDepositPeriod <= _depositLimit.MaxDepositPeriod,
            "DInterest: Invalid DepositPeriod range"
        );
        require(
            _depositLimit.MinDepositAmount <= _depositLimit.MaxDepositAmount,
            "DInterest: Invalid DepositAmount range"
        );
        MinDepositPeriod = _depositLimit.MinDepositPeriod;
        MaxDepositPeriod = _depositLimit.MaxDepositPeriod;
        MinDepositAmount = _depositLimit.MinDepositAmount;
        MaxDepositAmount = _depositLimit.MaxDepositAmount;
        DepositFee = _depositLimit.DepositFee;
        totalDeposit = 0;
    }
    function deposit(uint256 amount, uint256 maturationTimestamp)
        external
        nonReentrant
    {
        _deposit(amount, maturationTimestamp);
    }
    function withdraw(uint256 depositID, uint256 fundingID)
        external
        nonReentrant
    {
        _withdraw(depositID, fundingID, false);
    }
    function earlyWithdraw(uint256 depositID, uint256 fundingID)
        external
        nonReentrant
    {
        _withdraw(depositID, fundingID, true);
    }
    function multiDeposit(
        uint256[] calldata amountList,
        uint256[] calldata maturationTimestampList
    ) external nonReentrant {
        require(
            amountList.length == maturationTimestampList.length,
            "DInterest: List lengths unequal"
        );
        for (uint256 i = 0; i < amountList.length; i = i.add(1)) {
            _deposit(amountList[i], maturationTimestampList[i]);
        }
    }
    function multiWithdraw(
        uint256[] calldata depositIDList,
        uint256[] calldata fundingIDList
    ) external nonReentrant {
        require(
            depositIDList.length == fundingIDList.length,
            "DInterest: List lengths unequal"
        );
        for (uint256 i = 0; i < depositIDList.length; i = i.add(1)) {
            _withdraw(depositIDList[i], fundingIDList[i], false);
        }
    }
    function multiEarlyWithdraw(
        uint256[] calldata depositIDList,
        uint256[] calldata fundingIDList
    ) external nonReentrant {
        require(
            depositIDList.length == fundingIDList.length,
            "DInterest: List lengths unequal"
        );
        for (uint256 i = 0; i < depositIDList.length; i = i.add(1)) {
            _withdraw(depositIDList[i], fundingIDList[i], true);
        }
    }
    function fundAll() external nonReentrant {
        (bool isNegative, uint256 deficit) = surplus();
        require(isNegative, "DInterest: No deficit available");
        require(
            !depositIsFunded(deposits.length),
            "DInterest: All deposits funded"
        );
        uint256 incomeIndex = moneyMarket.incomeIndex();
        require(incomeIndex > 0, "DInterest: incomeIndex == 0");
        fundingList.push(
            Funding({
                fromDepositID: latestFundedDepositID,
                toDepositID: deposits.length,
                recordedFundedDepositAmount: unfundedUserDepositAmount,
                recordedMoneyMarketIncomeIndex: incomeIndex,
                creationTimestamp: now
            })
        );
        sumOfRecordedFundedDepositAndInterestAmountDivRecordedIncomeIndex = sumOfRecordedFundedDepositAndInterestAmountDivRecordedIncomeIndex
            .add(
            unfundedUserDepositAmount.mul(EXTRA_PRECISION).div(incomeIndex)
        );
        latestFundedDepositID = deposits.length;
        unfundedUserDepositAmount = 0;
        _fund(deficit);
    }
    function fundMultiple(uint256 toDepositID) external nonReentrant {
        require(
            toDepositID > latestFundedDepositID,
            "DInterest: Deposits already funded"
        );
        require(
            toDepositID <= deposits.length,
            "DInterest: Invalid toDepositID"
        );
        (bool isNegative, uint256 surplus) = surplus();
        require(isNegative, "DInterest: No deficit available");
        uint256 totalDeficit = 0;
        uint256 totalSurplus = 0;
        uint256 totalDepositAndInterestToFund = 0;
        for (
            uint256 id = latestFundedDepositID.add(1);
            id <= toDepositID;
            id = id.add(1)
        ) {
            Deposit storage depositEntry = _getDeposit(id);
            if (depositEntry.active) {
                (isNegative, surplus) = surplusOfDeposit(id);
            } else {
                (isNegative, surplus) = (
                    depositEntry.finalSurplusIsNegative,
                    depositEntry.finalSurplusAmount
                );
            }
            if (isNegative) {
                totalDeficit = totalDeficit.add(surplus);
            } else {
                totalSurplus = totalSurplus.add(surplus);
            }
            if (depositEntry.active) {
                totalDepositAndInterestToFund = totalDepositAndInterestToFund
                    .add(depositEntry.amount)
                    .add(depositEntry.interestOwed);
            }
        }
        if (totalSurplus >= totalDeficit) {
            revert("DInterest: Selected deposits in surplus");
        } else {
            totalDeficit = totalDeficit.sub(totalSurplus);
        }
        uint256 incomeIndex = moneyMarket.incomeIndex();
        require(incomeIndex > 0, "DInterest: incomeIndex == 0");
        fundingList.push(
            Funding({
                fromDepositID: latestFundedDepositID,
                toDepositID: toDepositID,
                recordedFundedDepositAmount: totalDepositAndInterestToFund,
                recordedMoneyMarketIncomeIndex: incomeIndex,
                creationTimestamp: now
            })
        );
        sumOfRecordedFundedDepositAndInterestAmountDivRecordedIncomeIndex = sumOfRecordedFundedDepositAndInterestAmountDivRecordedIncomeIndex
            .add(
            totalDepositAndInterestToFund.mul(EXTRA_PRECISION).div(incomeIndex)
        );
        latestFundedDepositID = toDepositID;
        unfundedUserDepositAmount = unfundedUserDepositAmount.sub(
            totalDepositAndInterestToFund
        );
        _fund(totalDeficit);
    }
    function payInterestToFunder(uint256 fundingID)
        external
        returns (uint256 interestAmount)
    {
        address funder = fundingNFT.ownerOf(fundingID);
        require(funder == msg.sender, "DInterest: not funder");
        Funding storage f = _getFunding(fundingID);
        uint256 currentMoneyMarketIncomeIndex = moneyMarket.incomeIndex();
        interestAmount = f
            .recordedFundedDepositAmount
            .mul(currentMoneyMarketIncomeIndex)
            .div(f.recordedMoneyMarketIncomeIndex)
            .sub(f.recordedFundedDepositAmount);
        sumOfRecordedFundedDepositAndInterestAmountDivRecordedIncomeIndex = sumOfRecordedFundedDepositAndInterestAmountDivRecordedIncomeIndex
            .sub(
            f.recordedFundedDepositAmount.mul(EXTRA_PRECISION).div(
                f.recordedMoneyMarketIncomeIndex
            )
        );
        f.recordedMoneyMarketIncomeIndex = currentMoneyMarketIncomeIndex;
        sumOfRecordedFundedDepositAndInterestAmountDivRecordedIncomeIndex = sumOfRecordedFundedDepositAndInterestAmountDivRecordedIncomeIndex
            .add(
            f.recordedFundedDepositAmount.mul(EXTRA_PRECISION).div(
                f.recordedMoneyMarketIncomeIndex
            )
        );
        if (interestAmount > 0) {
            interestAmount = moneyMarket.withdraw(interestAmount);
            if (interestAmount > 0) {
                stablecoin.safeTransfer(funder, interestAmount);
            }
        }
    }
    function calculateInterestAmount(
        uint256 depositAmount,
        uint256 depositPeriodInSeconds
    ) public returns (uint256 interestAmount) {
        (, uint256 moneyMarketInterestRatePerSecond) =
            interestOracle.updateAndQuery();
        (bool surplusIsNegative, uint256 surplusAmount) = surplus();
        return
            interestModel.calculateInterestAmount(
                depositAmount,
                depositPeriodInSeconds,
                moneyMarketInterestRatePerSecond,
                surplusIsNegative,
                surplusAmount
            );
    }
    function totalInterestOwedToFunders()
        public
        returns (uint256 interestOwed)
    {
        uint256 currentValue =
            moneyMarket
                .incomeIndex()
                .mul(
                sumOfRecordedFundedDepositAndInterestAmountDivRecordedIncomeIndex
            )
                .div(EXTRA_PRECISION);
        uint256 initialValue =
            totalDeposit.add(totalInterestOwed).sub(unfundedUserDepositAmount);
        if (currentValue < initialValue) {
            return 0;
        }
        return currentValue.sub(initialValue);
    }
    function surplus() public returns (bool isNegative, uint256 surplusAmount) {
        uint256 totalValue = moneyMarket.totalValue();
        uint256 totalOwed =
            totalDeposit.add(totalInterestOwed).add(
                totalInterestOwedToFunders()
            );
        if (totalValue >= totalOwed) {
            isNegative = false;
            surplusAmount = totalValue.sub(totalOwed);
        } else {
            isNegative = true;
            surplusAmount = totalOwed.sub(totalValue);
        }
    }
    function surplusOfDeposit(uint256 depositID)
        public
        returns (bool isNegative, uint256 surplusAmount)
    {
        Deposit storage depositEntry = _getDeposit(depositID);
        uint256 currentMoneyMarketIncomeIndex = moneyMarket.incomeIndex();
        uint256 currentDepositValue =
            depositEntry.amount.mul(currentMoneyMarketIncomeIndex).div(
                depositEntry.initialMoneyMarketIncomeIndex
            );
        uint256 owed = depositEntry.amount.add(depositEntry.interestOwed);
        if (currentDepositValue >= owed) {
            isNegative = false;
            surplusAmount = currentDepositValue.sub(owed);
        } else {
            isNegative = true;
            surplusAmount = owed.sub(currentDepositValue);
        }
    }
    function depositIsFunded(uint256 id) public view returns (bool) {
        return (id <= latestFundedDepositID);
    }
    function depositsLength() external view returns (uint256) {
        return deposits.length;
    }
    function fundingListLength() external view returns (uint256) {
        return fundingList.length;
    }
    function getDeposit(uint256 depositID)
        external
        view
        returns (Deposit memory)
    {
        return deposits[depositID.sub(1)];
    }
    function getFunding(uint256 fundingID)
        external
        view
        returns (Funding memory)
    {
        return fundingList[fundingID.sub(1)];
    }
    function moneyMarketIncomeIndex() external returns (uint256) {
        return moneyMarket.incomeIndex();
    }
    function setFeeModel(address newValue) external onlyOwner {
        require(newValue.isContract(), "DInterest: not contract");
        feeModel = IFeeModel(newValue);
        emit ESetParamAddress(msg.sender, "feeModel", newValue);
    }
    function setInterestModel(address newValue) external onlyOwner {
        require(newValue.isContract(), "DInterest: not contract");
        interestModel = IInterestModel(newValue);
        emit ESetParamAddress(msg.sender, "interestModel", newValue);
    }
    function setInterestOracle(address newValue) external onlyOwner {
        require(newValue.isContract(), "DInterest: not contract");
        interestOracle = IInterestOracle(newValue);
        require(
            interestOracle.moneyMarket() == address(moneyMarket),
            "DInterest: moneyMarket mismatch"
        );
        emit ESetParamAddress(msg.sender, "interestOracle", newValue);
    }
    function setRewards(address newValue) external onlyOwner {
        require(newValue.isContract(), "DInterest: not contract");
        moneyMarket.setRewards(newValue);
        emit ESetParamAddress(msg.sender, "moneyMarket.rewards", newValue);
    }
    function setMPHMinter(address newValue) external onlyOwner {
        require(newValue.isContract(), "DInterest: not contract");
        mphMinter = MPHMinter(newValue);
        emit ESetParamAddress(msg.sender, "mphMinter", newValue);
    }
    function setMinDepositPeriod(uint256 newValue) external onlyOwner {
        require(newValue <= MaxDepositPeriod, "DInterest: invalid value");
        MinDepositPeriod = newValue;
        emit ESetParamUint(msg.sender, "MinDepositPeriod", newValue);
    }
    function setMaxDepositPeriod(uint256 newValue) external onlyOwner {
        require(
            newValue >= MinDepositPeriod && newValue > 0,
            "DInterest: invalid value"
        );
        MaxDepositPeriod = newValue;
        emit ESetParamUint(msg.sender, "MaxDepositPeriod", newValue);
    }
    function setMinDepositAmount(uint256 newValue) external onlyOwner {
        require(
            newValue <= MaxDepositAmount && newValue > 0,
            "DInterest: invalid value"
        );
        MinDepositAmount = newValue;
        emit ESetParamUint(msg.sender, "MinDepositAmount", newValue);
    }
    function setMaxDepositAmount(uint256 newValue) external onlyOwner {
        require(
            newValue >= MinDepositAmount && newValue > 0,
            "DInterest: invalid value"
        );
        MaxDepositAmount = newValue;
        emit ESetParamUint(msg.sender, "MaxDepositAmount", newValue);
    }
    function setDepositFee(uint256 newValue) external onlyOwner {
        require(
            newValue < PRECISION,
            "DInterest: invalid value"
        );
        DepositFee = newValue;
        emit ESetParamUint(msg.sender, "DepositFee", newValue);
    }
    function setDepositNFTTokenURI(uint256 tokenId, string calldata newURI)
        external
        onlyOwner
    {
        depositNFT.setTokenURI(tokenId, newURI);
    }
    function setDepositNFTBaseURI(string calldata newURI) external onlyOwner {
        depositNFT.setBaseURI(newURI);
    }
    function setDepositNFTContractURI(string calldata newURI)
        external
        onlyOwner
    {
        depositNFT.setContractURI(newURI);
    }
    function setFundingNFTTokenURI(uint256 tokenId, string calldata newURI)
        external
        onlyOwner
    {
        fundingNFT.setTokenURI(tokenId, newURI);
    }
    function setFundingNFTBaseURI(string calldata newURI) external onlyOwner {
        fundingNFT.setBaseURI(newURI);
    }
    function setFundingNFTContractURI(string calldata newURI)
        external
        onlyOwner
    {
        fundingNFT.setContractURI(newURI);
    }
    function _getDeposit(uint256 depositID)
        internal
        view
        returns (Deposit storage)
    {
        return deposits[depositID.sub(1)];
    }
    function _getFunding(uint256 fundingID)
        internal
        view
        returns (Funding storage)
    {
        return fundingList[fundingID.sub(1)];
    }
    function _applyDepositFee(uint256 depositAmount)
        internal
        view
        returns (uint256)
    {
        return depositAmount.decmul(PRECISION.sub(DepositFee));
    }
    function _unapplyDepositFee(uint256 depositAmount)
        internal
        view
        returns (uint256)
    {
        return depositAmount.decdiv(PRECISION.sub(DepositFee));
    }
    function _deposit(uint256 amount, uint256 maturationTimestamp) internal {
        require(
            amount >= MinDepositAmount && amount <= MaxDepositAmount,
            "DInterest: Deposit amount out of range"
        );
        uint256 depositPeriod = maturationTimestamp.sub(now);
        require(
            depositPeriod >= MinDepositPeriod &&
                depositPeriod <= MaxDepositPeriod,
            "DInterest: Deposit period out of range"
        );
        uint256 amountAfterFee = _applyDepositFee(amount);
        totalDeposit = totalDeposit.add(amountAfterFee);
        uint256 interestAmount = calculateInterestAmount(amountAfterFee, depositPeriod);
        require(interestAmount > 0, "DInterest: interestAmount == 0");
        uint256 id = deposits.length.add(1);
        unfundedUserDepositAmount = unfundedUserDepositAmount.add(amountAfterFee).add(
            interestAmount
        );
        totalInterestOwed = totalInterestOwed.add(interestAmount);
        uint256 mintMPHAmount =
            mphMinter.mintDepositorReward(
                msg.sender,
                amountAfterFee,
                depositPeriod,
                interestAmount
            );
        deposits.push(
            Deposit({
                amount: amountAfterFee,
                maturationTimestamp: maturationTimestamp,
                interestOwed: interestAmount,
                initialMoneyMarketIncomeIndex: moneyMarket.incomeIndex(),
                active: true,
                finalSurplusIsNegative: false,
                finalSurplusAmount: 0,
                mintMPHAmount: mintMPHAmount,
                depositTimestamp: now
            })
        );
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);
        stablecoin.safeIncreaseAllowance(address(moneyMarket), amount);
        moneyMarket.deposit(amount);
        depositNFT.mint(msg.sender, id);
        emit EDeposit(
            msg.sender,
            id,
            amountAfterFee,
            maturationTimestamp,
            interestAmount,
            mintMPHAmount
        );
    }
    function _withdraw(
        uint256 depositID,
        uint256 fundingID,
        bool early
    ) internal {
        Deposit storage depositEntry = _getDeposit(depositID);
        require(depositEntry.active, "DInterest: Deposit not active");
        depositEntry.active = false;
        if (early) {
            require(
                now < depositEntry.maturationTimestamp,
                "DInterest: Deposit mature, use withdraw() instead"
            );
            require(
                now > depositEntry.depositTimestamp,
                "DInterest: Deposited in same block"
            );
        } else {
            require(
                now >= depositEntry.maturationTimestamp,
                "DInterest: Deposit not mature"
            );
        }
        require(
            depositNFT.ownerOf(depositID) == msg.sender,
            "DInterest: Sender doesn't own depositNFT"
        );
        {
            uint256 takeBackMPHAmount =
                mphMinter.takeBackDepositorReward(
                    msg.sender,
                    depositEntry.mintMPHAmount,
                    early
                );
            emit EWithdraw(
                msg.sender,
                depositID,
                fundingID,
                early,
                takeBackMPHAmount
            );
        }
        totalDeposit = totalDeposit.sub(depositEntry.amount);
        totalInterestOwed = totalInterestOwed.sub(depositEntry.interestOwed);
        uint256 currentMoneyMarketIncomeIndex = moneyMarket.incomeIndex();
        require(
            currentMoneyMarketIncomeIndex > 0,
            "DInterest: currentMoneyMarketIncomeIndex == 0"
        );
        (bool depositSurplusIsNegative, uint256 depositSurplus) =
            surplusOfDeposit(depositID);
        {
            uint256 feeAmount;
            uint256 withdrawAmount;
            if (early) {
                withdrawAmount = depositEntry.amount;
            } else {
                feeAmount = feeModel.getFee(depositEntry.interestOwed);
                withdrawAmount = depositEntry.amount.add(
                    depositEntry.interestOwed
                );
            }
            withdrawAmount = moneyMarket.withdraw(withdrawAmount);
            stablecoin.safeTransfer(msg.sender, withdrawAmount.sub(feeAmount));
            if (feeAmount > 0) {
                stablecoin.safeTransfer(feeModel.beneficiary(), feeAmount);
            }
        }
        if (depositIsFunded(depositID)) {
            _payInterestToFunder(
                fundingID,
                depositID,
                depositEntry.amount,
                depositEntry.maturationTimestamp,
                depositEntry.interestOwed,
                depositSurplusIsNegative,
                depositSurplus,
                currentMoneyMarketIncomeIndex,
                early
            );
        } else {
            unfundedUserDepositAmount = unfundedUserDepositAmount.sub(
                depositEntry.amount.add(depositEntry.interestOwed)
            );
            depositEntry.finalSurplusIsNegative = depositSurplusIsNegative;
            depositEntry.finalSurplusAmount = depositSurplus;
        }
    }
    function _payInterestToFunder(
        uint256 fundingID,
        uint256 depositID,
        uint256 depositAmount,
        uint256 depositMaturationTimestamp,
        uint256 depositInterestOwed,
        bool depositSurplusIsNegative,
        uint256 depositSurplus,
        uint256 currentMoneyMarketIncomeIndex,
        bool early
    ) internal {
        Funding storage f = _getFunding(fundingID);
        require(
            depositID > f.fromDepositID && depositID <= f.toDepositID,
            "DInterest: Deposit not funded by fundingID"
        );
        uint256 interestAmount =
            f
                .recordedFundedDepositAmount
                .mul(currentMoneyMarketIncomeIndex)
                .div(f.recordedMoneyMarketIncomeIndex)
                .sub(f.recordedFundedDepositAmount);
        sumOfRecordedFundedDepositAndInterestAmountDivRecordedIncomeIndex = sumOfRecordedFundedDepositAndInterestAmountDivRecordedIncomeIndex
            .sub(
            f.recordedFundedDepositAmount.mul(EXTRA_PRECISION).div(
                f.recordedMoneyMarketIncomeIndex
            )
        );
        f.recordedFundedDepositAmount = f.recordedFundedDepositAmount.sub(
            depositAmount.add(depositInterestOwed)
        );
        f.recordedMoneyMarketIncomeIndex = currentMoneyMarketIncomeIndex;
        sumOfRecordedFundedDepositAndInterestAmountDivRecordedIncomeIndex = sumOfRecordedFundedDepositAndInterestAmountDivRecordedIncomeIndex
            .add(
            f.recordedFundedDepositAmount.mul(EXTRA_PRECISION).div(
                f.recordedMoneyMarketIncomeIndex
            )
        );
        address funder = fundingNFT.ownerOf(fundingID);
        uint256 transferToFunderAmount =
            (early && depositSurplusIsNegative)
                ? interestAmount.add(depositSurplus)
                : interestAmount;
        if (transferToFunderAmount > 0) {
            transferToFunderAmount = moneyMarket.withdraw(
                transferToFunderAmount
            );
            if (transferToFunderAmount > 0) {
                stablecoin.safeTransfer(funder, transferToFunderAmount);
            }
        }
        mphMinter.mintFunderReward(
            funder,
            depositAmount,
            f.creationTimestamp,
            depositMaturationTimestamp,
            interestAmount,
            early
        );
    }
    function _fund(uint256 totalDeficit) internal {
        uint256 deficitWithFee = _unapplyDepositFee(totalDeficit);
        stablecoin.safeTransferFrom(msg.sender, address(this), deficitWithFee);
        stablecoin.safeIncreaseAllowance(address(moneyMarket), deficitWithFee);
        moneyMarket.deposit(deficitWithFee);
        fundingNFT.mint(msg.sender, fundingList.length);
        uint256 fundingID = fundingList.length;
        emit EFund(msg.sender, fundingID, deficitWithFee);
    }
}