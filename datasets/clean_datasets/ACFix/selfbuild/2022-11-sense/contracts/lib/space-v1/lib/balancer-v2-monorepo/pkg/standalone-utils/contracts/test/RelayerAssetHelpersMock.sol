pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "../relayer/RelayerAssetHelpers.sol";
contract RelayerAssetHelpersMock is RelayerAssetHelpers {
    constructor(IVault vault) RelayerAssetHelpers(vault) {}
    function approveToken(
        IERC20 token,
        address spender,
        uint256 amount
    ) external {
        _approveToken(token, spender, amount);
    }
    function sweepETH() external {
        _sweepETH();
    }
    function pullToken(
        address sender,
        IERC20 token,
        uint256 amount
    ) external {
        _pullToken(sender, token, amount);
    }
    function pullTokens(
        address sender,
        IERC20[] memory tokens,
        uint256[] memory amounts
    ) external {
        _pullTokens(sender, tokens, amounts);
    }
}