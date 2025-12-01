pragma solidity 0.8.11;
import { CropsFactory } from "../../../adapters/CropsFactory.sol";
import { CropFactory } from "../../../adapters/CropFactory.sol";
import { Divider } from "../../../Divider.sol";
import { MockCropsAdapter, MockAdapter } from "./MockAdapter.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { BaseAdapter } from "../../../adapters/BaseAdapter.sol";
import { Bytes32AddressLib } from "@rari-capital/solmate/src/utils/Bytes32AddressLib.sol";
interface MockTargetLike {
    function underlying() external view returns (address);
}
contract MockFactory is CropFactory {
    using Bytes32AddressLib for address;
    mapping(address => bool) public targets;
    constructor(
        address _divider,
        FactoryParams memory _factoryParams,
        address _reward
    ) CropFactory(_divider, _factoryParams, _reward) {}
    function addTarget(address _target, bool status) external {
        targets[_target] = status;
    }
    function deployAdapter(address _target, bytes memory data) external override returns (address adapter) {
        if (!targets[_target]) revert Errors.TargetNotSupported();
        if (Divider(divider).periphery() != msg.sender) revert Errors.OnlyPeriphery();
        BaseAdapter.AdapterParams memory adapterParams = BaseAdapter.AdapterParams({
            oracle: factoryParams.oracle,
            stake: factoryParams.stake,
            stakeSize: factoryParams.stakeSize,
            minm: factoryParams.minm,
            maxm: factoryParams.maxm,
            mode: factoryParams.mode,
            tilt: factoryParams.tilt,
            level: DEFAULT_LEVEL
        });
        adapter = address(
            new MockAdapter{ salt: _target.fillLast12Bytes() }(
                divider,
                _target,
                MockTargetLike(_target).underlying(),
                factoryParams.ifee,
                adapterParams,
                reward
            )
        );
    }
}
contract MockCropsFactory is CropsFactory {
    using Bytes32AddressLib for address;
    mapping(address => bool) public targets;
    address[] rewardTokens;
    constructor(
        address _divider,
        FactoryParams memory _factoryParams,
        address[] memory _rewardTokens
    ) CropsFactory(_divider, _factoryParams) {
        rewardTokens = _rewardTokens;
    }
    function addTarget(address _target, bool status) external {
        targets[_target] = status;
    }
    function deployAdapter(address _target, bytes memory data) external override returns (address adapter) {
        if (!targets[_target]) revert Errors.TargetNotSupported();
        if (Divider(divider).periphery() != msg.sender) revert Errors.OnlyPeriphery();
        BaseAdapter.AdapterParams memory adapterParams = BaseAdapter.AdapterParams({
            oracle: factoryParams.oracle,
            stake: factoryParams.stake,
            stakeSize: factoryParams.stakeSize,
            minm: factoryParams.minm,
            maxm: factoryParams.maxm,
            mode: factoryParams.mode,
            tilt: factoryParams.tilt,
            level: DEFAULT_LEVEL
        });
        adapter = address(
            new MockCropsAdapter{ salt: _target.fillLast12Bytes() }(
                divider,
                _target,
                MockTargetLike(_target).underlying(),
                factoryParams.ifee,
                adapterParams,
                rewardTokens
            )
        );
    }
}