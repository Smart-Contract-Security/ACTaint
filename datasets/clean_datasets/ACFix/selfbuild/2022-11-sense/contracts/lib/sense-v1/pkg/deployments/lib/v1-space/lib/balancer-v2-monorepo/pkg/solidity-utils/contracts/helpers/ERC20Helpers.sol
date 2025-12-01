pragma solidity ^0.7.0;
import "@balancer-labs/v2-vault/contracts/interfaces/IAsset.sol";
import "../openzeppelin/IERC20.sol";
function _asIAsset(IERC20[] memory tokens) pure returns (IAsset[] memory assets) {
    assembly {
        assets := tokens
    }
}
function _sortTokens(
    IERC20 tokenA,
    IERC20 tokenB,
    IERC20 tokenC
) pure returns (IERC20[] memory tokens) {
    (uint256 indexTokenA, uint256 indexTokenB, uint256 indexTokenC) = _getSortedTokenIndexes(tokenA, tokenB, tokenC);
    tokens = new IERC20[](3);
    tokens[indexTokenA] = tokenA;
    tokens[indexTokenB] = tokenB;
    tokens[indexTokenC] = tokenC;
}
function _getSortedTokenIndexes(
    IERC20 tokenA,
    IERC20 tokenB,
    IERC20 tokenC
)
    pure
    returns (
        uint256 indexTokenA,
        uint256 indexTokenB,
        uint256 indexTokenC
    )
{
    if (tokenA < tokenB) {
        if (tokenB < tokenC) {
            return (0, 1, 2);
        } else if (tokenA < tokenC) {
            return (0, 2, 1);
        } else {
            return (1, 2, 0);
        }
    } else {
        if (tokenC < tokenB) {
            return (2, 1, 0);
        } else if (tokenC < tokenA) {
            return (2, 0, 1);
        } else {
            return (1, 0, 2);
        }
    }
}