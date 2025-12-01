pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/InputHelpers.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/WordCodec.sol";
import "@balancer-labs/v2-pool-utils/contracts/BaseGeneralPool.sol";
import "@balancer-labs/v2-pool-utils/contracts/BaseMinimalSwapInfoPool.sol";
import "@balancer-labs/v2-pool-utils/contracts/interfaces/IRateProvider.sol";
import "./StableMath.sol";
import "./StablePoolUserDataHelpers.sol";
contract StablePool is BaseGeneralPool, BaseMinimalSwapInfoPool, StableMath, IRateProvider {
    using WordCodec for bytes32;
    using FixedPoint for uint256;
    using StablePoolUserDataHelpers for bytes;
    uint256 private constant _MIN_UPDATE_TIME = 1 days;
    uint256 private constant _MAX_AMP_UPDATE_DAILY_RATE = 2;
    bytes32 private _packedAmplificationData;
    event AmpUpdateStarted(uint256 startValue, uint256 endValue, uint256 startTime, uint256 endTime);
    event AmpUpdateStopped(uint256 currentValue);
    uint256 private immutable _totalTokens;
    IERC20 internal immutable _token0;
    IERC20 internal immutable _token1;
    IERC20 internal immutable _token2;
    IERC20 internal immutable _token3;
    IERC20 internal immutable _token4;
    uint256 internal immutable _scalingFactor0;
    uint256 internal immutable _scalingFactor1;
    uint256 internal immutable _scalingFactor2;
    uint256 internal immutable _scalingFactor3;
    uint256 internal immutable _scalingFactor4;
    uint256 internal _lastInvariant;
    uint256 internal _lastInvariantAmp;
    enum JoinKind { INIT, EXACT_TOKENS_IN_FOR_BPT_OUT, TOKEN_IN_FOR_EXACT_BPT_OUT }
    enum ExitKind { EXACT_BPT_IN_FOR_ONE_TOKEN_OUT, EXACT_BPT_IN_FOR_TOKENS_OUT, BPT_IN_FOR_EXACT_TOKENS_OUT }
    constructor(
        IVault vault,
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        uint256 amplificationParameter,
        uint256 swapFeePercentage,
        uint256 pauseWindowDuration,
        uint256 bufferPeriodDuration,
        address owner
    )
        BasePool(
            vault,
            tokens.length == 2 ? IVault.PoolSpecialization.TWO_TOKEN : IVault.PoolSpecialization.GENERAL,
            name,
            symbol,
            tokens,
            new address[](tokens.length),
            swapFeePercentage,
            pauseWindowDuration,
            bufferPeriodDuration,
            owner
        )
    {
        _require(amplificationParameter >= _MIN_AMP, Errors.MIN_AMP);
        _require(amplificationParameter <= _MAX_AMP, Errors.MAX_AMP);
        uint256 totalTokens = tokens.length;
        _totalTokens = totalTokens;
        _token0 = tokens[0];
        _token1 = tokens[1];
        _token2 = totalTokens > 2 ? tokens[2] : IERC20(0);
        _token3 = totalTokens > 3 ? tokens[3] : IERC20(0);
        _token4 = totalTokens > 4 ? tokens[4] : IERC20(0);
        _scalingFactor0 = _computeScalingFactor(tokens[0]);
        _scalingFactor1 = _computeScalingFactor(tokens[1]);
        _scalingFactor2 = totalTokens > 2 ? _computeScalingFactor(tokens[2]) : 0;
        _scalingFactor3 = totalTokens > 3 ? _computeScalingFactor(tokens[3]) : 0;
        _scalingFactor4 = totalTokens > 4 ? _computeScalingFactor(tokens[4]) : 0;
        uint256 initialAmp = Math.mul(amplificationParameter, _AMP_PRECISION);
        _setAmplificationData(initialAmp);
    }
    function getLastInvariant() external view returns (uint256 lastInvariant, uint256 lastInvariantAmp) {
        lastInvariant = _lastInvariant;
        lastInvariantAmp = _lastInvariantAmp;
    }
    function _onSwapGivenIn(
        SwapRequest memory swapRequest,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 indexOut
    ) internal virtual override whenNotPaused returns (uint256) {
        (uint256 currentAmp, ) = _getAmplificationParameter();
        uint256 amountOut = StableMath._calcOutGivenIn(currentAmp, balances, indexIn, indexOut, swapRequest.amount);
        return amountOut;
    }
    function _onSwapGivenOut(
        SwapRequest memory swapRequest,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 indexOut
    ) internal virtual override whenNotPaused returns (uint256) {
        (uint256 currentAmp, ) = _getAmplificationParameter();
        uint256 amountIn = StableMath._calcInGivenOut(currentAmp, balances, indexIn, indexOut, swapRequest.amount);
        return amountIn;
    }
    function _onSwapGivenIn(
        SwapRequest memory swapRequest,
        uint256 balanceTokenIn,
        uint256 balanceTokenOut
    ) internal virtual override returns (uint256) {
        _require(_getTotalTokens() == 2, Errors.NOT_TWO_TOKENS);
        (uint256[] memory balances, uint256 indexIn, uint256 indexOut) = _getSwapBalanceArrays(
            swapRequest,
            balanceTokenIn,
            balanceTokenOut
        );
        return _onSwapGivenIn(swapRequest, balances, indexIn, indexOut);
    }
    function _onSwapGivenOut(
        SwapRequest memory swapRequest,
        uint256 balanceTokenIn,
        uint256 balanceTokenOut
    ) internal virtual override returns (uint256) {
        _require(_getTotalTokens() == 2, Errors.NOT_TWO_TOKENS);
        (uint256[] memory balances, uint256 indexIn, uint256 indexOut) = _getSwapBalanceArrays(
            swapRequest,
            balanceTokenIn,
            balanceTokenOut
        );
        return _onSwapGivenOut(swapRequest, balances, indexIn, indexOut);
    }
    function _getSwapBalanceArrays(
        SwapRequest memory swapRequest,
        uint256 balanceTokenIn,
        uint256 balanceTokenOut
    )
        private
        view
        returns (
            uint256[] memory balances,
            uint256 indexIn,
            uint256 indexOut
        )
    {
        balances = new uint256[](2);
        if (_isToken0(swapRequest.tokenIn)) {
            indexIn = 0;
            indexOut = 1;
            balances[0] = balanceTokenIn;
            balances[1] = balanceTokenOut;
        } else {
            indexOut = 0;
            indexIn = 1;
            balances[0] = balanceTokenOut;
            balances[1] = balanceTokenIn;
        }
    }
    function _onInitializePool(
        bytes32,
        address,
        address,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal virtual override whenNotPaused returns (uint256, uint256[] memory) {
        StablePool.JoinKind kind = userData.joinKind();
        _require(kind == StablePool.JoinKind.INIT, Errors.UNINITIALIZED);
        uint256[] memory amountsIn = userData.initialAmountsIn();
        InputHelpers.ensureInputLengthMatch(amountsIn.length, _getTotalTokens());
        _upscaleArray(amountsIn, scalingFactors);
        (uint256 currentAmp, ) = _getAmplificationParameter();
        uint256 invariantAfterJoin = StableMath._calculateInvariant(currentAmp, amountsIn, true);
        uint256 bptAmountOut = invariantAfterJoin;
        _updateLastInvariant(invariantAfterJoin, currentAmp);
        return (bptAmountOut, amountsIn);
    }
    function _onJoinPool(
        bytes32,
        address,
        address,
        uint256[] memory balances,
        uint256,
        uint256 protocolSwapFeePercentage,
        uint256[] memory scalingFactors,
        bytes memory userData
    )
        internal
        virtual
        override
        whenNotPaused
        returns (
            uint256,
            uint256[] memory,
            uint256[] memory
        )
    {
        uint256[] memory dueProtocolFeeAmounts = _getDueProtocolFeeAmounts(balances, protocolSwapFeePercentage);
        _mutateAmounts(balances, dueProtocolFeeAmounts, FixedPoint.sub);
        (uint256 bptAmountOut, uint256[] memory amountsIn) = _doJoin(balances, scalingFactors, userData);
        _updateInvariantAfterJoin(balances, amountsIn);
        return (bptAmountOut, amountsIn, dueProtocolFeeAmounts);
    }
    function _doJoin(
        uint256[] memory balances,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) private view returns (uint256, uint256[] memory) {
        JoinKind kind = userData.joinKind();
        if (kind == JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT) {
            return _joinExactTokensInForBPTOut(balances, scalingFactors, userData);
        } else if (kind == JoinKind.TOKEN_IN_FOR_EXACT_BPT_OUT) {
            return _joinTokenInForExactBPTOut(balances, userData);
        } else {
            _revert(Errors.UNHANDLED_JOIN_KIND);
        }
    }
    function _joinExactTokensInForBPTOut(
        uint256[] memory balances,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) private view returns (uint256, uint256[] memory) {
        (uint256[] memory amountsIn, uint256 minBPTAmountOut) = userData.exactTokensInForBptOut();
        InputHelpers.ensureInputLengthMatch(_getTotalTokens(), amountsIn.length);
        _upscaleArray(amountsIn, scalingFactors);
        (uint256 currentAmp, ) = _getAmplificationParameter();
        uint256 bptAmountOut = StableMath._calcBptOutGivenExactTokensIn(
            currentAmp,
            balances,
            amountsIn,
            totalSupply(),
            getSwapFeePercentage()
        );
        _require(bptAmountOut >= minBPTAmountOut, Errors.BPT_OUT_MIN_AMOUNT);
        return (bptAmountOut, amountsIn);
    }
    function _joinTokenInForExactBPTOut(uint256[] memory balances, bytes memory userData)
        private
        view
        returns (uint256, uint256[] memory)
    {
        (uint256 bptAmountOut, uint256 tokenIndex) = userData.tokenInForExactBptOut();
        _require(tokenIndex < _getTotalTokens(), Errors.OUT_OF_BOUNDS);
        uint256[] memory amountsIn = new uint256[](_getTotalTokens());
        (uint256 currentAmp, ) = _getAmplificationParameter();
        amountsIn[tokenIndex] = StableMath._calcTokenInGivenExactBptOut(
            currentAmp,
            balances,
            tokenIndex,
            bptAmountOut,
            totalSupply(),
            getSwapFeePercentage()
        );
        return (bptAmountOut, amountsIn);
    }
    function _onExitPool(
        bytes32,
        address,
        address,
        uint256[] memory balances,
        uint256,
        uint256 protocolSwapFeePercentage,
        uint256[] memory scalingFactors,
        bytes memory userData
    )
        internal
        virtual
        override
        returns (
            uint256 bptAmountIn,
            uint256[] memory amountsOut,
            uint256[] memory dueProtocolFeeAmounts
        )
    {
        if (_isNotPaused()) {
            dueProtocolFeeAmounts = _getDueProtocolFeeAmounts(balances, protocolSwapFeePercentage);
            _mutateAmounts(balances, dueProtocolFeeAmounts, FixedPoint.sub);
        } else {
            dueProtocolFeeAmounts = new uint256[](_getTotalTokens());
        }
        (bptAmountIn, amountsOut) = _doExit(balances, scalingFactors, userData);
        _updateInvariantAfterExit(balances, amountsOut);
        return (bptAmountIn, amountsOut, dueProtocolFeeAmounts);
    }
    function _doExit(
        uint256[] memory balances,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) private view returns (uint256, uint256[] memory) {
        ExitKind kind = userData.exitKind();
        if (kind == ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT) {
            return _exitExactBPTInForTokenOut(balances, userData);
        } else if (kind == ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT) {
            return _exitExactBPTInForTokensOut(balances, userData);
        } else if (kind == ExitKind.BPT_IN_FOR_EXACT_TOKENS_OUT) {
            return _exitBPTInForExactTokensOut(balances, scalingFactors, userData);
        } else {
            _revert(Errors.UNHANDLED_EXIT_KIND);
        }
    }
    function _exitExactBPTInForTokenOut(uint256[] memory balances, bytes memory userData)
        private
        view
        whenNotPaused
        returns (uint256, uint256[] memory)
    {
        (uint256 bptAmountIn, uint256 tokenIndex) = userData.exactBptInForTokenOut();
        _require(tokenIndex < _getTotalTokens(), Errors.OUT_OF_BOUNDS);
        uint256[] memory amountsOut = new uint256[](_getTotalTokens());
        (uint256 currentAmp, ) = _getAmplificationParameter();
        amountsOut[tokenIndex] = StableMath._calcTokenOutGivenExactBptIn(
            currentAmp,
            balances,
            tokenIndex,
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
        uint256[] memory amountsOut = StableMath._calcTokensOutGivenExactBptIn(balances, bptAmountIn, totalSupply());
        return (bptAmountIn, amountsOut);
    }
    function _exitBPTInForExactTokensOut(
        uint256[] memory balances,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) private view whenNotPaused returns (uint256, uint256[] memory) {
        (uint256[] memory amountsOut, uint256 maxBPTAmountIn) = userData.bptInForExactTokensOut();
        InputHelpers.ensureInputLengthMatch(amountsOut.length, _getTotalTokens());
        _upscaleArray(amountsOut, scalingFactors);
        (uint256 currentAmp, ) = _getAmplificationParameter();
        uint256 bptAmountIn = StableMath._calcBptInGivenExactTokensOut(
            currentAmp,
            balances,
            amountsOut,
            totalSupply(),
            getSwapFeePercentage()
        );
        _require(bptAmountIn <= maxBPTAmountIn, Errors.BPT_IN_MAX_AMOUNT);
        return (bptAmountIn, amountsOut);
    }
    function _updateLastInvariant(uint256 invariant, uint256 amplificationParameter) private {
        _lastInvariant = invariant;
        _lastInvariantAmp = amplificationParameter;
    }
    function _getDueProtocolFeeAmounts(uint256[] memory balances, uint256 protocolSwapFeePercentage)
        private
        view
        returns (uint256[] memory)
    {
        uint256[] memory dueProtocolFeeAmounts = new uint256[](_getTotalTokens());
        if (protocolSwapFeePercentage == 0) {
            return dueProtocolFeeAmounts;
        }
        uint256 chosenTokenIndex = 0;
        uint256 maxBalance = balances[0];
        for (uint256 i = 1; i < _getTotalTokens(); ++i) {
            uint256 currentBalance = balances[i];
            if (currentBalance > maxBalance) {
                chosenTokenIndex = i;
                maxBalance = currentBalance;
            }
        }
        dueProtocolFeeAmounts[chosenTokenIndex] = StableMath._calcDueTokenProtocolSwapFeeAmount(
            _lastInvariantAmp,
            balances,
            _lastInvariant,
            chosenTokenIndex,
            protocolSwapFeePercentage
        );
        return dueProtocolFeeAmounts;
    }
    function _updateInvariantAfterJoin(uint256[] memory balances, uint256[] memory amountsIn) private {
        _mutateAmounts(balances, amountsIn, FixedPoint.add);
        (uint256 currentAmp, ) = _getAmplificationParameter();
        _updateLastInvariant(StableMath._calculateInvariant(currentAmp, balances, true), currentAmp);
    }
    function _updateInvariantAfterExit(uint256[] memory balances, uint256[] memory amountsOut) private {
        _mutateAmounts(balances, amountsOut, FixedPoint.sub);
        (uint256 currentAmp, ) = _getAmplificationParameter();
        _updateLastInvariant(StableMath._calculateInvariant(currentAmp, balances, true), currentAmp);
    }
    function _mutateAmounts(
        uint256[] memory toMutate,
        uint256[] memory arguments,
        function(uint256, uint256) pure returns (uint256) mutation
    ) private view {
        for (uint256 i = 0; i < _getTotalTokens(); ++i) {
            toMutate[i] = mutation(toMutate[i], arguments[i]);
        }
    }
    function getRate() public view override returns (uint256) {
        (, uint256[] memory balances, ) = getVault().getPoolTokens(getPoolId());
        (uint256 currentAmp, ) = _getAmplificationParameter();
        _upscaleArray(balances, _scalingFactors());
        uint256 invariant = StableMath._calculateInvariant(currentAmp, balances, false);
        return invariant.divDown(totalSupply());
    }
    function startAmplificationParameterUpdate(uint256 rawEndValue, uint256 endTime) external authenticate {
        _require(rawEndValue >= _MIN_AMP, Errors.MIN_AMP);
        _require(rawEndValue <= _MAX_AMP, Errors.MAX_AMP);
        uint256 duration = Math.sub(endTime, block.timestamp);
        _require(duration >= _MIN_UPDATE_TIME, Errors.AMP_END_TIME_TOO_CLOSE);
        (uint256 currentValue, bool isUpdating) = _getAmplificationParameter();
        _require(!isUpdating, Errors.AMP_ONGOING_UPDATE);
        uint256 endValue = Math.mul(rawEndValue, _AMP_PRECISION);
        uint256 dailyRate = endValue > currentValue
            ? Math.divUp(Math.mul(1 days, endValue), Math.mul(currentValue, duration))
            : Math.divUp(Math.mul(1 days, currentValue), Math.mul(endValue, duration));
        _require(dailyRate <= _MAX_AMP_UPDATE_DAILY_RATE, Errors.AMP_RATE_TOO_HIGH);
        _setAmplificationData(currentValue, endValue, block.timestamp, endTime);
    }
    function stopAmplificationParameterUpdate() external authenticate {
        (uint256 currentValue, bool isUpdating) = _getAmplificationParameter();
        _require(isUpdating, Errors.AMP_NO_ONGOING_UPDATE);
        _setAmplificationData(currentValue);
    }
    function _isOwnerOnlyAction(bytes32 actionId) internal view virtual override returns (bool) {
        return
            (actionId == getActionId(StablePool.startAmplificationParameterUpdate.selector)) ||
            (actionId == getActionId(StablePool.stopAmplificationParameterUpdate.selector)) ||
            super._isOwnerOnlyAction(actionId);
    }
    function getAmplificationParameter()
        external
        view
        returns (
            uint256 value,
            bool isUpdating,
            uint256 precision
        )
    {
        (value, isUpdating) = _getAmplificationParameter();
        precision = _AMP_PRECISION;
    }
    function _getAmplificationParameter() internal view returns (uint256 value, bool isUpdating) {
        (uint256 startValue, uint256 endValue, uint256 startTime, uint256 endTime) = _getAmplificationData();
        if (block.timestamp < endTime) {
            isUpdating = true;
            if (endValue > startValue) {
                value = startValue + ((endValue - startValue) * (block.timestamp - startTime)) / (endTime - startTime);
            } else {
                value = startValue - ((startValue - endValue) * (block.timestamp - startTime)) / (endTime - startTime);
            }
        } else {
            isUpdating = false;
            value = endValue;
        }
    }
    function _getMaxTokens() internal pure override returns (uint256) {
        return _MAX_STABLE_TOKENS;
    }
    function _getTotalTokens() internal view virtual override returns (uint256) {
        return _totalTokens;
    }
    function _scalingFactor(IERC20 token) internal view virtual override returns (uint256) {
        if (_isToken0(token)) { return _getScalingFactor0(); }
        else if (_isToken1(token)) { return _getScalingFactor1(); }
        else if (token == _token2) { return _getScalingFactor2(); }
        else if (token == _token3) { return _getScalingFactor3(); }
        else if (token == _token4) { return _getScalingFactor4(); }
        else {
            _revert(Errors.INVALID_TOKEN);
        }
    }
    function _scalingFactors() internal view virtual override returns (uint256[] memory) {
        uint256 totalTokens = _getTotalTokens();
        uint256[] memory scalingFactors = new uint256[](totalTokens);
        {
            if (totalTokens > 0) { scalingFactors[0] = _getScalingFactor0(); } else { return scalingFactors; }
            if (totalTokens > 1) { scalingFactors[1] = _getScalingFactor1(); } else { return scalingFactors; }
            if (totalTokens > 2) { scalingFactors[2] = _getScalingFactor2(); } else { return scalingFactors; }
            if (totalTokens > 3) { scalingFactors[3] = _getScalingFactor3(); } else { return scalingFactors; }
            if (totalTokens > 4) { scalingFactors[4] = _getScalingFactor4(); } else { return scalingFactors; }
        }
        return scalingFactors;
    }
    function _setAmplificationData(uint256 value) private {
        _setAmplificationData(value, value, block.timestamp, block.timestamp);
        emit AmpUpdateStopped(value);
    }
    function _setAmplificationData(
        uint256 startValue,
        uint256 endValue,
        uint256 startTime,
        uint256 endTime
    ) private {
        _packedAmplificationData =
            WordCodec.encodeUint(uint64(startValue), 0) |
            WordCodec.encodeUint(uint64(endValue), 64) |
            WordCodec.encodeUint(uint64(startTime), 64 * 2) |
            WordCodec.encodeUint(uint64(endTime), 64 * 3);
        emit AmpUpdateStarted(startValue, endValue, startTime, endTime);
    }
    function _getAmplificationData()
        private
        view
        returns (
            uint256 startValue,
            uint256 endValue,
            uint256 startTime,
            uint256 endTime
        )
    {
        startValue = _packedAmplificationData.decodeUint64(0);
        endValue = _packedAmplificationData.decodeUint64(64);
        startTime = _packedAmplificationData.decodeUint64(64 * 2);
        endTime = _packedAmplificationData.decodeUint64(64 * 3);
    }
    function _isToken0(IERC20 token) internal view returns (bool) {
        return token == _token0;
    }
    function _isToken1(IERC20 token) internal view returns (bool) {
        return token == _token1;
    }
    function _getScalingFactor0() internal view returns (uint256) {
        return _scalingFactor0;
    }
    function _getScalingFactor1() internal view returns (uint256) {
        return _scalingFactor1;
    }
    function _getScalingFactor2() internal view returns (uint256) {
        return _scalingFactor2;
    }
    function _getScalingFactor3() internal view returns (uint256) {
        return _scalingFactor3;
    }
    function _getScalingFactor4() internal view returns (uint256) {
        return _scalingFactor4;
    }
}