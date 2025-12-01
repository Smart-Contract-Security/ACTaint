pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/math/Math.sol";
library BalanceAllocation {
    using Math for uint256;
    function total(bytes32 balance) internal pure returns (uint256) {
        return cash(balance) + managed(balance);
    }
    function cash(bytes32 balance) internal pure returns (uint256) {
        uint256 mask = 2**(112) - 1;
        return uint256(balance) & mask;
    }
    function managed(bytes32 balance) internal pure returns (uint256) {
        uint256 mask = 2**(112) - 1;
        return uint256(balance >> 112) & mask;
    }
    function lastChangeBlock(bytes32 balance) internal pure returns (uint256) {
        uint256 mask = 2**(32) - 1;
        return uint256(balance >> 224) & mask;
    }
    function managedDelta(bytes32 newBalance, bytes32 oldBalance) internal pure returns (int256) {
        return int256(managed(newBalance)) - int256(managed(oldBalance));
    }
    function totalsAndLastChangeBlock(bytes32[] memory balances)
        internal
        pure
        returns (
            uint256[] memory results,
            uint256 lastChangeBlock_ 
        )
    {
        results = new uint256[](balances.length);
        lastChangeBlock_ = 0;
        for (uint256 i = 0; i < results.length; i++) {
            bytes32 balance = balances[i];
            results[i] = total(balance);
            lastChangeBlock_ = Math.max(lastChangeBlock_, lastChangeBlock(balance));
        }
    }
    function isZero(bytes32 balance) internal pure returns (bool) {
        uint256 mask = 2**(224) - 1;
        return (uint256(balance) & mask) == 0;
    }
    function isNotZero(bytes32 balance) internal pure returns (bool) {
        return !isZero(balance);
    }
    function toBalance(
        uint256 _cash,
        uint256 _managed,
        uint256 _blockNumber
    ) internal pure returns (bytes32) {
        uint256 _total = _cash + _managed;
        _require(_total >= _cash && _total < 2**112, Errors.BALANCE_TOTAL_OVERFLOW);
        return _pack(_cash, _managed, _blockNumber);
    }
    function increaseCash(bytes32 balance, uint256 amount) internal view returns (bytes32) {
        uint256 newCash = cash(balance).add(amount);
        uint256 currentManaged = managed(balance);
        uint256 newLastChangeBlock = block.number;
        return toBalance(newCash, currentManaged, newLastChangeBlock);
    }
    function decreaseCash(bytes32 balance, uint256 amount) internal view returns (bytes32) {
        uint256 newCash = cash(balance).sub(amount);
        uint256 currentManaged = managed(balance);
        uint256 newLastChangeBlock = block.number;
        return toBalance(newCash, currentManaged, newLastChangeBlock);
    }
    function cashToManaged(bytes32 balance, uint256 amount) internal pure returns (bytes32) {
        uint256 newCash = cash(balance).sub(amount);
        uint256 newManaged = managed(balance).add(amount);
        uint256 currentLastChangeBlock = lastChangeBlock(balance);
        return toBalance(newCash, newManaged, currentLastChangeBlock);
    }
    function managedToCash(bytes32 balance, uint256 amount) internal pure returns (bytes32) {
        uint256 newCash = cash(balance).add(amount);
        uint256 newManaged = managed(balance).sub(amount);
        uint256 currentLastChangeBlock = lastChangeBlock(balance);
        return toBalance(newCash, newManaged, currentLastChangeBlock);
    }
    function setManaged(bytes32 balance, uint256 newManaged) internal view returns (bytes32) {
        uint256 currentCash = cash(balance);
        uint256 newLastChangeBlock = block.number;
        return toBalance(currentCash, newManaged, newLastChangeBlock);
    }
    function _decodeBalanceA(bytes32 sharedBalance) private pure returns (uint256) {
        uint256 mask = 2**(112) - 1;
        return uint256(sharedBalance) & mask;
    }
    function _decodeBalanceB(bytes32 sharedBalance) private pure returns (uint256) {
        uint256 mask = 2**(112) - 1;
        return uint256(sharedBalance >> 112) & mask;
    }
    function fromSharedToBalanceA(bytes32 sharedCash, bytes32 sharedManaged) internal pure returns (bytes32) {
        return toBalance(_decodeBalanceA(sharedCash), _decodeBalanceA(sharedManaged), lastChangeBlock(sharedCash));
    }
    function fromSharedToBalanceB(bytes32 sharedCash, bytes32 sharedManaged) internal pure returns (bytes32) {
        return toBalance(_decodeBalanceB(sharedCash), _decodeBalanceB(sharedManaged), lastChangeBlock(sharedCash));
    }
    function toSharedCash(bytes32 tokenABalance, bytes32 tokenBBalance) internal pure returns (bytes32) {
        uint32 newLastChangeBlock = uint32(Math.max(lastChangeBlock(tokenABalance), lastChangeBlock(tokenBBalance)));
        return _pack(cash(tokenABalance), cash(tokenBBalance), newLastChangeBlock);
    }
    function toSharedManaged(bytes32 tokenABalance, bytes32 tokenBBalance) internal pure returns (bytes32) {
        return _pack(managed(tokenABalance), managed(tokenBBalance), 0);
    }
    function _pack(
        uint256 _leastSignificant,
        uint256 _midSignificant,
        uint256 _mostSignificant
    ) private pure returns (bytes32) {
        return bytes32((_mostSignificant << 224) + (_midSignificant << 112) + _leastSignificant);
    }
}