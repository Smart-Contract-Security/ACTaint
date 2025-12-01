pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/EnumerableMap.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/ReentrancyGuard.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/ERC20Helpers.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/WordCodec.sol";
import "../BaseWeightedPool.sol";
import "../WeightedPoolUserDataHelpers.sol";
import "./WeightCompression.sol";
contract InvestmentPool is BaseWeightedPool, ReentrancyGuard {
    using FixedPoint for uint256;
    using WordCodec for bytes32;
    using WeightCompression for uint256;
    using WeightedPoolUserDataHelpers for bytes;
    using EnumerableMap for EnumerableMap.IERC20ToUint256Map;
    uint256 private constant _MAX_INVESTMENT_TOKENS = 50;
    uint256 private immutable _managementSwapFeePercentage;
    uint256 private constant _MAX_MANAGEMENT_SWAP_FEE_PERCENTAGE = 1e18; 
    uint256 private constant _SWAP_ENABLED_OFFSET = 0;
    uint256 private constant _TOTAL_TOKENS_OFFSET = 1;
    uint256 private constant _START_TIME_OFFSET = 8;
    uint256 private constant _END_TIME_OFFSET = 40;
    mapping(IERC20 => bytes32) private _tokenState;
    EnumerableMap.IERC20ToUint256Map private _tokenCollectedManagementFees;
    uint256 private constant _START_WEIGHT_OFFSET = 0;
    uint256 private constant _END_WEIGHT_OFFSET = 64;
    uint256 private constant _DECIMAL_DIFF_OFFSET = 96;
    uint256 private constant _MINIMUM_WEIGHT_CHANGE_DURATION = 1 days;
    event GradualWeightUpdateScheduled(
        uint256 startTime,
        uint256 endTime,
        uint256[] startWeights,
        uint256[] endWeights
    );
    event SwapEnabledSet(bool swapEnabled);
    event ManagementFeePercentageChanged(uint256 managementFeePercentage);
    event ManagementFeesCollected(IERC20[] tokens, uint256[] amounts);
    struct NewPoolParams {
        IVault vault;
        string name;
        string symbol;
        IERC20[] tokens;
        uint256[] normalizedWeights;
        address[] assetManagers;
        uint256 swapFeePercentage;
        uint256 pauseWindowDuration;
        uint256 bufferPeriodDuration;
        address owner;
        bool swapEnabledOnStart;
        uint256 managementSwapFeePercentage;
    }
    constructor(NewPoolParams memory params)
        BaseWeightedPool(
            params.vault,
            params.name,
            params.symbol,
            params.tokens,
            params.assetManagers,
            params.swapFeePercentage,
            params.pauseWindowDuration,
            params.bufferPeriodDuration,
            params.owner
        )
    {
        uint256 totalTokens = params.tokens.length;
        InputHelpers.ensureInputLengthMatch(totalTokens, params.normalizedWeights.length, params.assetManagers.length);
        _setMiscData(_getMiscData().insertUint7(totalTokens, _TOTAL_TOKENS_OFFSET));
        _require(_getTotalTokens() == totalTokens, Errors.MAX_TOKENS);
        uint256 currentTime = block.timestamp;
        _startGradualWeightChange(
            currentTime,
            currentTime,
            params.normalizedWeights,
            params.normalizedWeights,
            params.tokens
        );
        for (uint256 i = 0; i < totalTokens; ++i) {
            _tokenCollectedManagementFees.set(params.tokens[i], 0);
        }
        _setSwapEnabled(params.swapEnabledOnStart);
        _require(
            params.managementSwapFeePercentage <= _MAX_MANAGEMENT_SWAP_FEE_PERCENTAGE,
            Errors.MAX_MANAGEMENT_SWAP_FEE_PERCENTAGE
        );
        _managementSwapFeePercentage = params.managementSwapFeePercentage;
        emit ManagementFeePercentageChanged(params.managementSwapFeePercentage);
    }
    function getSwapEnabled() public view returns (bool) {
        return _getMiscData().decodeBool(_SWAP_ENABLED_OFFSET);
    }
    function getManagementSwapFeePercentage() public view returns (uint256) {
        return _managementSwapFeePercentage;
    }
    function getMinimumWeightChangeDuration() external pure returns (uint256) {
        return _MINIMUM_WEIGHT_CHANGE_DURATION;
    }
    function getGradualWeightUpdateParams()
        external
        view
        returns (
            uint256 startTime,
            uint256 endTime,
            uint256[] memory endWeights
        )
    {
        bytes32 poolState = _getMiscData();
        startTime = poolState.decodeUint32(_START_TIME_OFFSET);
        endTime = poolState.decodeUint32(_END_TIME_OFFSET);
        (IERC20[] memory tokens, , ) = getVault().getPoolTokens(getPoolId());
        uint256 totalTokens = tokens.length;
        endWeights = new uint256[](totalTokens);
        for (uint256 i = 0; i < totalTokens; i++) {
            endWeights[i] = _tokenState[tokens[i]].decodeUint32(_END_WEIGHT_OFFSET).uncompress32();
        }
    }
    function _getMaxTokens() internal pure virtual override returns (uint256) {
        return _MAX_INVESTMENT_TOKENS;
    }
    function _getTotalTokens() internal view virtual override returns (uint256) {
        return _getMiscData().decodeUint7(_TOTAL_TOKENS_OFFSET);
    }
    function updateWeightsGradually(
        uint256 startTime,
        uint256 endTime,
        uint256[] memory endWeights
    ) external authenticate whenNotPaused nonReentrant {
        InputHelpers.ensureInputLengthMatch(_getTotalTokens(), endWeights.length);
        uint256 currentTime = block.timestamp;
        startTime = Math.max(currentTime, startTime);
        _require(startTime <= endTime, Errors.GRADUAL_UPDATE_TIME_TRAVEL);
        _require(endTime - startTime >= _MINIMUM_WEIGHT_CHANGE_DURATION, Errors.WEIGHT_CHANGE_TOO_FAST);
        (IERC20[] memory tokens, , ) = getVault().getPoolTokens(getPoolId());
        _startGradualWeightChange(startTime, endTime, _getNormalizedWeights(), endWeights, tokens);
    }
    function getCollectedManagementFees() public view returns (IERC20[] memory tokens, uint256[] memory collectedFees) {
        tokens = new IERC20[](_getTotalTokens());
        collectedFees = new uint256[](_getTotalTokens());
        for (uint256 i = 0; i < _getTotalTokens(); ++i) {
            (IERC20 token, uint256 fees) = _tokenCollectedManagementFees.unchecked_at(i);
            tokens[i] = token;
            collectedFees[i] = fees;
        }
        _downscaleDownArray(collectedFees, _scalingFactors());
    }
    function withdrawCollectedManagementFees(address recipient) external authenticate whenNotPaused nonReentrant {
        (IERC20[] memory tokens, uint256[] memory collectedFees) = getCollectedManagementFees();
        getVault().exitPool(
            getPoolId(),
            address(this),
            payable(recipient),
            IVault.ExitPoolRequest({
                assets: _asIAsset(tokens),
                minAmountsOut: collectedFees,
                userData: abi.encode(BaseWeightedPool.ExitKind.MANAGEMENT_FEE_TOKENS_OUT),
                toInternalBalance: false
            })
        );
        emit ManagementFeesCollected(tokens, collectedFees);
    }
    function setSwapEnabled(bool swapEnabled) external authenticate whenNotPaused nonReentrant {
        _setSwapEnabled(swapEnabled);
    }
    function _setSwapEnabled(bool swapEnabled) private {
        _setMiscData(_getMiscData().insertBool(swapEnabled, _SWAP_ENABLED_OFFSET));
        emit SwapEnabledSet(swapEnabled);
    }
    function _scalingFactor(IERC20 token) internal view virtual override returns (uint256) {
        return _readScalingFactor(_getTokenData(token));
    }
    function _scalingFactors() internal view virtual override returns (uint256[] memory scalingFactors) {
        (IERC20[] memory tokens, , ) = getVault().getPoolTokens(getPoolId());
        uint256 numTokens = tokens.length;
        scalingFactors = new uint256[](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            scalingFactors[i] = _readScalingFactor(_tokenState[tokens[i]]);
        }
    }
    function _getNormalizedWeight(IERC20 token) internal view override returns (uint256) {
        uint256 pctProgress = _calculateWeightChangeProgress();
        bytes32 tokenData = _getTokenData(token);
        return _interpolateWeight(tokenData, pctProgress);
    }
    function _getNormalizedWeights() internal view override returns (uint256[] memory normalizedWeights) {
        (IERC20[] memory tokens, , ) = getVault().getPoolTokens(getPoolId());
        uint256 numTokens = tokens.length;
        normalizedWeights = new uint256[](numTokens);
        uint256 pctProgress = _calculateWeightChangeProgress();
        for (uint256 i = 0; i < numTokens; i++) {
            bytes32 tokenData = _tokenState[tokens[i]];
            normalizedWeights[i] = _interpolateWeight(tokenData, pctProgress);
        }
    }
    function _getNormalizedWeightsAndMaxWeightIndex()
        internal
        view
        override
        returns (uint256[] memory normalizedWeights, uint256 maxWeightTokenIndex)
    {
        normalizedWeights = _getNormalizedWeights();
        maxWeightTokenIndex = 0;
        uint256 maxNormalizedWeight = normalizedWeights[0];
        for (uint256 i = 1; i < normalizedWeights.length; i++) {
            if (normalizedWeights[i] > maxNormalizedWeight) {
                maxWeightTokenIndex = i;
                maxNormalizedWeight = normalizedWeights[i];
            }
        }
    }
    function _onSwapGivenIn(
        SwapRequest memory swapRequest,
        uint256 currentBalanceTokenIn,
        uint256 currentBalanceTokenOut
    ) internal view override returns (uint256) {
        _require(getSwapEnabled(), Errors.SWAPS_DISABLED);
        return super._onSwapGivenIn(swapRequest, currentBalanceTokenIn, currentBalanceTokenOut);
    }
    function _onSwapGivenOut(
        SwapRequest memory swapRequest,
        uint256 currentBalanceTokenIn,
        uint256 currentBalanceTokenOut
    ) internal view override returns (uint256) {
        _require(getSwapEnabled(), Errors.SWAPS_DISABLED);
        return super._onSwapGivenOut(swapRequest, currentBalanceTokenIn, currentBalanceTokenOut);
    }
    function _subtractCollectedFees(uint256[] memory balances) private view {
        for (uint256 i = 0; i < _getTotalTokens(); ++i) {
            balances[i] = balances[i].sub(_tokenCollectedManagementFees.unchecked_valueAt(i));
        }
    }
    function getLastInvariant() public pure override returns (uint256) {
        _revert(Errors.UNHANDLED_BY_INVESTMENT_POOL);
    }
    function _onJoinPool(
        bytes32,
        address,
        address,
        uint256[] memory balances,
        uint256,
        uint256,
        uint256[] memory scalingFactors,
        bytes memory userData
    )
        internal
        virtual
        override
        whenNotPaused 
        returns (
            uint256 bptAmountOut,
            uint256[] memory amountsIn,
            uint256[] memory dueProtocolFeeAmounts
        )
    {
        _subtractCollectedFees(balances);
        _require(
            getSwapEnabled() || userData.joinKind() == JoinKind.ALL_TOKENS_IN_FOR_EXACT_BPT_OUT,
            Errors.INVALID_JOIN_EXIT_KIND_WHILE_SWAPS_DISABLED
        );
        (bptAmountOut, amountsIn) = _doJoin(balances, _getNormalizedWeights(), scalingFactors, userData);
        dueProtocolFeeAmounts = new uint256[](_getTotalTokens());
    }
    function _onExitPool(
        bytes32,
        address sender,
        address,
        uint256[] memory balances,
        uint256,
        uint256,
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
        _subtractCollectedFees(balances);
        ExitKind kind = userData.exitKind();
        _require(
            getSwapEnabled() ||
                kind == ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT ||
                kind == ExitKind.MANAGEMENT_FEE_TOKENS_OUT,
            Errors.INVALID_JOIN_EXIT_KIND_WHILE_SWAPS_DISABLED
        );
        (bptAmountIn, amountsOut) = _doInvestmentPoolExit(
            sender,
            balances,
            _getNormalizedWeights(),
            scalingFactors,
            userData
        );
        dueProtocolFeeAmounts = new uint256[](_getTotalTokens());
    }
    function _doInvestmentPoolExit(
        address sender,
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal returns (uint256, uint256[] memory) {
        ExitKind kind = userData.exitKind();
        if (kind == ExitKind.MANAGEMENT_FEE_TOKENS_OUT) {
            return _exitManagerFeeTokensOut(sender);
        } else {
            return _doExit(balances, normalizedWeights, scalingFactors, userData);
        }
    }
    function _exitManagerFeeTokensOut(address sender)
        private
        whenNotPaused
        returns (uint256 bptAmountIn, uint256[] memory amountsOut)
    {
        _require(sender == address(this), Errors.UNAUTHORIZED_EXIT);
        bptAmountIn = 0;
        amountsOut = new uint256[](_getTotalTokens());
        for (uint256 i = 0; i < _getTotalTokens(); ++i) {
            amountsOut[i] = _tokenCollectedManagementFees.unchecked_valueAt(i);
            _tokenCollectedManagementFees.unchecked_setAt(i, 0);
        }
    }
    function _tokenAddressToIndex(IERC20 token) internal view override returns (uint256) {
        return _tokenCollectedManagementFees.indexOf(token, Errors.INVALID_TOKEN);
    }
    function _processSwapFeeAmount(uint256 index, uint256 amount) internal virtual override {
        if (amount > 0) {
            uint256 managementFeeAmount = amount.mulDown(_managementSwapFeePercentage);
            uint256 previousCollectedFees = _tokenCollectedManagementFees.unchecked_valueAt(index);
            _tokenCollectedManagementFees.unchecked_setAt(index, previousCollectedFees.add(managementFeeAmount));
        }
        super._processSwapFeeAmount(index, amount);
    }
    function onSwap(
        SwapRequest memory swapRequest,
        uint256 currentBalanceTokenIn,
        uint256 currentBalanceTokenOut
    ) public override returns (uint256) {
        uint256 tokenInUpscaledCollectedFees = _tokenCollectedManagementFees.get(
            swapRequest.tokenIn,
            Errors.INVALID_TOKEN
        );
        uint256 adjustedBalanceTokenIn = currentBalanceTokenIn.sub(
            _downscaleDown(tokenInUpscaledCollectedFees, _scalingFactor(swapRequest.tokenIn))
        );
        uint256 tokenOutUpscaledCollectedFees = _tokenCollectedManagementFees.get(
            swapRequest.tokenOut,
            Errors.INVALID_TOKEN
        );
        uint256 adjustedBalanceTokenOut = currentBalanceTokenOut.sub(
            _downscaleDown(tokenOutUpscaledCollectedFees, _scalingFactor(swapRequest.tokenOut))
        );
        return super.onSwap(swapRequest, adjustedBalanceTokenIn, adjustedBalanceTokenOut);
    }
    function _startGradualWeightChange(
        uint256 startTime,
        uint256 endTime,
        uint256[] memory startWeights,
        uint256[] memory endWeights,
        IERC20[] memory tokens
    ) internal virtual {
        uint256 normalizedSum = 0;
        bytes32 tokenState;
        for (uint256 i = 0; i < endWeights.length; i++) {
            uint256 endWeight = endWeights[i];
            _require(endWeight >= _MIN_WEIGHT, Errors.MIN_WEIGHT);
            IERC20 token = tokens[i];
            _tokenState[token] = tokenState
                .insertUint64(startWeights[i].compress64(), _START_WEIGHT_OFFSET)
                .insertUint32(endWeight.compress32(), _END_WEIGHT_OFFSET)
                .insertUint5(uint256(18).sub(ERC20(address(token)).decimals()), _DECIMAL_DIFF_OFFSET);
            normalizedSum = normalizedSum.add(endWeight);
        }
        _require(normalizedSum == FixedPoint.ONE, Errors.NORMALIZED_WEIGHT_INVARIANT);
        _setMiscData(
            _getMiscData().insertUint32(startTime, _START_TIME_OFFSET).insertUint32(endTime, _END_TIME_OFFSET)
        );
        emit GradualWeightUpdateScheduled(startTime, endTime, startWeights, endWeights);
    }
    function _readScalingFactor(bytes32 tokenState) private pure returns (uint256) {
        uint256 decimalsDifference = tokenState.decodeUint5(_DECIMAL_DIFF_OFFSET);
        return FixedPoint.ONE * 10**decimalsDifference;
    }
    function _isOwnerOnlyAction(bytes32 actionId) internal view override returns (bool) {
        return
            (actionId == getActionId(InvestmentPool.updateWeightsGradually.selector)) ||
            (actionId == getActionId(InvestmentPool.setSwapEnabled.selector)) ||
            (actionId == getActionId(InvestmentPool.withdrawCollectedManagementFees.selector)) ||
            super._isOwnerOnlyAction(actionId);
    }
    function _calculateWeightChangeProgress() private view returns (uint256) {
        uint256 currentTime = block.timestamp;
        bytes32 poolState = _getMiscData();
        uint256 startTime = poolState.decodeUint32(_START_TIME_OFFSET);
        uint256 endTime = poolState.decodeUint32(_END_TIME_OFFSET);
        if (currentTime >= endTime) {
            return FixedPoint.ONE;
        } else if (currentTime <= startTime) {
            return 0;
        }
        uint256 totalSeconds = endTime - startTime;
        uint256 secondsElapsed = currentTime - startTime;
        return secondsElapsed.divDown(totalSeconds);
    }
    function _interpolateWeight(bytes32 tokenData, uint256 pctProgress) private pure returns (uint256 finalWeight) {
        uint256 startWeight = tokenData.decodeUint64(_START_WEIGHT_OFFSET).uncompress64();
        uint256 endWeight = tokenData.decodeUint32(_END_WEIGHT_OFFSET).uncompress32();
        if (pctProgress == 0 || startWeight == endWeight) return startWeight;
        if (pctProgress >= FixedPoint.ONE) return endWeight;
        if (startWeight > endWeight) {
            uint256 weightDelta = pctProgress.mulDown(startWeight - endWeight);
            return startWeight - weightDelta;
        } else {
            uint256 weightDelta = pctProgress.mulDown(endWeight - startWeight);
            return startWeight + weightDelta;
        }
    }
    function _getTokenData(IERC20 token) private view returns (bytes32 tokenData) {
        tokenData = _tokenState[token];
        _require(tokenData != 0, Errors.INVALID_TOKEN);
    }
}