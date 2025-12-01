pragma solidity 0.8.11;
import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { SafeTransferLib } from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { CropsAdapter } from "../CropsAdapter.sol";
import { CTokenLike } from "../compound/CAdapter.sol";
interface WETHLike {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}
interface FETHTokenLike {
    function mint() external payable;
}
interface FTokenLike {
    function isCEther() external view returns (bool);
}
interface FComptrollerLike {
    function markets(address target) external returns (bool isListed, uint256 collateralFactorMantissa);
    function oracle() external returns (address);
    function getRewardsDistributors() external view returns (address[] memory);
}
interface RewardsDistributorLike {
    function claimRewards(address holder) external;
    function marketState(address marker) external view returns (uint224 index, uint32 lastUpdatedTimestamp);
    function rewardToken() external view returns (address rewardToken);
}
interface PriceOracleLike {
    function getUnderlyingPrice(address target) external view returns (uint256);
    function price(address underlying) external view returns (uint256);
}
contract FAdapter is CropsAdapter {
    using SafeTransferLib for ERC20;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant FETH = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    mapping(address => address) public rewardsDistributorsList; 
    address public comptroller;
    bool public isFETH;
    uint8 public uDecimals;
    constructor(
        address _divider,
        address _target,
        address _underlying,
        uint128 _ifee,
        address _comptroller,
        AdapterParams memory _adapterParams,
        address[] memory _rewardTokens,
        address[] memory _rewardsDistributorsList
    ) CropsAdapter(_divider, _target, _underlying, _ifee, _adapterParams, _rewardTokens) {
        rewardTokens = _rewardTokens;
        comptroller = _comptroller;
        isFETH = FTokenLike(_target).isCEther();
        ERC20(_underlying).approve(_target, type(uint256).max);
        uDecimals = CTokenLike(_underlying).decimals();
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            rewardsDistributorsList[_rewardTokens[i]] = _rewardsDistributorsList[i];
        }
    }
    function scale() external override returns (uint256) {
        uint256 exRate = CTokenLike(target).exchangeRateCurrent();
        return _to18Decimals(exRate);
    }
    function scaleStored() external view override returns (uint256) {
        uint256 exRate = CTokenLike(target).exchangeRateStored();
        return _to18Decimals(exRate);
    }
    function _claimRewards() internal virtual override {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (rewardTokens[i] != address(0))
                RewardsDistributorLike(rewardsDistributorsList[rewardTokens[i]]).claimRewards(address(this));
        }
    }
    function getUnderlyingPrice() external view override returns (uint256 price) {
        price = isFETH ? 1e18 : PriceOracleLike(adapterParams.oracle).price(underlying);
    }
    function wrapUnderlying(uint256 uBal) external override returns (uint256 tBal) {
        ERC20 t = ERC20(target);
        ERC20(underlying).safeTransferFrom(msg.sender, address(this), uBal); 
        if (isFETH) WETHLike(WETH).withdraw(uBal); 
        uint256 tBalBefore = t.balanceOf(address(this));
        if (isFETH) {
            FETHTokenLike(target).mint{ value: uBal }();
        } else {
            if (CTokenLike(target).mint(uBal) != 0) revert Errors.MintFailed();
        }
        uint256 tBalAfter = t.balanceOf(address(this));
        t.safeTransfer(msg.sender, tBal = tBalAfter - tBalBefore);
    }
    function unwrapTarget(uint256 tBal) external override returns (uint256 uBal) {
        ERC20 u = ERC20(underlying);
        ERC20(target).safeTransferFrom(msg.sender, address(this), tBal); 
        uint256 uBalBefore = isFETH ? address(this).balance : u.balanceOf(address(this));
        if (CTokenLike(target).redeem(tBal) != 0) revert Errors.RedeemFailed();
        uint256 uBalAfter = isFETH ? address(this).balance : u.balanceOf(address(this));
        unchecked {
            uBal = uBalAfter - uBalBefore;
        }
        if (isFETH) {
            (bool success, ) = WETH.call{ value: uBal }("");
            if (!success) revert Errors.TransferFailed();
        }
        ERC20(underlying).safeTransfer(msg.sender, uBal);
    }
    function _to18Decimals(uint256 exRate) internal view returns (uint256) {
        return uDecimals >= 8 ? exRate / 10**(uDecimals - 8) : exRate * 10**(8 - uDecimals);
    }
    function setRewardTokens(address[] memory _rewardTokens, address[] memory _rewardsDistributorsList)
        public
        virtual
        requiresTrust
    {
        super.setRewardTokens(_rewardTokens);
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            rewardsDistributorsList[_rewardTokens[i]] = _rewardsDistributorsList[i];
        }
    }
    fallback() external payable {}
}