pragma solidity 0.8.11;
import { FixedMath } from "../../external/FixedMath.sol";
import { BaseAdapter } from "../BaseAdapter.sol";
import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { SafeTransferLib } from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
interface WstETHLike {
    function stEthPerToken() external view returns (uint256);
    function unwrap(uint256 _wstETHAmount) external returns (uint256);
    function wrap(uint256 _stETHAmount) external returns (uint256);
}
interface StETHLike {
    function submit(address _referral) external payable returns (uint256);
    function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);
    function balanceOf(address _account) external view returns (uint256);
}
interface CurveStableSwapLike {
    function get_dy(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256);
    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external payable returns (uint256);
}
interface WETHLike {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}
interface StEthPriceFeedLike {
    function safe_price_value() external view returns (uint256);
}
contract WstETHAdapter is BaseAdapter {
    using FixedMath for uint256;
    using SafeTransferLib for ERC20;
    address public constant CETH = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant CURVESINGLESWAP = 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022;
    address public constant STETHPRICEFEED = 0xAb55Bf4DfBf469ebfe082b7872557D1F87692Fe6;
    uint256 public constant SLIPPAGE_TOLERANCE = 0.005e18;
    uint256 public override scaleStored;
    constructor(
        address _divider,
        address _target,
        address _underlying,
        uint128 _ifee,
        BaseAdapter.AdapterParams memory _adapterParams
    ) BaseAdapter(_divider, _target, _underlying, _ifee, _adapterParams) {
        ERC20(STETH).approve(WSTETH, type(uint256).max);
        ERC20(STETH).approve(CURVESINGLESWAP, type(uint256).max);
        scaleStored = _wstEthToEthRate();
    }
    function scale() external virtual override returns (uint256 exRate) {
        exRate = _wstEthToEthRate();
        if (exRate != scaleStored) {
            scaleStored = exRate;
        }
    }
    function getUnderlyingPrice() external pure override returns (uint256 price) {
        price = 1e18;
    }
    function unwrapTarget(uint256 amount) external override returns (uint256 eth) {
        ERC20(WSTETH).safeTransferFrom(msg.sender, address(this), amount); 
        uint256 stEth = WstETHLike(WSTETH).unwrap(amount); 
        uint256 stEthEth = StEthPriceFeedLike(STETHPRICEFEED).safe_price_value(); 
        eth = CurveStableSwapLike(CURVESINGLESWAP).exchange(
            int128(1),
            int128(0),
            stEth,
            stEthEth.fmul(stEth).fmul(FixedMath.WAD - SLIPPAGE_TOLERANCE)
        );
        (bool success, ) = WETH.call{ value: eth }("");
        if (!success) revert Errors.TransferFailed();
        ERC20(WETH).safeTransfer(msg.sender, eth); 
    }
    function wrapUnderlying(uint256 amount) external override returns (uint256 wstETH) {
        ERC20(WETH).safeTransferFrom(msg.sender, address(this), amount); 
        WETHLike(WETH).withdraw(amount); 
        StETHLike(STETH).submit{ value: amount }(address(0)); 
        uint256 stEth = StETHLike(STETH).balanceOf(address(this));
        ERC20(WSTETH).safeTransfer(msg.sender, wstETH = WstETHLike(WSTETH).wrap(stEth)); 
    }
    function _wstEthToEthRate() internal view returns (uint256 exRate) {
        uint256 stEthEth = StEthPriceFeedLike(STETHPRICEFEED).safe_price_value(); 
        uint256 wstETHstETH = StETHLike(STETH).getPooledEthByShares(1 ether); 
        exRate = stEthEth.fmul(wstETHstETH);
    }
    fallback() external payable {
        if (msg.sender != WETH && msg.sender != CURVESINGLESWAP) revert Errors.SenderNotEligible();
    }
}