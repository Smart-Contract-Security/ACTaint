pragma solidity 0.8.13;
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { BaseAdapter } from "../BaseAdapter.sol";
import { Divider } from "../../../Divider.sol";
import { FixedMath } from "../../../external/FixedMath.sol";
import { Trust } from "@sense-finance/v1-utils/src/Trust.sol";
interface ERC20 {
    function decimals() external view returns (uint256 decimals);
}
interface ChainlinkOracleLike {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
    function decimals() external view returns (uint256 decimals);
}
abstract contract BaseFactory is Trust {
    using FixedMath for uint256;
    address public constant ETH_USD_PRICEFEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; 
    uint48 public constant DEFAULT_LEVEL = 31;
    address public immutable divider;
    address public restrictedAdmin;
    address public rewardsRecipient;
    FactoryParams public factoryParams;
    struct FactoryParams {
        address oracle; 
        address stake; 
        uint256 stakeSize; 
        uint256 minm; 
        uint256 maxm; 
        uint128 ifee; 
        uint16 mode; 
        uint64 tilt; 
        uint256 guard; 
    }
    constructor(
        address _divider,
        address _restrictedAdmin,
        address _rewardsRecipient,
        FactoryParams memory _factoryParams
    ) Trust(msg.sender) {
        divider = _divider;
        restrictedAdmin = _restrictedAdmin;
        rewardsRecipient = _rewardsRecipient;
        factoryParams = _factoryParams;
    }
    function deployAdapter(address _target, bytes memory _data) external virtual returns (address adapter) {}
    function _setGuard(address _adapter) internal {
        if (Divider(divider).guarded()) {
            BaseAdapter adapter = BaseAdapter(_adapter);
            try adapter.getUnderlyingPrice() returns (uint256 underlyingPriceInEth) {
                (, int256 ethPrice, , uint256 ethUpdatedAt, ) = ChainlinkOracleLike(ETH_USD_PRICEFEED)
                    .latestRoundData();
                if (block.timestamp - ethUpdatedAt > 2 hours) revert Errors.InvalidPrice();
                uint256 price = underlyingPriceInEth.fmul(uint256(ethPrice), 1e8);
                price = adapter.scale().fmul(price);
                Divider(divider).setGuard(
                    _adapter,
                    factoryParams.guard.fdiv(price, 10**ERC20(adapter.target()).decimals())
                );
            } catch {}
        }
    }
    function setRestrictedAdmin(address _restrictedAdmin) external requiresTrust {
        emit RestrictedAdminChanged(restrictedAdmin, _restrictedAdmin);
        restrictedAdmin = _restrictedAdmin;
    }
    function setRewardsRecipient(address _recipient) external requiresTrust {
        emit RewardsRecipientChanged(rewardsRecipient, _recipient);
        rewardsRecipient = _recipient;
    }
    event RewardsRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event RestrictedAdminChanged(address indexed oldAdmin, address indexed newAdmin);
}