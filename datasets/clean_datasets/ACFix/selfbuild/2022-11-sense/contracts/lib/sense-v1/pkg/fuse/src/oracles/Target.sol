pragma solidity 0.8.13;
import { PriceOracle } from "../external/PriceOracle.sol";
import { CToken } from "../external/CToken.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { Trust } from "@sense-finance/v1-utils/src/Trust.sol";
import { Token } from "@sense-finance/v1-core/src/tokens/Token.sol";
import { FixedMath } from "@sense-finance/v1-core/src/external/FixedMath.sol";
import { BaseAdapter as Adapter } from "@sense-finance/v1-core/src/adapters/abstract/BaseAdapter.sol";
contract TargetOracle is PriceOracle, Trust {
    using FixedMath for uint256;
    mapping(address => address) public adapters;
    constructor() Trust(msg.sender) {}
    function setTarget(address target, address adapter) external requiresTrust {
        adapters[target] = adapter;
    }
    function getUnderlyingPrice(CToken cToken) external view override returns (uint256) {
        Token target = Token(cToken.underlying());
        return _price(address(target));
    }
    function price(address target) external view override returns (uint256) {
        return _price(target);
    }
    function _price(address target) internal view returns (uint256) {
        address adapter = adapters[address(target)];
        if (adapter == address(0)) revert Errors.AdapterNotSet();
        uint256 scale = Adapter(adapter).scaleStored();
        return scale.fmul(Adapter(adapter).getUnderlyingPrice());
    }
}