pragma solidity 0.8.13;
import { Crop } from "../extensions/Crop.sol";
import { BaseFactory } from "./BaseFactory.sol";
abstract contract CropFactory is BaseFactory {
    address public reward;
    constructor(
        address _divider,
        address _restrictedAdmin,
        address _rewardsRecipient,
        FactoryParams memory _factoryParams,
        address _reward
    ) BaseFactory(_divider, _restrictedAdmin, _rewardsRecipient, _factoryParams) {
        reward = _reward;
    }
}