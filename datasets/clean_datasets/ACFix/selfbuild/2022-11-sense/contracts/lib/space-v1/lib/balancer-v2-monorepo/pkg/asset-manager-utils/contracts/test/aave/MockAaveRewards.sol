pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/IERC20.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/ERC20.sol";
import "../../aave/IAaveIncentivesController.sol";
contract MockAaveRewards is IAaveIncentivesController, ERC20("Staked Aave", "stkAAVE") {
    function claimRewards(
        address[] calldata, 
        uint256, 
        address to
    ) external override returns (uint256 rewards) {
        rewards = 1e18;
        _mint(to, rewards);
    }
    function REWARD_TOKEN() external view override returns (address) {
        return address(this);
    }
}