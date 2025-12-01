pragma solidity 0.8.13;
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { Divider } from "../../../Divider.sol";
import { BaseAdapter } from "../BaseAdapter.sol";
import { IClaimer } from "../IClaimer.sol";
import { FixedMath } from "../../../external/FixedMath.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { Trust } from "@sense-finance/v1-utils/src/Trust.sol";
abstract contract Crops is Trust {
    using SafeTransferLib for ERC20;
    using FixedMath for uint256;
    address public claimer; 
    uint256 public totalTarget; 
    mapping(address => uint256) public tBalance; 
    mapping(address => uint256) public reconciledAmt; 
    mapping(address => mapping(uint256 => bool)) public reconciled; 
    address[] public rewardTokens; 
    mapping(address => Crop) public data;
    struct Crop {
        uint256 shares;
        uint256 rewardedBalances;
        mapping(address => uint256) rewarded;
    }
    constructor(address _divider, address[] memory _rewardTokens) {
        setIsTrusted(_divider, true);
        rewardTokens = _rewardTokens;
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
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            data[rewardTokens[i]].rewarded[_usr] = tBalance[_usr].fmulUp(data[rewardTokens[i]].shares, FixedMath.RAY);
        }
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
    function setRewardTokens(address[] memory _rewardTokens) public requiresTrust {
        _claimRewards();
        rewardTokens = _rewardTokens;
        emit RewardTokensChanged(rewardTokens);
    }
    function setClaimer(address _claimer) public requiresTrust {
        claimer = _claimer;
        emit ClaimerChanged(claimer);
    }
    event Distributed(address indexed usr, address indexed token, uint256 amount);
    event RewardTokensChanged(address[] indexed rewardTokens);
    event Reconciled(address indexed usr, uint256 tBal, uint256 maturity);
    event ClaimerChanged(address indexed claimer);
}