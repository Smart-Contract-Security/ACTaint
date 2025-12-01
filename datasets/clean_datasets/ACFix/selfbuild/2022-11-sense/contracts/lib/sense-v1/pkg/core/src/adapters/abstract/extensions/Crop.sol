pragma solidity 0.8.13;
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { Divider } from "../../../Divider.sol";
import { BaseAdapter } from "../BaseAdapter.sol";
import { IClaimer } from "../IClaimer.sol";
import { FixedMath } from "../../../external/FixedMath.sol";
import { Trust } from "@sense-finance/v1-utils/src/Trust.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
abstract contract Crop is Trust {
    using SafeTransferLib for ERC20;
    using FixedMath for uint256;
    address public claimer; 
    address public reward;
    uint256 public share; 
    uint256 public rewardBal; 
    uint256 public totalTarget; 
    mapping(address => uint256) public tBalance; 
    mapping(address => uint256) public rewarded; 
    mapping(address => uint256) public reconciledAmt; 
    mapping(address => mapping(uint256 => bool)) public reconciled; 
    event Distributed(address indexed usr, address indexed token, uint256 amount);
    constructor(address _divider, address _reward) {
        setIsTrusted(_divider, true);
        reward = _reward;
    }
    function notify(
        address _usr,
        uint256 amt,
        bool join
    ) public virtual requiresTrust {
        _distribute(_usr);
        if (amt > 0) {
            if (join) {
                totalTarget += amt;
                tBalance[_usr] += amt;
            } else {
                uint256 uReconciledAmt = reconciledAmt[_usr];
                if (uReconciledAmt > 0) {
                    if (amt < uReconciledAmt) {
                        unchecked {
                            uReconciledAmt -= amt;
                        }
                        amt = 0;
                    } else {
                        unchecked {
                            amt -= uReconciledAmt;
                        }
                        uReconciledAmt = 0;
                    }
                    reconciledAmt[_usr] = uReconciledAmt;
                }
                if (amt > 0) {
                    totalTarget -= amt;
                    tBalance[_usr] -= amt;
                }
            }
        }
        rewarded[_usr] = tBalance[_usr].fmulUp(share, FixedMath.RAY);
    }
    function reconcile(address[] calldata _usrs, uint256[] calldata _maturities) public {
        Divider divider = Divider(BaseAdapter(address(this)).divider());
        for (uint256 j = 0; j < _maturities.length; j++) {
            for (uint256 i = 0; i < _usrs.length; i++) {
                address usr = _usrs[i];
                uint256 ytBal = ERC20(divider.yt(address(this), _maturities[j])).balanceOf(usr);
                if (_maturities[j] <= block.timestamp && ytBal > 0 && !reconciled[usr][_maturities[j]]) {
                    _distribute(usr);
                    uint256 tBal = ytBal.fdiv(divider.lscales(address(this), _maturities[j], usr));
                    totalTarget -= tBal;
                    tBalance[usr] -= tBal;
                    reconciledAmt[usr] += tBal; 
                    reconciled[usr][_maturities[j]] = true;
                    emit Reconciled(usr, tBal, _maturities[j]);
                }
            }
        }
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
        if (claimer != address(0)) {
            ERC20 target = ERC20(BaseAdapter(address(this)).target());
            uint256 tBal = ERC20(target).balanceOf(address(this));
            if (tBal > 0) {
                ERC20(target).transfer(claimer, tBal);
                IClaimer(claimer).claim();
                if (ERC20(target).balanceOf(address(this)) < tBal) revert Errors.BadContractInteration();
            }
        }
    }
    function setRewardToken(address _reward) public requiresTrust {
        _claimReward();
        reward = _reward;
        emit RewardTokenChanged(reward);
    }
    function setClaimer(address _claimer) public requiresTrust {
        claimer = _claimer;
        emit ClaimerChanged(claimer);
    }
    event Reconciled(address indexed usr, uint256 tBal, uint256 maturity);
    event RewardTokenChanged(address indexed reward);
    event ClaimerChanged(address indexed claimer);
}