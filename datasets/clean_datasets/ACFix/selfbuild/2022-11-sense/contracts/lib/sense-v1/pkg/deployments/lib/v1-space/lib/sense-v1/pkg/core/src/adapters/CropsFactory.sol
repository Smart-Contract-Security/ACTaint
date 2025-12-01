pragma solidity 0.8.11;
import { CropsAdapter } from "./CropsAdapter.sol";
import { BaseFactory } from "./BaseFactory.sol";
import { Trust } from "@sense-finance/v1-utils/src/Trust.sol";
abstract contract CropsFactory is Trust, BaseFactory {
    constructor(address _divider, FactoryParams memory _factoryParams)
        Trust(msg.sender)
        BaseFactory(_divider, _factoryParams)
    {}
    function setRewardTokens(address[] memory _rewardTokens, address[] memory _adapters) public requiresTrust {
        for (uint256 i = 0; i < _adapters.length; i++) {
            CropsAdapter(_adapters[i]).setRewardTokens(_rewardTokens);
        }
    }
}