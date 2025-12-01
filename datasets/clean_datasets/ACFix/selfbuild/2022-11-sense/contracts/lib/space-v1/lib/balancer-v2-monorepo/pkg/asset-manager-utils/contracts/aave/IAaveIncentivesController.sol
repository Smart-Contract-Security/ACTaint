pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
interface IAaveIncentivesController {
    function claimRewards(
        address[] calldata assets,
        uint256 amount,
        address to
    ) external returns (uint256);
    function REWARD_TOKEN() external view returns (address);
}