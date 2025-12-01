pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/helpers/BalancerErrors.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/IERC20.sol";
import "./BalanceAllocation.sol";
import "../PoolRegistry.sol";
abstract contract TwoTokenPoolsBalance is PoolRegistry {
    using BalanceAllocation for bytes32;
    struct TwoTokenPoolBalances {
        bytes32 sharedCash;
        bytes32 sharedManaged;
    }
    struct TwoTokenPoolTokens {
        IERC20 tokenA;
        IERC20 tokenB;
        mapping(bytes32 => TwoTokenPoolBalances) balances;
    }
    mapping(bytes32 => TwoTokenPoolTokens) private _twoTokenPoolTokens;
    function _registerTwoTokenPoolTokens(
        bytes32 poolId,
        IERC20 tokenX,
        IERC20 tokenY
    ) internal {
        _require(tokenX != tokenY, Errors.TOKEN_ALREADY_REGISTERED);
        _require(tokenX < tokenY, Errors.UNSORTED_TOKENS);
        TwoTokenPoolTokens storage poolTokens = _twoTokenPoolTokens[poolId];
        _require(poolTokens.tokenA == IERC20(0) && poolTokens.tokenB == IERC20(0), Errors.TOKENS_ALREADY_SET);
        poolTokens.tokenA = tokenX;
        poolTokens.tokenB = tokenY;
    }
    function _deregisterTwoTokenPoolTokens(
        bytes32 poolId,
        IERC20 tokenX,
        IERC20 tokenY
    ) internal {
        (
            bytes32 balanceA,
            bytes32 balanceB,
            TwoTokenPoolBalances storage poolBalances
        ) = _getTwoTokenPoolSharedBalances(poolId, tokenX, tokenY);
        _require(balanceA.isZero() && balanceB.isZero(), Errors.NONZERO_TOKEN_BALANCE);
        delete _twoTokenPoolTokens[poolId];
        delete poolBalances.sharedCash;
    }
    function _setTwoTokenPoolCashBalances(
        bytes32 poolId,
        IERC20 tokenA,
        bytes32 balanceA,
        IERC20 tokenB,
        bytes32 balanceB
    ) internal {
        bytes32 pairHash = _getTwoTokenPairHash(tokenA, tokenB);
        TwoTokenPoolBalances storage poolBalances = _twoTokenPoolTokens[poolId].balances[pairHash];
        poolBalances.sharedCash = BalanceAllocation.toSharedCash(balanceA, balanceB);
    }
    function _twoTokenPoolCashToManaged(
        bytes32 poolId,
        IERC20 token,
        uint256 amount
    ) internal {
        _updateTwoTokenPoolSharedBalance(poolId, token, BalanceAllocation.cashToManaged, amount);
    }
    function _twoTokenPoolManagedToCash(
        bytes32 poolId,
        IERC20 token,
        uint256 amount
    ) internal {
        _updateTwoTokenPoolSharedBalance(poolId, token, BalanceAllocation.managedToCash, amount);
    }
    function _setTwoTokenPoolManagedBalance(
        bytes32 poolId,
        IERC20 token,
        uint256 amount
    ) internal returns (int256) {
        return _updateTwoTokenPoolSharedBalance(poolId, token, BalanceAllocation.setManaged, amount);
    }
    function _updateTwoTokenPoolSharedBalance(
        bytes32 poolId,
        IERC20 token,
        function(bytes32, uint256) returns (bytes32) mutation,
        uint256 amount
    ) private returns (int256) {
        (
            TwoTokenPoolBalances storage balances,
            IERC20 tokenA,
            bytes32 balanceA,
            ,
            bytes32 balanceB
        ) = _getTwoTokenPoolBalances(poolId);
        int256 delta;
        if (token == tokenA) {
            bytes32 newBalance = mutation(balanceA, amount);
            delta = newBalance.managedDelta(balanceA);
            balanceA = newBalance;
        } else {
            bytes32 newBalance = mutation(balanceB, amount);
            delta = newBalance.managedDelta(balanceB);
            balanceB = newBalance;
        }
        balances.sharedCash = BalanceAllocation.toSharedCash(balanceA, balanceB);
        balances.sharedManaged = BalanceAllocation.toSharedManaged(balanceA, balanceB);
        return delta;
    }
    function _getTwoTokenPoolTokens(bytes32 poolId)
        internal
        view
        returns (IERC20[] memory tokens, bytes32[] memory balances)
    {
        (, IERC20 tokenA, bytes32 balanceA, IERC20 tokenB, bytes32 balanceB) = _getTwoTokenPoolBalances(poolId);
        if (tokenA == IERC20(0) || tokenB == IERC20(0)) {
            return (new IERC20[](0), new bytes32[](0));
        }
        tokens = new IERC20[](2);
        tokens[0] = tokenA;
        tokens[1] = tokenB;
        balances = new bytes32[](2);
        balances[0] = balanceA;
        balances[1] = balanceB;
    }
    function _getTwoTokenPoolBalances(bytes32 poolId)
        private
        view
        returns (
            TwoTokenPoolBalances storage poolBalances,
            IERC20 tokenA,
            bytes32 balanceA,
            IERC20 tokenB,
            bytes32 balanceB
        )
    {
        TwoTokenPoolTokens storage poolTokens = _twoTokenPoolTokens[poolId];
        tokenA = poolTokens.tokenA;
        tokenB = poolTokens.tokenB;
        bytes32 pairHash = _getTwoTokenPairHash(tokenA, tokenB);
        poolBalances = poolTokens.balances[pairHash];
        bytes32 sharedCash = poolBalances.sharedCash;
        bytes32 sharedManaged = poolBalances.sharedManaged;
        balanceA = BalanceAllocation.fromSharedToBalanceA(sharedCash, sharedManaged);
        balanceB = BalanceAllocation.fromSharedToBalanceB(sharedCash, sharedManaged);
    }
    function _getTwoTokenPoolBalance(bytes32 poolId, IERC20 token) internal view returns (bytes32) {
        (, IERC20 tokenA, bytes32 balanceA, IERC20 tokenB, bytes32 balanceB) = _getTwoTokenPoolBalances(poolId);
        if (token == tokenA) {
            return balanceA;
        } else if (token == tokenB) {
            return balanceB;
        } else {
            _revert(Errors.TOKEN_NOT_REGISTERED);
        }
    }
    function _getTwoTokenPoolSharedBalances(
        bytes32 poolId,
        IERC20 tokenX,
        IERC20 tokenY
    )
        internal
        view
        returns (
            bytes32 balanceA,
            bytes32 balanceB,
            TwoTokenPoolBalances storage poolBalances
        )
    {
        (IERC20 tokenA, IERC20 tokenB) = _sortTwoTokens(tokenX, tokenY);
        bytes32 pairHash = _getTwoTokenPairHash(tokenA, tokenB);
        poolBalances = _twoTokenPoolTokens[poolId].balances[pairHash];
        bytes32 sharedCash = poolBalances.sharedCash;
        bytes32 sharedManaged = poolBalances.sharedManaged;
        bool tokensRegistered = sharedCash.isNotZero() ||
            sharedManaged.isNotZero() ||
            (_isTwoTokenPoolTokenRegistered(poolId, tokenA) && _isTwoTokenPoolTokenRegistered(poolId, tokenB));
        if (!tokensRegistered) {
            _ensureRegisteredPool(poolId);
            _revert(Errors.TOKEN_NOT_REGISTERED);
        }
        balanceA = BalanceAllocation.fromSharedToBalanceA(sharedCash, sharedManaged);
        balanceB = BalanceAllocation.fromSharedToBalanceB(sharedCash, sharedManaged);
    }
    function _isTwoTokenPoolTokenRegistered(bytes32 poolId, IERC20 token) internal view returns (bool) {
        TwoTokenPoolTokens storage poolTokens = _twoTokenPoolTokens[poolId];
        return (token == poolTokens.tokenA || token == poolTokens.tokenB) && token != IERC20(0);
    }
    function _getTwoTokenPairHash(IERC20 tokenA, IERC20 tokenB) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(tokenA, tokenB));
    }
    function _sortTwoTokens(IERC20 tokenX, IERC20 tokenY) private pure returns (IERC20, IERC20) {
        return tokenX < tokenY ? (tokenX, tokenY) : (tokenY, tokenX);
    }
}