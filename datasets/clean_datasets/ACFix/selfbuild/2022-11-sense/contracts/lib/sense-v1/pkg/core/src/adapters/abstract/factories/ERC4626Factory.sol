pragma solidity 0.8.13;
import { Divider } from "../../../Divider.sol";
import { ERC4626Adapter } from "../erc4626/ERC4626Adapter.sol";
import { BaseAdapter } from "../../abstract/BaseAdapter.sol";
import { ExtractableReward } from "../../abstract/extensions/ExtractableReward.sol";
import { BaseFactory } from "./BaseFactory.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { Bytes32AddressLib } from "solmate/utils/Bytes32AddressLib.sol";
contract ERC4626Factory is BaseFactory {
    using Bytes32AddressLib for address;
    mapping(address => bool) public supportedTargets;
    constructor(
        address _divider,
        address _restrictedAdmin,
        address _rewardsRecipient,
        FactoryParams memory _factoryParams
    ) BaseFactory(_divider, _restrictedAdmin, _rewardsRecipient, _factoryParams) {}
    function deployAdapter(address _target, bytes memory data) external override returns (address adapter) {
        if (Divider(divider).periphery() != msg.sender) revert Errors.OnlyPeriphery();
        if (!Divider(divider).permissionless() && !supportedTargets[_target]) revert Errors.TargetNotSupported();
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
            new ERC4626Adapter{ salt: _target.fillLast12Bytes() }(
                divider,
                _target,
                rewardsRecipient,
                factoryParams.ifee,
                adapterParams
            )
        );
        _setGuard(adapter);
        ExtractableReward(adapter).setIsTrusted(restrictedAdmin, true);
    }
    function supportTarget(address _target, bool supported) external requiresTrust {
        supportedTargets[_target] = supported;
        emit TargetSupported(_target, supported);
    }
    function supportTargets(address[] memory _targets, bool supported) external requiresTrust {
        for (uint256 i = 0; i < _targets.length; i++) {
            supportedTargets[_targets[i]] = supported;
            emit TargetSupported(_targets[i], supported);
        }
    }
    event TargetSupported(address indexed target, bool indexed supported);
}