pragma solidity 0.5.17;
interface OneSplitAudit {
    function swap(
        address fromToken,
        address destToken,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata distribution,
        uint256 flags
    ) external payable;
    function getExpectedReturn(
        address fromToken,
        address destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags 
    )
        external
        view
        returns (uint256 returnAmount, uint256[] memory distribution);
}