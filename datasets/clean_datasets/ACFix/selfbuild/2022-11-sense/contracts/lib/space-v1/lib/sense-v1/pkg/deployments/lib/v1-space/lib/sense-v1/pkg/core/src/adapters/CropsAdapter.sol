pragma solidity 0.8.11;
import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { SafeTransferLib } from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import { Divider } from "../Divider.sol";
import { BaseAdapter } from "./BaseAdapter.sol";
import { FixedMath } from "../external/FixedMath.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { Trust } from "@sense-finance/v1-utils/src/Trust.sol";
abstract contract CropsAdapter is Trust, BaseAdapter {
    using SafeTransferLib for ERC20;
    using FixedMath for uint256;
    uint256 public totalTarget;
    mapping(address => uint256) public tBalance;
    address[] public rewardTokens;
    mapping(address => Crop) public data;
    struct Crop {
        uint256 shares;
        uint256 rewardedBalances;
        mapping(address => uint256) rewarded;
    }
    constructor(
        address _divider,
        address _target,
        address _underlying,
        uint128 _ifee,
        BaseAdapter.AdapterParams memory _adapterParams,
        address[] memory _rewardTokens
    ) Trust(msg.sender) BaseAdapter(_divider, _target, _underlying, _ifee, _adapterParams) {
        rewardTokens = _rewardTokens;
    }
    function notify(
        address _usr,
        uint256 amt,
        bool join
    ) public override {
        if (divider != msg.sender) revert Errors.OnlyDivider();
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
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            data[rewardTokens[i]].rewarded[_usr] = tBalance[_usr].fmulUp(data[rewardTokens[i]].shares, FixedMath.RAY);
        }
    }
    function _distribute(address _usr) internal {
        _claimRewards();
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            uint256 crop = ERC20(rewardTokens[i]).balanceOf(address(this)) - data[rewardTokens[i]].rewardedBalances;
            if (totalTarget > 0) data[rewardTokens[i]].shares += (crop.fdiv(totalTarget, FixedMath.RAY));
            uint256 last = data[rewardTokens[i]].rewarded[_usr];
            uint256 curr = tBalance[_usr].fmul(data[rewardTokens[i]].shares, FixedMath.RAY);
            if (curr > last) {
                unchecked {
                    ERC20(rewardTokens[i]).safeTransfer(_usr, curr - last);
                }
            }
            data[rewardTokens[i]].rewardedBalances = ERC20(rewardTokens[i]).balanceOf(address(this));
            emit Distributed(_usr, rewardTokens[i], curr > last ? curr - last : 0);
        }
    }
    function _claimRewards() internal virtual {
        return;
    }
    function setRewardTokens(address[] memory _rewardTokens) public requiresTrust {
        _claimRewards();
        rewardTokens = _rewardTokens;
    }
    event Distributed(address indexed usr, address indexed token, uint256 amount);
}