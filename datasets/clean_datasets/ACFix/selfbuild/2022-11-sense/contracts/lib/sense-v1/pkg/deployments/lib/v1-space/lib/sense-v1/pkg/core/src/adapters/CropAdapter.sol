pragma solidity 0.8.11;
import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { SafeTransferLib } from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import { Divider } from "../Divider.sol";
import { BaseAdapter } from "./BaseAdapter.sol";
import { FixedMath } from "../external/FixedMath.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
abstract contract CropAdapter is BaseAdapter {
    using SafeTransferLib for ERC20;
    using FixedMath for uint256;
    address public immutable reward;
    uint256 public share; 
    uint256 public rewardBal; 
    uint256 public totalTarget; 
    mapping(address => uint256) public tBalance; 
    mapping(address => uint256) public rewarded; 
    event Distributed(address indexed usr, address indexed token, uint256 amount);
    constructor(
        address _divider,
        address _target,
        address _underlying,
        uint128 _ifee,
        BaseAdapter.AdapterParams memory _adapterParams,
        address _reward
    ) BaseAdapter(_divider, _target, _underlying, _ifee, _adapterParams) {
        reward = _reward;
    }
    function notify(
        address _usr,
        uint256 amt,
        bool join
    ) public override onlyDivider {
        _distribute(_usr);
        if (amt > 0) {
            if (join) {
                totalTarget += amt;
                tBalance[_usr] += amt;
            } else {
                totalTarget -= amt;
                tBalance[_usr] -= amt;
            }
        }
        rewarded[_usr] = tBalance[_usr].fmulUp(share, FixedMath.RAY);
    }
    function _distribute(address _usr) internal {
        _claimReward();
        uint256 crop = ERC20(reward).balanceOf(address(this)) - rewardBal;
        if (totalTarget > 0) share += (crop.fdiv(totalTarget, FixedMath.RAY));
        uint256 last = rewarded[_usr];
        uint256 curr = tBalance[_usr].fmul(share, FixedMath.RAY);
        if (curr > last) {
            unchecked {
                ERC20(reward).safeTransfer(_usr, curr - last);
            }
        }
        rewardBal = ERC20(reward).balanceOf(address(this));
        emit Distributed(_usr, reward, curr > last ? curr - last : 0);
    }
    function _claimReward() internal virtual {
        return;
    }
    modifier onlyDivider() {
        if (divider != msg.sender) revert Errors.OnlyDivider();
        _;
    }
}