pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import "@balancer-labs/v2-solidity-utils/contracts/math/Math.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/InputHelpers.sol";
contract WeightedMath {
    using FixedPoint for uint256;
    uint256 internal constant _MIN_WEIGHT = 0.01e18;
    uint256 internal constant _MAX_WEIGHTED_TOKENS = 100;
    uint256 internal constant _MAX_IN_RATIO = 0.3e18;
    uint256 internal constant _MAX_OUT_RATIO = 0.3e18;
    uint256 internal constant _MAX_INVARIANT_RATIO = 3e18;
    uint256 internal constant _MIN_INVARIANT_RATIO = 0.7e18;
    function _calculateInvariant(uint256[] memory normalizedWeights, uint256[] memory balances)
        internal
        pure
        returns (uint256 invariant)
    {
        invariant = FixedPoint.ONE;
        for (uint256 i = 0; i < normalizedWeights.length; i++) {
            invariant = invariant.mulDown(balances[i].powDown(normalizedWeights[i]));
        }
        _require(invariant > 0, Errors.ZERO_INVARIANT);
    }
    function _calcOutGivenIn(
        uint256 balanceIn,
        uint256 weightIn,
        uint256 balanceOut,
        uint256 weightOut,
        uint256 amountIn
    ) internal pure returns (uint256) {
        _require(amountIn <= balanceIn.mulDown(_MAX_IN_RATIO), Errors.MAX_IN_RATIO);
        uint256 denominator = balanceIn.add(amountIn);
        uint256 base = balanceIn.divUp(denominator);
        uint256 exponent = weightIn.divDown(weightOut);
        uint256 power = base.powUp(exponent);
        return balanceOut.mulDown(power.complement());
    }
    function _calcInGivenOut(
        uint256 balanceIn,
        uint256 weightIn,
        uint256 balanceOut,
        uint256 weightOut,
        uint256 amountOut
    ) internal pure returns (uint256) {
        _require(amountOut <= balanceOut.mulDown(_MAX_OUT_RATIO), Errors.MAX_OUT_RATIO);
        uint256 base = balanceOut.divUp(balanceOut.sub(amountOut));
        uint256 exponent = weightOut.divUp(weightIn);
        uint256 power = base.powUp(exponent);
        uint256 ratio = power.sub(FixedPoint.ONE);
        return balanceIn.mulUp(ratio);
    }
    function _calcBptOutGivenExactTokensIn(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256[] memory amountsIn,
        uint256 bptTotalSupply,
        uint256 swapFeePercentage
    ) internal pure returns (uint256, uint256[] memory) {
        uint256[] memory balanceRatiosWithFee = new uint256[](amountsIn.length);
        uint256 invariantRatioWithFees = 0;
        for (uint256 i = 0; i < balances.length; i++) {
            balanceRatiosWithFee[i] = balances[i].add(amountsIn[i]).divDown(balances[i]);
            invariantRatioWithFees = invariantRatioWithFees.add(balanceRatiosWithFee[i].mulDown(normalizedWeights[i]));
        }
        (uint256 invariantRatio, uint256[] memory swapFees) = _computeJoinExactTokensInInvariantRatio(
            balances,
            normalizedWeights,
            amountsIn,
            balanceRatiosWithFee,
            invariantRatioWithFees,
            swapFeePercentage
        );
        uint256 bptOut = (invariantRatio > FixedPoint.ONE)
            ? bptTotalSupply.mulDown(invariantRatio.sub(FixedPoint.ONE))
            : 0;
        return (bptOut, swapFees);
    }
    function _computeJoinExactTokensInInvariantRatio(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256[] memory amountsIn,
        uint256[] memory balanceRatiosWithFee,
        uint256 invariantRatioWithFees,
        uint256 swapFeePercentage
    ) private pure returns (uint256 invariantRatio, uint256[] memory swapFees) {
        swapFees = new uint256[](amountsIn.length);
        invariantRatio = FixedPoint.ONE;
        for (uint256 i = 0; i < balances.length; i++) {
            uint256 amountInWithoutFee;
            if (balanceRatiosWithFee[i] > invariantRatioWithFees) {
                uint256 nonTaxableAmount = balances[i].mulDown(invariantRatioWithFees.sub(FixedPoint.ONE));
                uint256 taxableAmount = amountsIn[i].sub(nonTaxableAmount);
                uint256 swapFee = taxableAmount.mulUp(swapFeePercentage);
                amountInWithoutFee = nonTaxableAmount.add(taxableAmount.sub(swapFee));
                swapFees[i] = swapFee;
            } else {
                amountInWithoutFee = amountsIn[i];
            }
            uint256 balanceRatio = balances[i].add(amountInWithoutFee).divDown(balances[i]);
            invariantRatio = invariantRatio.mulDown(balanceRatio.powDown(normalizedWeights[i]));
        }
    }
    function _calcTokenInGivenExactBptOut(
        uint256 balance,
        uint256 normalizedWeight,
        uint256 bptAmountOut,
        uint256 bptTotalSupply,
        uint256 swapFeePercentage
    ) internal pure returns (uint256 amountIn, uint256 swapFee) {
        uint256 invariantRatio = bptTotalSupply.add(bptAmountOut).divUp(bptTotalSupply);
        _require(invariantRatio <= _MAX_INVARIANT_RATIO, Errors.MAX_OUT_BPT_FOR_TOKEN_IN);
        uint256 balanceRatio = invariantRatio.powUp(FixedPoint.ONE.divUp(normalizedWeight));
        uint256 amountInWithoutFee = balance.mulUp(balanceRatio.sub(FixedPoint.ONE));
        uint256 taxablePercentage = normalizedWeight.complement();
        uint256 taxableAmount = amountInWithoutFee.mulUp(taxablePercentage);
        uint256 nonTaxableAmount = amountInWithoutFee.sub(taxableAmount);
        uint256 taxableAmountPlusFees = taxableAmount.divUp(FixedPoint.ONE.sub(swapFeePercentage));
        swapFee = taxableAmountPlusFees - taxableAmount;
        amountIn = nonTaxableAmount.add(taxableAmountPlusFees);
    }
    function _calcAllTokensInGivenExactBptOut(
        uint256[] memory balances,
        uint256 bptAmountOut,
        uint256 totalBPT
    ) internal pure returns (uint256[] memory) {
        uint256 bptRatio = bptAmountOut.divUp(totalBPT);
        uint256[] memory amountsIn = new uint256[](balances.length);
        for (uint256 i = 0; i < balances.length; i++) {
            amountsIn[i] = balances[i].mulUp(bptRatio);
        }
        return amountsIn;
    }
    function _calcBptInGivenExactTokensOut(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256[] memory amountsOut,
        uint256 bptTotalSupply,
        uint256 swapFeePercentage
    ) internal pure returns (uint256, uint256[] memory) {
        uint256[] memory balanceRatiosWithoutFee = new uint256[](amountsOut.length);
        uint256 invariantRatioWithoutFees = 0;
        for (uint256 i = 0; i < balances.length; i++) {
            balanceRatiosWithoutFee[i] = balances[i].sub(amountsOut[i]).divUp(balances[i]);
            invariantRatioWithoutFees = invariantRatioWithoutFees.add(
                balanceRatiosWithoutFee[i].mulUp(normalizedWeights[i])
            );
        }
        (uint256 invariantRatio, uint256[] memory swapFees) = _computeExitExactTokensOutInvariantRatio(
            balances,
            normalizedWeights,
            amountsOut,
            balanceRatiosWithoutFee,
            invariantRatioWithoutFees,
            swapFeePercentage
        );
        uint256 bptIn = bptTotalSupply.mulUp(invariantRatio.complement());
        return (bptIn, swapFees);
    }
    function _computeExitExactTokensOutInvariantRatio(
        uint256[] memory balances,
        uint256[] memory normalizedWeights,
        uint256[] memory amountsOut,
        uint256[] memory balanceRatiosWithoutFee,
        uint256 invariantRatioWithoutFees,
        uint256 swapFeePercentage
    ) private pure returns (uint256 invariantRatio, uint256[] memory swapFees) {
        swapFees = new uint256[](amountsOut.length);
        invariantRatio = FixedPoint.ONE;
        for (uint256 i = 0; i < balances.length; i++) {
            uint256 amountOutWithFee;
            if (invariantRatioWithoutFees > balanceRatiosWithoutFee[i]) {
                uint256 nonTaxableAmount = balances[i].mulDown(invariantRatioWithoutFees.complement());
                uint256 taxableAmount = amountsOut[i].sub(nonTaxableAmount);
                uint256 taxableAmountPlusFees = taxableAmount.divUp(FixedPoint.ONE.sub(swapFeePercentage));
                swapFees[i] = taxableAmountPlusFees - taxableAmount;
                amountOutWithFee = nonTaxableAmount.add(taxableAmountPlusFees);
            } else {
                amountOutWithFee = amountsOut[i];
            }
            uint256 balanceRatio = balances[i].sub(amountOutWithFee).divDown(balances[i]);
            invariantRatio = invariantRatio.mulDown(balanceRatio.powDown(normalizedWeights[i]));
        }
    }
    function _calcTokenOutGivenExactBptIn(
        uint256 balance,
        uint256 normalizedWeight,
        uint256 bptAmountIn,
        uint256 bptTotalSupply,
        uint256 swapFeePercentage
    ) internal pure returns (uint256 amountOut, uint256 swapFee) {
        uint256 invariantRatio = bptTotalSupply.sub(bptAmountIn).divUp(bptTotalSupply);
        _require(invariantRatio >= _MIN_INVARIANT_RATIO, Errors.MIN_BPT_IN_FOR_TOKEN_OUT);
        uint256 balanceRatio = invariantRatio.powUp(FixedPoint.ONE.divDown(normalizedWeight));
        uint256 amountOutWithoutFee = balance.mulDown(balanceRatio.complement());
        uint256 taxablePercentage = normalizedWeight.complement();
        uint256 taxableAmount = amountOutWithoutFee.mulUp(taxablePercentage);
        uint256 nonTaxableAmount = amountOutWithoutFee.sub(taxableAmount);
        swapFee = taxableAmount.mulUp(swapFeePercentage);
        amountOut = nonTaxableAmount.add(taxableAmount.sub(swapFee));
    }
    function _calcTokensOutGivenExactBptIn(
        uint256[] memory balances,
        uint256 bptAmountIn,
        uint256 totalBPT
    ) internal pure returns (uint256[] memory) {
        uint256 bptRatio = bptAmountIn.divDown(totalBPT);
        uint256[] memory amountsOut = new uint256[](balances.length);
        for (uint256 i = 0; i < balances.length; i++) {
            amountsOut[i] = balances[i].mulDown(bptRatio);
        }
        return amountsOut;
    }
    function _calcDueTokenProtocolSwapFeeAmount(
        uint256 balance,
        uint256 normalizedWeight,
        uint256 previousInvariant,
        uint256 currentInvariant,
        uint256 protocolSwapFeePercentage
    ) internal pure returns (uint256) {
        if (currentInvariant <= previousInvariant) {
            return 0;
        }
        uint256 base = previousInvariant.divUp(currentInvariant);
        uint256 exponent = FixedPoint.ONE.divDown(normalizedWeight);
        base = Math.max(base, FixedPoint.MIN_POW_BASE_FREE_EXPONENT);
        uint256 power = base.powUp(exponent);
        uint256 tokenAccruedFees = balance.mulDown(power.complement());
        return tokenAccruedFees.mulDown(protocolSwapFeePercentage);
    }
}