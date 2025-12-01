pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/InputHelpers.sol";
import "@balancer-labs/v2-pool-utils/contracts/BaseMinimalSwapInfoPool.sol";
import "./WeightedMath.sol";
import "./WeightedPoolUserDataHelpers.sol";
abstract contract BaseWeightedPool is BaseMinimalSwapInfoPool, WeightedMath {
    using FixedPoint for uint256;
    using WeightedPoolUserDataHelpers for bytes;
    uint256 private _lastInvariant;
    enum JoinKind { INIT, EXACT_TOKENS_IN_FOR_BPT_OUT, TOKEN_IN_FOR_EXACT_BPT_OUT, ALL_TOKENS_IN_FOR_EXACT_BPT_OUT }
    enum ExitKind {
        EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
        EXACT_BPT_IN_FOR_TOKENS_OUT,
        BPT_IN_FOR_EXACT_TOKENS_OUT,
        MANAGEMENT_FEE_TOKENS_OUT 
    }
    constructor(
        IVault vault,
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        address[] memory assetManagers,
        uint256 swapFeePercentage,
        uint256 pauseWindowDuration,
        uint256 bufferPeriodDuration,
        address owner
    )
        BasePool(
            vault,
            tokens.length == 2 ? IVault.PoolSpecialization.TWO_TOKEN : IVault.PoolSpecialization.MINIMAL_SWAP_INFO,
            name,
            symbol,
            tokens,
            assetManagers,
            swapFeePercentage,
            pauseWindowDuration,
            bufferPeriodDuration,
            owner
        )
    {
    }
    function _getNormalizedWeight(IERC20 token) internal view virtual returns (uint256);
    function _getNormalizedWeights() internal view virtual returns (uint256[] memory);
    function _getNormalizedWeightsAndMaxWeightIndex() internal view virtual returns (uint256[] memory, uint256);
    function getLastInvariant() public view virtual returns (uint256) {
        return _lastInvariant;
    }
    function getInvariant() public view returns (uint256) {
        (, uint256[] memory balances, ) = getVault().getPoolTokens(getPoolId());
        _upscaleArray(balances, _scalingFactors());
        (uint256[] memory normalizedWeights, ) = _getNormalizedWeightsAndMaxWeightIndex();
        return WeightedMath._calculateInvariant(normalizedWeights, balances);
    }
    function getNormalizedWeights() external view returns (uint256[] memory) {
        return _getNormalizedWeights();
    }
    function _onSwapGivenIn(
        SwapRequest memory swapRequest,
        uint256 currentBalanceTokenIn,
        uint256 currentBalanceTokenOut
    ) internal view virtual override whenNotPaused returns (uint256) {
        return
            WeightedMath._calcOutGivenIn(
                currentBalanceTokenIn,
                _getNormalizedWeight(swapRequest.tokenIn),
                currentBalanceTokenOut,
                _getNormalizedWeight(swapRequest.tokenOut),
                swapRequest.amount
            );
    }
    function _onSwapGivenOut(
        SwapRequest memory swapRequest,
        uint256 currentBalanceTokenIn,
        uint256 currentBalanceTokenOut
    ) internal view virtual override whenNotPaused returns (uint256) {
        return
            WeightedMath._calcInGivenOut(
                currentBalanceTokenIn,
                _getNormalizedWeight(swapRequest.tokenIn),
                currentBalanceTokenOut,
                _getNormalizedWeight(swapRequest.tokenOut),
                swapRequest.amount
            );
    }
    function _onInitializePool(
        bytes32,
        address,
        address,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal virtual override whenNotPaused returns (uint256, uint256[] memory) {
        JoinKind kind = userData.joinKind();
        _require(kind == JoinKind.INIT, Errors.UNINITIALIZED);
        uint256[] memory amountsIn = userData.initialAmountsIn();
        InputHelpers.ensureInputLengthMatch(_getTotalTokens(), amountsIn.length);
        _upscaleArray(amountsIn, scalingFactors);
        (uint256[] memory normalizedWeights, ) = _getNormalizedWeightsAndMaxWeightIndex();
        uint256 invariantAfterJoin = WeightedMath._calculateInvariant(normalizedWeights, amountsIn);
        uint256 bptAmountOut = Math.mul(invariantAfterJoin, _getTotalTokens());
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
        (uint256[] memory normalizedWeights, uint256 maxWeightTokenIndex) = _getNormalizedWeightsAndMaxWeightIndex();
        uint256 invariantBeforeJoin = WeightedMath._calculateInvariant(normalizedWeights, balances);
        uint256[] memory dueProtocolFeeAmounts = _getDueProtocolFeeAmounts(
            balances,
            normalizedWeights,
            maxWeightTokenIndex,
            _lastInvariant,
            invariantBeforeJoin,
            protocolSwapFeePercentage
        );
        _mutateAmounts(balances, dueProtocolFeeAmounts, FixedPoint.sub);
        (uint256 bptAmountOut, uint256[] memory amountsIn) = _doJoin(
            balances,
            normalizedWeights,
            scalingFactors,
            userData
        );
        _lastInvariant = _invariantAfterJoin(balances, amountsIn, normalizedWeights);
        return (bptAmountOut, amountsIn, dueProtocolFeeAmounts);
    }
    function _doJoin(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal returns (uint256, uint256[] memory) {
        JoinKind kind = userData.joinKind();
        if (kind == JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT) {
            return _joinExactTokensInForBPTOut(balances, normalizedWeights, scalingFactors, userData);
        } else if (kind == JoinKind.TOKEN_IN_FOR_EXACT_BPT_OUT) {
            return _joinTokenInForExactBPTOut(balances, normalizedWeights, userData);
        } else if (kind == JoinKind.ALL_TOKENS_IN_FOR_EXACT_BPT_OUT) {
            return _joinAllTokensInForExactBPTOut(balances, userData);
        } else {
            _revert(Errors.UNHANDLED_JOIN_KIND);
        }
    }
    function _joinExactTokensInForBPTOut(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) private returns (uint256, uint256[] memory) {
        (uint256[] memory amountsIn, uint256 minBPTAmountOut) = userData.exactTokensInForBptOut();
        InputHelpers.ensureInputLengthMatch(_getTotalTokens(), amountsIn.length);
        _upscaleArray(amountsIn, scalingFactors);
        (uint256 bptAmountOut, uint256[] memory swapFees) = WeightedMath._calcBptOutGivenExactTokensIn(
            balances,
            normalizedWeights,
            amountsIn,
            totalSupply(),
            getSwapFeePercentage()
        );
        _processSwapFeeAmounts(swapFees);
        _require(bptAmountOut >= minBPTAmountOut, Errors.BPT_OUT_MIN_AMOUNT);
        return (bptAmountOut, amountsIn);
    }
    function _joinTokenInForExactBPTOut(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        bytes memory userData
    ) private returns (uint256, uint256[] memory) {
        (uint256 bptAmountOut, uint256 tokenIndex) = userData.tokenInForExactBptOut();
        _require(tokenIndex < _getTotalTokens(), Errors.OUT_OF_BOUNDS);
        (uint256 amountIn, uint256 swapFee) = WeightedMath._calcTokenInGivenExactBptOut(
            balances[tokenIndex],
            normalizedWeights[tokenIndex],
            bptAmountOut,
            totalSupply(),
            getSwapFeePercentage()
        );
        _processSwapFeeAmount(tokenIndex, swapFee);
        uint256[] memory amountsIn = new uint256[](_getTotalTokens());
        amountsIn[tokenIndex] = amountIn;
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
        (uint256[] memory normalizedWeights, uint256 maxWeightTokenIndex) = _getNormalizedWeightsAndMaxWeightIndex();
        if (_isNotPaused()) {
            uint256 invariantBeforeExit = WeightedMath._calculateInvariant(normalizedWeights, balances);
            dueProtocolFeeAmounts = _getDueProtocolFeeAmounts(
                balances,
                normalizedWeights,
                maxWeightTokenIndex,
                _lastInvariant,
                invariantBeforeExit,
                protocolSwapFeePercentage
            );
            _mutateAmounts(balances, dueProtocolFeeAmounts, FixedPoint.sub);
        } else {
            dueProtocolFeeAmounts = new uint256[](_getTotalTokens());
        }
        (bptAmountIn, amountsOut) = _doExit(balances, normalizedWeights, scalingFactors, userData);
        _lastInvariant = _invariantAfterExit(balances, amountsOut, normalizedWeights);
        return (bptAmountIn, amountsOut, dueProtocolFeeAmounts);
    }
    function _doExit(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal returns (uint256, uint256[] memory) {
        ExitKind kind = userData.exitKind();
        if (kind == ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT) {
            return _exitExactBPTInForTokenOut(balances, normalizedWeights, userData);
        } else if (kind == ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT) {
            return _exitExactBPTInForTokensOut(balances, userData);
        } else if (kind == ExitKind.BPT_IN_FOR_EXACT_TOKENS_OUT) {
            return _exitBPTInForExactTokensOut(balances, normalizedWeights, scalingFactors, userData);
        } else {
            _revert(Errors.UNHANDLED_EXIT_KIND);
        }
    }
    function _exitExactBPTInForTokenOut(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        bytes memory userData
    ) private whenNotPaused returns (uint256, uint256[] memory) {
        (uint256 bptAmountIn, uint256 tokenIndex) = userData.exactBptInForTokenOut();
        _require(tokenIndex < _getTotalTokens(), Errors.OUT_OF_BOUNDS);
        (uint256 amountOut, uint256 swapFee) = WeightedMath._calcTokenOutGivenExactBptIn(
            balances[tokenIndex],
            normalizedWeights[tokenIndex],
            bptAmountIn,
            totalSupply(),
            getSwapFeePercentage()
        );
        _processSwapFeeAmount(tokenIndex, swapFee);
        uint256[] memory amountsOut = new uint256[](_getTotalTokens());
        amountsOut[tokenIndex] = amountOut;
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
        uint256[] memory scalingFactors,
        bytes memory userData
    ) private whenNotPaused returns (uint256, uint256[] memory) {
        (uint256[] memory amountsOut, uint256 maxBPTAmountIn) = userData.bptInForExactTokensOut();
        InputHelpers.ensureInputLengthMatch(amountsOut.length, _getTotalTokens());
        _upscaleArray(amountsOut, scalingFactors);
        (uint256 bptAmountIn, uint256[] memory swapFees) = WeightedMath._calcBptInGivenExactTokensOut(
            balances,
            normalizedWeights,
            amountsOut,
            totalSupply(),
            getSwapFeePercentage()
        );
        _require(bptAmountIn <= maxBPTAmountIn, Errors.BPT_IN_MAX_AMOUNT);
        _processSwapFeeAmounts(swapFees);
        return (bptAmountIn, amountsOut);
    }
    function _getDueProtocolFeeAmounts(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256 maxWeightTokenIndex,
        uint256 previousInvariant,
        uint256 currentInvariant,
        uint256 protocolSwapFeePercentage
    ) private view returns (uint256[] memory) {
        uint256[] memory dueProtocolFeeAmounts = new uint256[](_getTotalTokens());
        if (protocolSwapFeePercentage == 0) {
            return dueProtocolFeeAmounts;
        }
        dueProtocolFeeAmounts[maxWeightTokenIndex] = WeightedMath._calcDueTokenProtocolSwapFeeAmount(
            balances[maxWeightTokenIndex],
            normalizedWeights[maxWeightTokenIndex],
            previousInvariant,
            currentInvariant,
            protocolSwapFeePercentage
        );
        return dueProtocolFeeAmounts;
    }
    function _invariantAfterJoin(
        uint256[] memory balances,
        uint256[] memory amountsIn,
        uint256[] memory normalizedWeights
    ) private view returns (uint256) {
        _mutateAmounts(balances, amountsIn, FixedPoint.add);
        return WeightedMath._calculateInvariant(normalizedWeights, balances);
    }
    function _invariantAfterExit(
        uint256[] memory balances,
        uint256[] memory amountsOut,
        uint256[] memory normalizedWeights
    ) private view returns (uint256) {
        _mutateAmounts(balances, amountsOut, FixedPoint.sub);
        return WeightedMath._calculateInvariant(normalizedWeights, balances);
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
    function getRate() public view returns (uint256) {
        return Math.mul(getInvariant(), _getTotalTokens()).divDown(totalSupply());
    }
}