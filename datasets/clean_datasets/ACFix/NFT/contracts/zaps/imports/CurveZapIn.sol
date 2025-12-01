pragma solidity 0.5.17;
interface CurveZapIn {
    function ZapIn(
        address toWhomToIssue,
        address fromToken,
        address swapAddress,
        uint256 incomingTokenQty,
        uint256 minPoolTokens
    ) external payable returns (uint256 crvTokensBought);
}