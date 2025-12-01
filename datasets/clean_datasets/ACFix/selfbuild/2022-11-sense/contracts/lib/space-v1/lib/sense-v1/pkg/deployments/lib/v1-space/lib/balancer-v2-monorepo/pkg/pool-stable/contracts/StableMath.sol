pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/math/Math.sol";
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
contract StableMath {
    using FixedPoint for uint256;
    uint256 internal constant _MIN_AMP = 1;
    uint256 internal constant _MAX_AMP = 5000;
    uint256 internal constant _AMP_PRECISION = 1e3;
    uint256 internal constant _MAX_STABLE_TOKENS = 5;
    function _calculateInvariant(
        uint256 amplificationParameter,
        uint256[] memory balances,
        bool roundUp
    ) internal pure returns (uint256) {
        uint256 sum = 0;
        uint256 numTokens = balances.length;
        for (uint256 i = 0; i < numTokens; i++) {
            sum = sum.add(balances[i]);
        }
        if (sum == 0) {
            return 0;
        }
        uint256 prevInvariant = 0;
        uint256 invariant = sum;
        uint256 ampTimesTotal = amplificationParameter * numTokens;
        for (uint256 i = 0; i < 255; i++) {
            uint256 P_D = balances[0] * numTokens;
            for (uint256 j = 1; j < numTokens; j++) {
                P_D = Math.div(Math.mul(Math.mul(P_D, balances[j]), numTokens), invariant, roundUp);
            }
            prevInvariant = invariant;
            invariant = Math.div(
                Math.mul(Math.mul(numTokens, invariant), invariant).add(
                    Math.div(Math.mul(Math.mul(ampTimesTotal, sum), P_D), _AMP_PRECISION, roundUp)
                ),
                Math.mul(numTokens + 1, invariant).add(
                    Math.div(Math.mul(ampTimesTotal - _AMP_PRECISION, P_D), _AMP_PRECISION, !roundUp)
                ),
                roundUp
            );
            if (invariant > prevInvariant) {
                if (invariant - prevInvariant <= 1) {
                    return invariant;
                }
            } else if (prevInvariant - invariant <= 1) {
                return invariant;
            }
        }
        _revert(Errors.STABLE_INVARIANT_DIDNT_CONVERGE);
    }
    function _calcOutGivenIn(
        uint256 amplificationParameter,
        uint256[] memory balances,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 tokenAmountIn
    ) internal pure returns (uint256) {
        uint256 invariant = _calculateInvariant(amplificationParameter, balances, true);
        balances[tokenIndexIn] = balances[tokenIndexIn].add(tokenAmountIn);
        uint256 finalBalanceOut = _getTokenBalanceGivenInvariantAndAllOtherBalances(
            amplificationParameter,
            balances,
            invariant,
            tokenIndexOut
        );
        balances[tokenIndexIn] = balances[tokenIndexIn] - tokenAmountIn;
        return balances[tokenIndexOut].sub(finalBalanceOut).sub(1);
    }
    function _calcInGivenOut(
        uint256 amplificationParameter,
        uint256[] memory balances,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 tokenAmountOut
    ) internal pure returns (uint256) {
        uint256 invariant = _calculateInvariant(amplificationParameter, balances, true);
        balances[tokenIndexOut] = balances[tokenIndexOut].sub(tokenAmountOut);
        uint256 finalBalanceIn = _getTokenBalanceGivenInvariantAndAllOtherBalances(
            amplificationParameter,
            balances,
            invariant,
            tokenIndexIn
        );
        balances[tokenIndexOut] = balances[tokenIndexOut] + tokenAmountOut;
        return finalBalanceIn.sub(balances[tokenIndexIn]).add(1);
    }
    function _calcBptOutGivenExactTokensIn(
        uint256 amp,
        uint256[] memory balances,
        uint256[] memory amountsIn,
        uint256 bptTotalSupply,
        uint256 swapFeePercentage
    ) internal pure returns (uint256) {
        uint256 sumBalances = 0;
        for (uint256 i = 0; i < balances.length; i++) {
            sumBalances = sumBalances.add(balances[i]);
        }
        uint256[] memory balanceRatiosWithFee = new uint256[](amountsIn.length);
        uint256 invariantRatioWithFees = 0;
        for (uint256 i = 0; i < balances.length; i++) {
            uint256 currentWeight = balances[i].divDown(sumBalances);
            balanceRatiosWithFee[i] = balances[i].add(amountsIn[i]).divDown(balances[i]);
            invariantRatioWithFees = invariantRatioWithFees.add(balanceRatiosWithFee[i].mulDown(currentWeight));
        }
        uint256[] memory newBalances = new uint256[](balances.length);
        for (uint256 i = 0; i < balances.length; i++) {
            uint256 amountInWithoutFee;
            if (balanceRatiosWithFee[i] > invariantRatioWithFees) {
                uint256 nonTaxableAmount = balances[i].mulDown(invariantRatioWithFees.sub(FixedPoint.ONE));
                uint256 taxableAmount = amountsIn[i].sub(nonTaxableAmount);
                amountInWithoutFee = nonTaxableAmount.add(taxableAmount.mulDown(FixedPoint.ONE - swapFeePercentage));
            } else {
                amountInWithoutFee = amountsIn[i];
            }
            newBalances[i] = balances[i].add(amountInWithoutFee);
        }
        uint256 currentInvariant = _calculateInvariant(amp, balances, true);
        uint256 newInvariant = _calculateInvariant(amp, newBalances, false);
        uint256 invariantRatio = newInvariant.divDown(currentInvariant);
        if (invariantRatio > FixedPoint.ONE) {
            return bptTotalSupply.mulDown(invariantRatio - FixedPoint.ONE);
        } else {
            return 0;
        }
    }
    function _calcTokenInGivenExactBptOut(
        uint256 amp,
        uint256[] memory balances,
        uint256 tokenIndex,
        uint256 bptAmountOut,
        uint256 bptTotalSupply,
        uint256 swapFeePercentage
    ) internal pure returns (uint256) {
        uint256 currentInvariant = _calculateInvariant(amp, balances, true);
        uint256 newInvariant = bptTotalSupply.add(bptAmountOut).divUp(bptTotalSupply).mulUp(currentInvariant);
        uint256 newBalanceTokenIndex = _getTokenBalanceGivenInvariantAndAllOtherBalances(
            amp,
            balances,
            newInvariant,
            tokenIndex
        );
        uint256 amountInWithoutFee = newBalanceTokenIndex.sub(balances[tokenIndex]);
        uint256 sumBalances = 0;
        for (uint256 i = 0; i < balances.length; i++) {
            sumBalances = sumBalances.add(balances[i]);
        }
        uint256 currentWeight = balances[tokenIndex].divDown(sumBalances);
        uint256 taxablePercentage = currentWeight.complement();
        uint256 taxableAmount = amountInWithoutFee.mulUp(taxablePercentage);
        uint256 nonTaxableAmount = amountInWithoutFee.sub(taxableAmount);
        return nonTaxableAmount.add(taxableAmount.divUp(FixedPoint.ONE - swapFeePercentage));
    }
    function _calcBptInGivenExactTokensOut(
        uint256 amp,
        uint256[] memory balances,
        uint256[] memory amountsOut,
        uint256 bptTotalSupply,
        uint256 swapFeePercentage
    ) internal pure returns (uint256) {
        uint256 sumBalances = 0;
        for (uint256 i = 0; i < balances.length; i++) {
            sumBalances = sumBalances.add(balances[i]);
        }
        uint256[] memory balanceRatiosWithoutFee = new uint256[](amountsOut.length);
        uint256 invariantRatioWithoutFees = 0;
        for (uint256 i = 0; i < balances.length; i++) {
            uint256 currentWeight = balances[i].divUp(sumBalances);
            balanceRatiosWithoutFee[i] = balances[i].sub(amountsOut[i]).divUp(balances[i]);
            invariantRatioWithoutFees = invariantRatioWithoutFees.add(balanceRatiosWithoutFee[i].mulUp(currentWeight));
        }
        uint256[] memory newBalances = new uint256[](balances.length);
        for (uint256 i = 0; i < balances.length; i++) {
            uint256 amountOutWithFee;
            if (invariantRatioWithoutFees > balanceRatiosWithoutFee[i]) {
                uint256 nonTaxableAmount = balances[i].mulDown(invariantRatioWithoutFees.complement());
                uint256 taxableAmount = amountsOut[i].sub(nonTaxableAmount);
                amountOutWithFee = nonTaxableAmount.add(taxableAmount.divUp(FixedPoint.ONE - swapFeePercentage));
            } else {
                amountOutWithFee = amountsOut[i];
            }
            newBalances[i] = balances[i].sub(amountOutWithFee);
        }
        uint256 currentInvariant = _calculateInvariant(amp, balances, true);
        uint256 newInvariant = _calculateInvariant(amp, newBalances, false);
        uint256 invariantRatio = newInvariant.divDown(currentInvariant);
        return bptTotalSupply.mulUp(invariantRatio.complement());
    }
    function _calcTokenOutGivenExactBptIn(
        uint256 amp,
        uint256[] memory balances,
        uint256 tokenIndex,
        uint256 bptAmountIn,
        uint256 bptTotalSupply,
        uint256 swapFeePercentage
    ) internal pure returns (uint256) {
        uint256 currentInvariant = _calculateInvariant(amp, balances, true);
        uint256 newInvariant = bptTotalSupply.sub(bptAmountIn).divUp(bptTotalSupply).mulUp(currentInvariant);
        uint256 newBalanceTokenIndex = _getTokenBalanceGivenInvariantAndAllOtherBalances(
            amp,
            balances,
            newInvariant,
            tokenIndex
        );
        uint256 amountOutWithoutFee = balances[tokenIndex].sub(newBalanceTokenIndex);
        uint256 sumBalances = 0;
        for (uint256 i = 0; i < balances.length; i++) {
            sumBalances = sumBalances.add(balances[i]);
        }
        uint256 currentWeight = balances[tokenIndex].divDown(sumBalances);
        uint256 taxablePercentage = currentWeight.complement();
        uint256 taxableAmount = amountOutWithoutFee.mulUp(taxablePercentage);
        uint256 nonTaxableAmount = amountOutWithoutFee.sub(taxableAmount);
        return nonTaxableAmount.add(taxableAmount.mulDown(FixedPoint.ONE - swapFeePercentage));
    }
    function _calcTokensOutGivenExactBptIn(
        uint256[] memory balances,
        uint256 bptAmountIn,
        uint256 bptTotalSupply
    ) internal pure returns (uint256[] memory) {
        uint256 bptRatio = bptAmountIn.divDown(bptTotalSupply);
        uint256[] memory amountsOut = new uint256[](balances.length);
        for (uint256 i = 0; i < balances.length; i++) {
            amountsOut[i] = balances[i].mulDown(bptRatio);
        }
        return amountsOut;
    }
    function _calcDueTokenProtocolSwapFeeAmount(
        uint256 amplificationParameter,
        uint256[] memory balances,
        uint256 lastInvariant,
        uint256 tokenIndex,
        uint256 protocolSwapFeePercentage
    ) internal pure returns (uint256) {
        uint256 finalBalanceFeeToken = _getTokenBalanceGivenInvariantAndAllOtherBalances(
            amplificationParameter,
            balances,
            lastInvariant,
            tokenIndex
        );
        if (balances[tokenIndex] <= finalBalanceFeeToken) {
            return 0;
        }
        uint256 accumulatedTokenSwapFees = balances[tokenIndex] - finalBalanceFeeToken;
        return accumulatedTokenSwapFees.mulDown(protocolSwapFeePercentage).divDown(FixedPoint.ONE);
    }
    function _getTokenBalanceGivenInvariantAndAllOtherBalances(
        uint256 amplificationParameter,
        uint256[] memory balances,
        uint256 invariant,
        uint256 tokenIndex
    ) internal pure returns (uint256) {
        uint256 ampTimesTotal = amplificationParameter * balances.length;
        uint256 sum = balances[0];
        uint256 P_D = balances[0] * balances.length;
        for (uint256 j = 1; j < balances.length; j++) {
            P_D = Math.divDown(Math.mul(Math.mul(P_D, balances[j]), balances.length), invariant);
            sum = sum.add(balances[j]);
        }
        sum = sum - balances[tokenIndex];
        uint256 inv2 = Math.mul(invariant, invariant);
        uint256 c = Math.mul(
            Math.mul(Math.divUp(inv2, Math.mul(ampTimesTotal, P_D)), _AMP_PRECISION),
            balances[tokenIndex]
        );
        uint256 b = sum.add(Math.mul(Math.divDown(invariant, ampTimesTotal), _AMP_PRECISION));
        uint256 prevTokenBalance = 0;
        uint256 tokenBalance = Math.divUp(inv2.add(c), invariant.add(b));
        for (uint256 i = 0; i < 255; i++) {
            prevTokenBalance = tokenBalance;
            tokenBalance = Math.divUp(
                Math.mul(tokenBalance, tokenBalance).add(c),
                Math.mul(tokenBalance, 2).add(b).sub(invariant)
            );
            if (tokenBalance > prevTokenBalance) {
                if (tokenBalance - prevTokenBalance <= 1) {
                    return tokenBalance;
                }
            } else if (prevTokenBalance - tokenBalance <= 1) {
                return tokenBalance;
            }
        }
        _revert(Errors.STABLE_GET_BALANCE_DIDNT_CONVERGE);
    }
}