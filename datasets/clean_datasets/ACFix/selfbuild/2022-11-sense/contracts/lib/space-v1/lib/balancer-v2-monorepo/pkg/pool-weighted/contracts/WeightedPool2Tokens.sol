pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/InputHelpers.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/LogCompression.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/TemporarilyPausable.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/ERC20.sol";
import "@balancer-labs/v2-vault/contracts/interfaces/IMinimalSwapInfoPool.sol";
import "@balancer-labs/v2-pool-utils/contracts/BasePoolAuthorization.sol";
import "@balancer-labs/v2-pool-utils/contracts/BalancerPoolToken.sol";
import "@balancer-labs/v2-pool-utils/contracts/oracle/PoolPriceOracle.sol";
import "@balancer-labs/v2-pool-utils/contracts/oracle/Buffer.sol";
import "./WeightedMath.sol";
import "./WeightedOracleMath.sol";
import "./WeightedPoolUserDataHelpers.sol";
import "./WeightedPool2TokensMiscData.sol";
contract WeightedPool2Tokens is
    IMinimalSwapInfoPool,
    BasePoolAuthorization,
    BalancerPoolToken,
    TemporarilyPausable,
    PoolPriceOracle,
    WeightedMath,
    WeightedOracleMath
{
    using FixedPoint for uint256;
    using WeightedPoolUserDataHelpers for bytes;
    using WeightedPool2TokensMiscData for bytes32;
    uint256 private constant _MINIMUM_BPT = 1e6;
    uint256 private constant _MIN_SWAP_FEE_PERCENTAGE = 1e12; 
    uint256 private constant _MAX_SWAP_FEE_PERCENTAGE = 1e17; 
    bytes32 internal _miscData;
    uint256 private _lastInvariant;
    IVault private immutable _vault;
    bytes32 private immutable _poolId;
    IERC20 internal immutable _token0;
    IERC20 internal immutable _token1;
    uint256 private immutable _normalizedWeight0;
    uint256 private immutable _normalizedWeight1;
    uint256 private immutable _maxWeightTokenIndex;
    uint256 internal immutable _scalingFactor0;
    uint256 internal immutable _scalingFactor1;
    event OracleEnabledChanged(bool enabled);
    event SwapFeePercentageChanged(uint256 swapFeePercentage);
    modifier onlyVault(bytes32 poolId) {
        _require(msg.sender == address(getVault()), Errors.CALLER_NOT_VAULT);
        _require(poolId == getPoolId(), Errors.INVALID_POOL_ID);
        _;
    }
    struct NewPoolParams {
        IVault vault;
        string name;
        string symbol;
        IERC20 token0;
        IERC20 token1;
        uint256 normalizedWeight0;
        uint256 normalizedWeight1;
        uint256 swapFeePercentage;
        uint256 pauseWindowDuration;
        uint256 bufferPeriodDuration;
        bool oracleEnabled;
        address owner;
    }
    constructor(NewPoolParams memory params)
        Authentication(bytes32(uint256(msg.sender)))
        BalancerPoolToken(params.name, params.symbol)
        BasePoolAuthorization(params.owner)
        TemporarilyPausable(params.pauseWindowDuration, params.bufferPeriodDuration)
    {
        _setOracleEnabled(params.oracleEnabled);
        _setSwapFeePercentage(params.swapFeePercentage);
        bytes32 poolId = params.vault.registerPool(IVault.PoolSpecialization.TWO_TOKEN);
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = params.token0;
        tokens[1] = params.token1;
        params.vault.registerTokens(poolId, tokens, new address[](2));
        _vault = params.vault;
        _poolId = poolId;
        _token0 = params.token0;
        _token1 = params.token1;
        _scalingFactor0 = _computeScalingFactor(params.token0);
        _scalingFactor1 = _computeScalingFactor(params.token1);
        _require(params.normalizedWeight0 >= _MIN_WEIGHT, Errors.MIN_WEIGHT);
        _require(params.normalizedWeight1 >= _MIN_WEIGHT, Errors.MIN_WEIGHT);
        uint256 normalizedSum = params.normalizedWeight0.add(params.normalizedWeight1);
        _require(normalizedSum == FixedPoint.ONE, Errors.NORMALIZED_WEIGHT_INVARIANT);
        _normalizedWeight0 = params.normalizedWeight0;
        _normalizedWeight1 = params.normalizedWeight1;
        _maxWeightTokenIndex = params.normalizedWeight0 >= params.normalizedWeight1 ? 0 : 1;
    }
    function getVault() public view returns (IVault) {
        return _vault;
    }
    function getPoolId() public view override returns (bytes32) {
        return _poolId;
    }
    function getMiscData()
        external
        view
        returns (
            int256 logInvariant,
            int256 logTotalSupply,
            uint256 oracleSampleCreationTimestamp,
            uint256 oracleIndex,
            bool oracleEnabled,
            uint256 swapFeePercentage
        )
    {
        bytes32 miscData = _miscData;
        logInvariant = miscData.logInvariant();
        logTotalSupply = miscData.logTotalSupply();
        oracleSampleCreationTimestamp = miscData.oracleSampleCreationTimestamp();
        oracleIndex = miscData.oracleIndex();
        oracleEnabled = miscData.oracleEnabled();
        swapFeePercentage = miscData.swapFeePercentage();
    }
    function getSwapFeePercentage() public view returns (uint256) {
        return _miscData.swapFeePercentage();
    }
    function setSwapFeePercentage(uint256 swapFeePercentage) public virtual authenticate whenNotPaused {
        _setSwapFeePercentage(swapFeePercentage);
    }
    function _setSwapFeePercentage(uint256 swapFeePercentage) private {
        _require(swapFeePercentage >= _MIN_SWAP_FEE_PERCENTAGE, Errors.MIN_SWAP_FEE_PERCENTAGE);
        _require(swapFeePercentage <= _MAX_SWAP_FEE_PERCENTAGE, Errors.MAX_SWAP_FEE_PERCENTAGE);
        _miscData = _miscData.setSwapFeePercentage(swapFeePercentage);
        emit SwapFeePercentageChanged(swapFeePercentage);
    }
    function _isOwnerOnlyAction(bytes32 actionId) internal view virtual override returns (bool) {
        return
            (actionId == getActionId(BasePool.setSwapFeePercentage.selector)) ||
            (actionId == getActionId(BasePool.setAssetManagerPoolConfig.selector));
    }
    function enableOracle() external whenNotPaused authenticate {
        _setOracleEnabled(true);
        if (totalSupply() > 0) {
            _cacheInvariantAndSupply();
        }
    }
    function _setOracleEnabled(bool enabled) internal {
        _miscData = _miscData.setOracleEnabled(enabled);
        emit OracleEnabledChanged(enabled);
    }
    function setPaused(bool paused) external authenticate {
        _setPaused(paused);
    }
    function getNormalizedWeights() external view returns (uint256[] memory) {
        return _normalizedWeights();
    }
    function _normalizedWeights() internal view virtual returns (uint256[] memory) {
        uint256[] memory normalizedWeights = new uint256[](2);
        normalizedWeights[0] = _normalizedWeights(true);
        normalizedWeights[1] = _normalizedWeights(false);
        return normalizedWeights;
    }
    function _normalizedWeights(bool token0) internal view virtual returns (uint256) {
        return token0 ? _normalizedWeight0 : _normalizedWeight1;
    }
    function getLastInvariant() external view returns (uint256) {
        return _lastInvariant;
    }
    function getInvariant() public view returns (uint256) {
        (, uint256[] memory balances, ) = getVault().getPoolTokens(getPoolId());
        _upscaleArray(balances);
        uint256[] memory normalizedWeights = _normalizedWeights();
        return WeightedMath._calculateInvariant(normalizedWeights, balances);
    }
    function onSwap(
        SwapRequest memory request,
        uint256 balanceTokenIn,
        uint256 balanceTokenOut
    ) public virtual override whenNotPaused onlyVault(request.poolId) returns (uint256) {
        bool tokenInIsToken0 = request.tokenIn == _token0;
        uint256 scalingFactorTokenIn = _scalingFactor(tokenInIsToken0);
        uint256 scalingFactorTokenOut = _scalingFactor(!tokenInIsToken0);
        uint256 normalizedWeightIn = _normalizedWeights(tokenInIsToken0);
        uint256 normalizedWeightOut = _normalizedWeights(!tokenInIsToken0);
        balanceTokenIn = _upscale(balanceTokenIn, scalingFactorTokenIn);
        balanceTokenOut = _upscale(balanceTokenOut, scalingFactorTokenOut);
        _updateOracle(
            request.lastChangeBlock,
            tokenInIsToken0 ? balanceTokenIn : balanceTokenOut,
            tokenInIsToken0 ? balanceTokenOut : balanceTokenIn
        );
        if (request.kind == IVault.SwapKind.GIVEN_IN) {
            uint256 feeAmount = request.amount.mulUp(getSwapFeePercentage());
            request.amount = _upscale(request.amount.sub(feeAmount), scalingFactorTokenIn);
            uint256 amountOut = _onSwapGivenIn(
                request,
                balanceTokenIn,
                balanceTokenOut,
                normalizedWeightIn,
                normalizedWeightOut
            );
            return _downscaleDown(amountOut, scalingFactorTokenOut);
        } else {
            request.amount = _upscale(request.amount, scalingFactorTokenOut);
            uint256 amountIn = _onSwapGivenOut(
                request,
                balanceTokenIn,
                balanceTokenOut,
                normalizedWeightIn,
                normalizedWeightOut
            );
            amountIn = _downscaleUp(amountIn, scalingFactorTokenIn);
            return amountIn.divUp(getSwapFeePercentage().complement());
        }
    }
    function _onSwapGivenIn(
        SwapRequest memory swapRequest,
        uint256 currentBalanceTokenIn,
        uint256 currentBalanceTokenOut,
        uint256 normalizedWeightIn,
        uint256 normalizedWeightOut
    ) private pure returns (uint256) {
        return
            WeightedMath._calcOutGivenIn(
                currentBalanceTokenIn,
                normalizedWeightIn,
                currentBalanceTokenOut,
                normalizedWeightOut,
                swapRequest.amount
            );
    }
    function _onSwapGivenOut(
        SwapRequest memory swapRequest,
        uint256 currentBalanceTokenIn,
        uint256 currentBalanceTokenOut,
        uint256 normalizedWeightIn,
        uint256 normalizedWeightOut
    ) private pure returns (uint256) {
        return
            WeightedMath._calcInGivenOut(
                currentBalanceTokenIn,
                normalizedWeightIn,
                currentBalanceTokenOut,
                normalizedWeightOut,
                swapRequest.amount
            );
    }
    function onJoinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    )
        public
        virtual
        override
        onlyVault(poolId)
        whenNotPaused
        returns (uint256[] memory amountsIn, uint256[] memory dueProtocolFeeAmounts)
    {
        uint256 bptAmountOut;
        if (totalSupply() == 0) {
            (bptAmountOut, amountsIn) = _onInitializePool(poolId, sender, recipient, userData);
            _require(bptAmountOut >= _MINIMUM_BPT, Errors.MINIMUM_BPT);
            _mintPoolTokens(address(0), _MINIMUM_BPT);
            _mintPoolTokens(recipient, bptAmountOut - _MINIMUM_BPT);
            _downscaleUpArray(amountsIn);
            dueProtocolFeeAmounts = new uint256[](2);
        } else {
            _upscaleArray(balances);
            _updateOracle(lastChangeBlock, balances[0], balances[1]);
            (bptAmountOut, amountsIn, dueProtocolFeeAmounts) = _onJoinPool(
                poolId,
                sender,
                recipient,
                balances,
                lastChangeBlock,
                protocolSwapFeePercentage,
                userData
            );
            _mintPoolTokens(recipient, bptAmountOut);
            _downscaleUpArray(amountsIn);
            _downscaleDownArray(dueProtocolFeeAmounts);
        }
        _cacheInvariantAndSupply();
    }
    function _onInitializePool(
        bytes32,
        address,
        address,
        bytes memory userData
    ) private returns (uint256, uint256[] memory) {
        BaseWeightedPool.JoinKind kind = userData.joinKind();
        _require(kind == BaseWeightedPool.JoinKind.INIT, Errors.UNINITIALIZED);
        uint256[] memory amountsIn = userData.initialAmountsIn();
        InputHelpers.ensureInputLengthMatch(amountsIn.length, 2);
        _upscaleArray(amountsIn);
        uint256[] memory normalizedWeights = _normalizedWeights();
        uint256 invariantAfterJoin = WeightedMath._calculateInvariant(normalizedWeights, amountsIn);
        uint256 bptAmountOut = Math.mul(invariantAfterJoin, 2);
        _lastInvariant = invariantAfterJoin;
        return (bptAmountOut, amountsIn);
    }
    function _onJoinPool(
        bytes32,
        address,
        address,
        uint256[] memory balances,
        uint256,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    )
        private
        returns (
            uint256,
            uint256[] memory,
            uint256[] memory
        )
    {
        uint256[] memory normalizedWeights = _normalizedWeights();
        uint256 invariantBeforeJoin = WeightedMath._calculateInvariant(normalizedWeights, balances);
        uint256[] memory dueProtocolFeeAmounts = _getDueProtocolFeeAmounts(
            balances,
            normalizedWeights,
            _lastInvariant,
            invariantBeforeJoin,
            protocolSwapFeePercentage
        );
        _mutateAmounts(balances, dueProtocolFeeAmounts, FixedPoint.sub);
        (uint256 bptAmountOut, uint256[] memory amountsIn) = _doJoin(balances, normalizedWeights, userData);
        _mutateAmounts(balances, amountsIn, FixedPoint.add);
        _lastInvariant = WeightedMath._calculateInvariant(normalizedWeights, balances);
        return (bptAmountOut, amountsIn, dueProtocolFeeAmounts);
    }
    function _doJoin(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        bytes memory userData
    ) private view returns (uint256, uint256[] memory) {
        BaseWeightedPool.JoinKind kind = userData.joinKind();
        if (kind == BaseWeightedPool.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT) {
            return _joinExactTokensInForBPTOut(balances, normalizedWeights, userData);
        } else if (kind == BaseWeightedPool.JoinKind.TOKEN_IN_FOR_EXACT_BPT_OUT) {
            return _joinTokenInForExactBPTOut(balances, normalizedWeights, userData);
        } else if (kind == BaseWeightedPool.JoinKind.ALL_TOKENS_IN_FOR_EXACT_BPT_OUT) {
            return _joinAllTokensInForExactBPTOut(balances, userData);
        } else {
            _revert(Errors.UNHANDLED_JOIN_KIND);
        }
    }
    function _joinExactTokensInForBPTOut(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        bytes memory userData
    ) private view returns (uint256, uint256[] memory) {
        (uint256[] memory amountsIn, uint256 minBPTAmountOut) = userData.exactTokensInForBptOut();
        InputHelpers.ensureInputLengthMatch(amountsIn.length, 2);
        _upscaleArray(amountsIn);
        (uint256 bptAmountOut, ) = WeightedMath._calcBptOutGivenExactTokensIn(
            balances,
            normalizedWeights,
            amountsIn,
            totalSupply(),
            getSwapFeePercentage()
        );
        _require(bptAmountOut >= minBPTAmountOut, Errors.BPT_OUT_MIN_AMOUNT);
        return (bptAmountOut, amountsIn);
    }
    function _joinTokenInForExactBPTOut(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        bytes memory userData
    ) private view returns (uint256, uint256[] memory) {
        (uint256 bptAmountOut, uint256 tokenIndex) = userData.tokenInForExactBptOut();
        _require(tokenIndex < 2, Errors.OUT_OF_BOUNDS);
        uint256[] memory amountsIn = new uint256[](2);
        (amountsIn[tokenIndex], ) = WeightedMath._calcTokenInGivenExactBptOut(
            balances[tokenIndex],
            normalizedWeights[tokenIndex],
            bptAmountOut,
            totalSupply(),
            getSwapFeePercentage()
        );
        return (bptAmountOut, amountsIn);
    }
    function _joinAllTokensInForExactBPTOut(uint256[] memory balances, bytes memory userData)
        private
        view
        returns (uint256, uint256[] memory)
    {
        uint256 bptAmountOut = userData.allTokensInForExactBptOut();
        uint256[] memory amountsIn = WeightedMath._calcAllTokensInGivenExactBptOut(
            balances,
            bptAmountOut,
            totalSupply()
        );
        return (bptAmountOut, amountsIn);
    }
    function onExitPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) public virtual override onlyVault(poolId) returns (uint256[] memory, uint256[] memory) {
        _upscaleArray(balances);
        (uint256 bptAmountIn, uint256[] memory amountsOut, uint256[] memory dueProtocolFeeAmounts) = _onExitPool(
            poolId,
            sender,
            recipient,
            balances,
            lastChangeBlock,
            protocolSwapFeePercentage,
            userData
        );
        _burnPoolTokens(sender, bptAmountIn);
        _downscaleDownArray(amountsOut);
        _downscaleDownArray(dueProtocolFeeAmounts);
        if (_isNotPaused()) {
            _cacheInvariantAndSupply();
        }
        return (amountsOut, dueProtocolFeeAmounts);
    }
    function _onExitPool(
        bytes32,
        address,
        address,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    )
        private
        returns (
            uint256 bptAmountIn,
            uint256[] memory amountsOut,
            uint256[] memory dueProtocolFeeAmounts
        )
    {
        uint256[] memory normalizedWeights = _normalizedWeights();
        if (_isNotPaused()) {
            _updateOracle(lastChangeBlock, balances[0], balances[1]);
            uint256 invariantBeforeExit = WeightedMath._calculateInvariant(normalizedWeights, balances);
            dueProtocolFeeAmounts = _getDueProtocolFeeAmounts(
                balances,
                normalizedWeights,
                _lastInvariant,
                invariantBeforeExit,
                protocolSwapFeePercentage
            );
            _mutateAmounts(balances, dueProtocolFeeAmounts, FixedPoint.sub);
        } else {
            dueProtocolFeeAmounts = new uint256[](2);
        }
        (bptAmountIn, amountsOut) = _doExit(balances, normalizedWeights, userData);
        _mutateAmounts(balances, amountsOut, FixedPoint.sub);
        _lastInvariant = WeightedMath._calculateInvariant(normalizedWeights, balances);
        return (bptAmountIn, amountsOut, dueProtocolFeeAmounts);
    }
    function _doExit(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        bytes memory userData
    ) private view returns (uint256, uint256[] memory) {
        BaseWeightedPool.ExitKind kind = userData.exitKind();
        if (kind == BaseWeightedPool.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT) {
            return _exitExactBPTInForTokenOut(balances, normalizedWeights, userData);
        } else if (kind == BaseWeightedPool.ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT) {
            return _exitExactBPTInForTokensOut(balances, userData);
        } else if (kind == BaseWeightedPool.ExitKind.BPT_IN_FOR_EXACT_TOKENS_OUT) {
            return _exitBPTInForExactTokensOut(balances, normalizedWeights, userData);
        } else {
            _revert(Errors.UNHANDLED_EXIT_KIND);
        }
    }
    function _exitExactBPTInForTokenOut(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        bytes memory userData
    ) private view whenNotPaused returns (uint256, uint256[] memory) {
        (uint256 bptAmountIn, uint256 tokenIndex) = userData.exactBptInForTokenOut();
        _require(tokenIndex < 2, Errors.OUT_OF_BOUNDS);
        uint256[] memory amountsOut = new uint256[](2);
        (amountsOut[tokenIndex], ) = WeightedMath._calcTokenOutGivenExactBptIn(
            balances[tokenIndex],
            normalizedWeights[tokenIndex],
            bptAmountIn,
            totalSupply(),
            getSwapFeePercentage()
        );
        return (bptAmountIn, amountsOut);
    }
    function _exitExactBPTInForTokensOut(uint256[] memory balances, bytes memory userData)
        private
        view
        returns (uint256, uint256[] memory)
    {
        uint256 bptAmountIn = userData.exactBptInForTokensOut();
        uint256[] memory amountsOut = WeightedMath._calcTokensOutGivenExactBptIn(balances, bptAmountIn, totalSupply());
        return (bptAmountIn, amountsOut);
    }
    function _exitBPTInForExactTokensOut(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        bytes memory userData
    ) private view whenNotPaused returns (uint256, uint256[] memory) {
        (uint256[] memory amountsOut, uint256 maxBPTAmountIn) = userData.bptInForExactTokensOut();
        InputHelpers.ensureInputLengthMatch(amountsOut.length, 2);
        _upscaleArray(amountsOut);
        (uint256 bptAmountIn, ) = WeightedMath._calcBptInGivenExactTokensOut(
            balances,
            normalizedWeights,
            amountsOut,
            totalSupply(),
            getSwapFeePercentage()
        );
        _require(bptAmountIn <= maxBPTAmountIn, Errors.BPT_IN_MAX_AMOUNT);
        return (bptAmountIn, amountsOut);
    }
    function _updateOracle(
        uint256 lastChangeBlock,
        uint256 balanceToken0,
        uint256 balanceToken1
    ) internal {
        bytes32 miscData = _miscData;
        if (miscData.oracleEnabled() && block.number > lastChangeBlock) {
            int256 logSpotPrice = WeightedOracleMath._calcLogSpotPrice(
                _normalizedWeight0,
                balanceToken0,
                _normalizedWeight1,
                balanceToken1
            );
            int256 logBPTPrice = WeightedOracleMath._calcLogBPTPrice(
                _normalizedWeight0,
                balanceToken0,
                miscData.logTotalSupply()
            );
            uint256 oracleCurrentIndex = miscData.oracleIndex();
            uint256 oracleCurrentSampleInitialTimestamp = miscData.oracleSampleCreationTimestamp();
            uint256 oracleUpdatedIndex = _processPriceData(
                oracleCurrentSampleInitialTimestamp,
                oracleCurrentIndex,
                logSpotPrice,
                logBPTPrice,
                miscData.logInvariant()
            );
            if (oracleCurrentIndex != oracleUpdatedIndex) {
                miscData = miscData.setOracleIndex(oracleUpdatedIndex);
                miscData = miscData.setOracleSampleCreationTimestamp(block.timestamp);
                _miscData = miscData;
            }
        }
    }
    function _cacheInvariantAndSupply() internal {
        bytes32 miscData = _miscData;
        if (miscData.oracleEnabled()) {
            miscData = miscData.setLogInvariant(LogCompression.toLowResLog(_lastInvariant));
            miscData = miscData.setLogTotalSupply(LogCompression.toLowResLog(totalSupply()));
            _miscData = miscData;
        }
    }
    function _getOracleIndex() internal view override returns (uint256) {
        return _miscData.oracleIndex();
    }
    function queryJoin(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) external returns (uint256 bptOut, uint256[] memory amountsIn) {
        InputHelpers.ensureInputLengthMatch(balances.length, 2);
        _queryAction(
            poolId,
            sender,
            recipient,
            balances,
            lastChangeBlock,
            protocolSwapFeePercentage,
            userData,
            _onJoinPool,
            _downscaleUpArray
        );
        return (bptOut, amountsIn);
    }
    function queryExit(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) external returns (uint256 bptIn, uint256[] memory amountsOut) {
        InputHelpers.ensureInputLengthMatch(balances.length, 2);
        _queryAction(
            poolId,
            sender,
            recipient,
            balances,
            lastChangeBlock,
            protocolSwapFeePercentage,
            userData,
            _onExitPool,
            _downscaleDownArray
        );
        return (bptIn, amountsOut);
    }
    function _getDueProtocolFeeAmounts(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256 previousInvariant,
        uint256 currentInvariant,
        uint256 protocolSwapFeePercentage
    ) private view returns (uint256[] memory) {
        uint256[] memory dueProtocolFeeAmounts = new uint256[](2);
        if (protocolSwapFeePercentage == 0) {
            return dueProtocolFeeAmounts;
        }
        dueProtocolFeeAmounts[_maxWeightTokenIndex] = WeightedMath._calcDueTokenProtocolSwapFeeAmount(
            balances[_maxWeightTokenIndex],
            normalizedWeights[_maxWeightTokenIndex],
            previousInvariant,
            currentInvariant,
            protocolSwapFeePercentage
        );
        return dueProtocolFeeAmounts;
    }
    function _mutateAmounts(
        uint256[] memory toMutate,
        uint256[] memory arguments,
        function(uint256, uint256) pure returns (uint256) mutation
    ) private pure {
        toMutate[0] = mutation(toMutate[0], arguments[0]);
        toMutate[1] = mutation(toMutate[1], arguments[1]);
    }
    function getRate() public view returns (uint256) {
        return Math.mul(getInvariant(), 2).divDown(totalSupply());
    }
    function _computeScalingFactor(IERC20 token) private view returns (uint256) {
        uint256 tokenDecimals = ERC20(address(token)).decimals();
        uint256 decimalsDifference = Math.sub(18, tokenDecimals);
        return 10**decimalsDifference;
    }
    function _scalingFactor(bool token0) internal view returns (uint256) {
        return token0 ? _scalingFactor0 : _scalingFactor1;
    }
    function _upscale(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        return Math.mul(amount, scalingFactor);
    }
    function _upscaleArray(uint256[] memory amounts) internal view {
        amounts[0] = Math.mul(amounts[0], _scalingFactor(true));
        amounts[1] = Math.mul(amounts[1], _scalingFactor(false));
    }
    function _downscaleDown(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        return Math.divDown(amount, scalingFactor);
    }
    function _downscaleDownArray(uint256[] memory amounts) internal view {
        amounts[0] = Math.divDown(amounts[0], _scalingFactor(true));
        amounts[1] = Math.divDown(amounts[1], _scalingFactor(false));
    }
    function _downscaleUp(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        return Math.divUp(amount, scalingFactor);
    }
    function _downscaleUpArray(uint256[] memory amounts) internal view {
        amounts[0] = Math.divUp(amounts[0], _scalingFactor(true));
        amounts[1] = Math.divUp(amounts[1], _scalingFactor(false));
    }
    function _getAuthorizer() internal view override returns (IAuthorizer) {
        return getVault().getAuthorizer();
    }
    function _queryAction(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData,
        function(bytes32, address, address, uint256[] memory, uint256, uint256, bytes memory)
            internal
            returns (uint256, uint256[] memory, uint256[] memory) _action,
        function(uint256[] memory) internal view _downscaleArray
    ) private {
        if (msg.sender != address(this)) {
            (bool success, ) = address(this).call(msg.data);
            assembly {
                switch success
                    case 0 {
                        returndatacopy(0, 0, 0x04)
                        let error := and(mload(0), 0xffffffff00000000000000000000000000000000000000000000000000000000)
                        if eq(eq(error, 0x43adbafb00000000000000000000000000000000000000000000000000000000), 0) {
                            returndatacopy(0, 0, returndatasize())
                            revert(0, returndatasize())
                        }
                        returndatacopy(0, 0x04, 32)
                        mstore(0x20, 64)
                        returndatacopy(0x40, 0x24, sub(returndatasize(), 36))
                        return(0, add(returndatasize(), 28))
                    }
                    default {
                        invalid()
                    }
            }
        } else {
            _upscaleArray(balances);
            (uint256 bptAmount, uint256[] memory tokenAmounts, ) = _action(
                poolId,
                sender,
                recipient,
                balances,
                lastChangeBlock,
                protocolSwapFeePercentage,
                userData
            );
            _downscaleArray(tokenAmounts);
            assembly {
                let size := mul(mload(tokenAmounts), 32)
                let start := sub(tokenAmounts, 0x20)
                mstore(start, bptAmount)
                mstore(sub(start, 0x20), 0x0000000000000000000000000000000000000000000000000000000043adbafb)
                start := sub(start, 0x04)
                revert(start, add(size, 68))
            }
        }
    }
}