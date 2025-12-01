pragma solidity 0.8.19;
import "@equilibria/root/control/unstructured/UInitializable.sol";
import "@equilibria/root/control/unstructured/UReentrancyGuard.sol";
import "../controller/UControllerProvider.sol";
import "./UPayoffProvider.sol";
import "./UParamProvider.sol";
import "./types/position/AccountPosition.sol";
import "./types/accumulator/AccountAccumulator.sol";
contract Product is IProduct, UInitializable, UParamProvider, UPayoffProvider, UReentrancyGuard {
    BoolStorage private constant _closed = BoolStorage.wrap(keccak256("equilibria.perennial.Product.closed"));
    function closed() public view returns (bool) {
        return _closed.read();
    }
    string public name;
    string public symbol;
    mapping(address => AccountPosition) private _positions;
    VersionedPosition private _position;
    mapping(address => AccountAccumulator) private _accumulators;
    VersionedAccumulator private _accumulator;
    function initialize(ProductInfo calldata productInfo_) external initializer(1) {
        __UControllerProvider__initialize(IController(msg.sender));
        __UPayoffProvider__initialize(productInfo_.oracle, productInfo_.payoffDefinition);
        __UReentrancyGuard__initialize();
        __UParamProvider__initialize(
            productInfo_.maintenance,
            productInfo_.fundingFee,
            productInfo_.makerFee,
            productInfo_.takerFee,
            productInfo_.positionFee,
            productInfo_.makerLimit,
            productInfo_.utilizationCurve
        );
        name = productInfo_.name;
        symbol = productInfo_.symbol;
    }
    function settle() external nonReentrant notPaused {
        _settle();
    }
    function _settle() private returns (IOracleProvider.OracleVersion memory currentOracleVersion) {
        IController _controller = controller();
        currentOracleVersion = _sync();
        uint256 _latestVersion = latestVersion();
        if (_latestVersion == currentOracleVersion.version) return currentOracleVersion; 
        IOracleProvider.OracleVersion memory latestOracleVersion = atVersion(_latestVersion);
        uint256 _settleVersion = _position.pre.settleVersion(currentOracleVersion.version);
        IOracleProvider.OracleVersion memory settleOracleVersion = _settleVersion == currentOracleVersion.version
            ? currentOracleVersion 
            : atVersion(_settleVersion);
        _controller.incentivizer().sync(currentOracleVersion);
        UFixed18 boundedFundingFee = _boundedFundingFee();
        UFixed18 accumulatedFee = _accumulator.accumulate(
            boundedFundingFee, _position, latestOracleVersion, settleOracleVersion);
        _position.settle(_latestVersion, settleOracleVersion);
        _settleFeeUpdates();
        if (settleOracleVersion.version != currentOracleVersion.version) {
            accumulatedFee = accumulatedFee.add(
                _accumulator.accumulate(boundedFundingFee, _position, settleOracleVersion, currentOracleVersion)
            );
            _position.settle(settleOracleVersion.version, currentOracleVersion);
        }
        _controller.collateral().settleProduct(accumulatedFee);
        emit Settle(settleOracleVersion.version, currentOracleVersion.version);
    }
    function settleAccount(address account) external nonReentrant notPaused {
        IOracleProvider.OracleVersion memory currentOracleVersion = _settle();
        _settleAccount(account, currentOracleVersion);
    }
    function _settleAccount(address account, IOracleProvider.OracleVersion memory currentOracleVersion) private {
        IController _controller = controller();
        if (latestVersion(account) == currentOracleVersion.version) return; 
        uint256 _settleVersion = _positions[account].pre.settleVersion(currentOracleVersion.version);
        IOracleProvider.OracleVersion memory settleOracleVersion = _settleVersion == currentOracleVersion.version
            ? currentOracleVersion 
            : atVersion(_settleVersion);
        _controller.incentivizer().syncAccount(account, settleOracleVersion);
        Fixed18 accumulated = _accumulators[account].syncTo(
            _accumulator, _positions[account], settleOracleVersion.version).sum();
        _positions[account].settle(settleOracleVersion);
        if (settleOracleVersion.version != currentOracleVersion.version) {
            _controller.incentivizer().syncAccount(account, currentOracleVersion);
            accumulated = accumulated.add(
                _accumulators[account].syncTo(_accumulator, _positions[account], currentOracleVersion.version).sum()
            );
        }
        _controller.collateral().settleAccount(account, accumulated);
        emit AccountSettle(account, settleOracleVersion.version, currentOracleVersion.version);
    }
    function openTake(UFixed18 amount) external {
        openTakeFor(msg.sender, amount);
    }
    function openTakeFor(address account, UFixed18 amount)
        public
        nonReentrant
        notPaused
        notClosed
        onlyAccountOrMultiInvoker(account)
        settleForAccount(account)
        maxUtilizationInvariant
        positionInvariant(account)
        liquidationInvariant(account)
        maintenanceInvariant(account)
    {
        IOracleProvider.OracleVersion memory latestOracleVersion = atVersion(latestVersion());
        _positions[account].pre.openTake(latestOracleVersion.version, amount);
        _position.pre.openTake(latestOracleVersion.version, amount);
        UFixed18 positionFee = amount.mul(latestOracleVersion.price.abs()).mul(takerFee());
        if (!positionFee.isZero()) {
            controller().collateral().settleAccount(account, Fixed18Lib.from(-1, positionFee));
            emit PositionFeeCharged(account, latestOracleVersion.version, positionFee);
        }
        emit PositionFeeCharged(account, latestOracleVersion.version, positionFee);
        emit TakeOpened(account, latestOracleVersion.version, amount);
    }
    function closeTake(UFixed18 amount) external {
        closeTakeFor(msg.sender, amount);
    }
    function closeTakeFor(address account, UFixed18 amount)
        public
        nonReentrant
        notPaused
        onlyAccountOrMultiInvoker(account)
        settleForAccount(account)
        closeInvariant(account)
        liquidationInvariant(account)
    {
        _closeTake(account, amount);
    }
    function _closeTake(address account, UFixed18 amount) private {
        IOracleProvider.OracleVersion memory latestOracleVersion = atVersion(latestVersion());
        _positions[account].pre.closeTake(latestOracleVersion.version, amount);
        _position.pre.closeTake(latestOracleVersion.version, amount);
        UFixed18 positionFee = amount.mul(latestOracleVersion.price.abs()).mul(takerFee());
        if (!positionFee.isZero()) {
            controller().collateral().settleAccount(account, Fixed18Lib.from(-1, positionFee));
            emit PositionFeeCharged(account, latestOracleVersion.version, positionFee);
        }
        emit PositionFeeCharged(account, latestOracleVersion.version, positionFee);
        emit TakeClosed(account, latestOracleVersion.version, amount);
    }
    function openMake(UFixed18 amount) external {
        openMakeFor(msg.sender, amount);
    }
    function openMakeFor(address account, UFixed18 amount)
        public
        nonReentrant
        notPaused
        notClosed
        onlyAccountOrMultiInvoker(account)
        settleForAccount(account)
        nonZeroVersionInvariant
        makerInvariant
        positionInvariant(account)
        liquidationInvariant(account)
        maintenanceInvariant(account)
    {
        IOracleProvider.OracleVersion memory latestOracleVersion = atVersion(latestVersion());
        _positions[account].pre.openMake(latestOracleVersion.version, amount);
        _position.pre.openMake(latestOracleVersion.version, amount);
        UFixed18 positionFee = amount.mul(latestOracleVersion.price.abs()).mul(makerFee());
        if (!positionFee.isZero()) {
            controller().collateral().settleAccount(account, Fixed18Lib.from(-1, positionFee));
            emit PositionFeeCharged(account, latestOracleVersion.version, positionFee);
        }
        emit PositionFeeCharged(account, latestOracleVersion.version, positionFee);
        emit MakeOpened(account, latestOracleVersion.version, amount);
    }
    function closeMake(UFixed18 amount) external {
        closeMakeFor(msg.sender, amount);
    }
    function closeMakeFor(address account, UFixed18 amount)
        public
        nonReentrant
        notPaused
        onlyAccountOrMultiInvoker(account)
        settleForAccount(account)
        takerInvariant
        closeInvariant(account)
        liquidationInvariant(account)
    {
        _closeMake(account, amount);
    }
    function _closeMake(address account, UFixed18 amount) private {
        IOracleProvider.OracleVersion memory latestOracleVersion = atVersion(latestVersion());
        _positions[account].pre.closeMake(latestOracleVersion.version, amount);
        _position.pre.closeMake(latestOracleVersion.version, amount);
        UFixed18 positionFee = amount.mul(latestOracleVersion.price.abs()).mul(makerFee());
        if (!positionFee.isZero()) {
            controller().collateral().settleAccount(account, Fixed18Lib.from(-1, positionFee));
            emit PositionFeeCharged(account, latestOracleVersion.version, positionFee);
        }
        emit PositionFeeCharged(account, latestOracleVersion.version, positionFee);
        emit MakeClosed(account, latestOracleVersion.version, amount);
    }
    function closeAll(address account) external onlyCollateral notClosed settleForAccount(account) {
        AccountPosition storage accountPosition = _positions[account];
        Position memory p = accountPosition.position.next(_positions[account].pre);
        _closeMake(account, p.maker);
        _closeTake(account, p.taker);
        accountPosition.liquidation = true;
    }
    function maintenance(address account) external view returns (UFixed18) {
        return _positions[account].maintenance();
    }
    function maintenanceNext(address account) external view returns (UFixed18) {
        return _positions[account].maintenanceNext();
    }
    function isClosed(address account) external view returns (bool) {
        return _positions[account].isClosed();
    }
    function isLiquidating(address account) external view returns (bool) {
        return _positions[account].liquidation;
    }
    function position(address account) external view returns (Position memory) {
        return _positions[account].position;
    }
    function pre(address account) external view returns (PrePosition memory) {
        return _positions[account].pre;
    }
    function latestVersion() public view returns (uint256) {
        return _accumulator.latestVersion;
    }
    function positionAtVersion(uint256 oracleVersion) public view returns (Position memory) {
        return _position.positionAtVersion(oracleVersion);
    }
    function pre() external view returns (PrePosition memory) {
        return _position.pre;
    }
    function valueAtVersion(uint256 oracleVersion) external view returns (Accumulator memory) {
        return _accumulator.valueAtVersion(oracleVersion);
    }
    function shareAtVersion(uint256 oracleVersion) external view returns (Accumulator memory) {
        return _accumulator.shareAtVersion(oracleVersion);
    }
    function latestVersion(address account) public view returns (uint256) {
        return _accumulators[account].latestVersion;
    }
    function rate(Position calldata position_) public view returns (Fixed18) {
        UFixed18 utilization = position_.taker.unsafeDiv(position_.maker);
        Fixed18 annualizedRate = utilizationCurve().compute(utilization);
        return annualizedRate.div(Fixed18Lib.from(365 days));
    }
    function _boundedFundingFee() private view returns (UFixed18) {
        return fundingFee().max(controller().minFundingFee());
    }
    function updateClosed(bool newClosed) external nonReentrant notPaused onlyProductOwner {
        IOracleProvider.OracleVersion memory oracleVersion = _settle();
        _closed.store(newClosed);
        emit ClosedUpdated(newClosed, oracleVersion.version);
    }
    function updateOracle(IOracleProvider newOracle) external onlyProductOwner {
        _updateOracle(address(newOracle), latestVersion());
    }
    modifier makerInvariant() {
        _;
        Position memory next = positionAtVersion(latestVersion()).next(_position.pre);
        if (next.maker.gt(makerLimit())) revert ProductMakerOverLimitError();
    }
    modifier takerInvariant() {
        _;
        if (closed()) return;
        Position memory next = positionAtVersion(latestVersion()).next(_position.pre);
        UFixed18 socializationFactor = next.socializationFactor();
        if (socializationFactor.lt(UFixed18Lib.ONE)) revert ProductInsufficientLiquidityError(socializationFactor);
    }
    modifier maxUtilizationInvariant() {
        _;
        if (closed()) return;
        Position memory next = positionAtVersion(latestVersion()).next(_position.pre);
        UFixed18 utilization = next.taker.unsafeDiv(next.maker);
        if (utilization.gt(UFixed18Lib.ONE.sub(utilizationBuffer())))
            revert ProductInsufficientLiquidityError(utilization);
    }
    modifier positionInvariant(address account) {
        _;
        if (_positions[account].isDoubleSided()) revert ProductDoubleSidedError();
    }
    modifier closeInvariant(address account) {
        _;
        if (_positions[account].isOverClosed()) revert ProductOverClosedError();
    }
    modifier maintenanceInvariant(address account) {
        _;
        if (controller().collateral().liquidatableNext(account, IProduct(this)))
            revert ProductInsufficientCollateralError();
    }
    modifier liquidationInvariant(address account) {
        if (_positions[account].liquidation) revert ProductInLiquidationError();
        _;
    }
    modifier settleForAccount(address account) {
        IOracleProvider.OracleVersion memory _currentVersion = _settle();
        _settleAccount(account, _currentVersion);
        _;
    }
    modifier nonZeroVersionInvariant() {
        if (latestVersion() == 0) revert ProductOracleBootstrappingError();
        _;
    }
    modifier notClosed() {
        if (closed()) revert ProductClosedError();
        _;
    }
}