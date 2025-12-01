pragma solidity 0.8.11;
import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { SafeTransferLib } from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { CropAdapter } from "../CropAdapter.sol";
interface WETHLike {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}
interface CTokenLike {
    function exchangeRateCurrent() external returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function decimals() external view returns (uint8);
    function underlying() external view returns (address);
    function mint(uint256 mintAmount) external returns (uint256);
    function redeem(uint256 redeemTokens) external returns (uint256);
}
interface CETHTokenLike {
    function mint() external payable;
}
interface ComptrollerLike {
    function claimComp(address holder, address[] memory cTokens) external;
    function markets(address target)
        external
        returns (
            bool isListed,
            uint256 collateralFactorMantissa,
            bool isComped
        );
    function oracle() external returns (address);
}
interface PriceOracleLike {
    function getUnderlyingPrice(address target) external view returns (uint256);
    function price(address underlying) external view returns (uint256);
}
contract CAdapter is CropAdapter {
    using SafeTransferLib for ERC20;
    address public constant COMPTROLLER = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant CETH = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    bool public immutable isCETH;
    uint8 public immutable uDecimals;
    constructor(
        address _divider,
        address _target,
        address _underlying,
        uint128 _ifee,
        AdapterParams memory _adapterParams,
        address _reward
    ) CropAdapter(_divider, _target, _underlying, _ifee, _adapterParams, _reward) {
        isCETH = _target == CETH;
        ERC20(_underlying).approve(_target, type(uint256).max);
        uDecimals = CTokenLike(_underlying).decimals();
    }
    function scale() external override returns (uint256) {
        uint256 exRate = CTokenLike(target).exchangeRateCurrent();
        return _to18Decimals(exRate);
    }
    function scaleStored() external view override returns (uint256) {
        uint256 exRate = CTokenLike(target).exchangeRateStored();
        return _to18Decimals(exRate);
    }
    function _claimReward() internal virtual override {
        address[] memory cTokens = new address[](1);
        cTokens[0] = target;
        ComptrollerLike(COMPTROLLER).claimComp(address(this), cTokens);
    }
    function getUnderlyingPrice() external view override returns (uint256 price) {
        price = isCETH ? 1e18 : PriceOracleLike(adapterParams.oracle).price(underlying);
    }
    function wrapUnderlying(uint256 uBal) external override returns (uint256 tBal) {
        ERC20 t = ERC20(target);
        ERC20(underlying).safeTransferFrom(msg.sender, address(this), uBal); 
        if (isCETH) WETHLike(WETH).withdraw(uBal); 
        uint256 tBalBefore = t.balanceOf(address(this));
        if (isCETH) {
            CETHTokenLike(target).mint{ value: uBal }();
        } else {
            if (CTokenLike(target).mint(uBal) != 0) revert Errors.MintFailed();
        }
        uint256 tBalAfter = t.balanceOf(address(this));
        t.safeTransfer(msg.sender, tBal = tBalAfter - tBalBefore);
    }
    function unwrapTarget(uint256 tBal) external override returns (uint256 uBal) {
        ERC20 u = ERC20(underlying);
        ERC20(target).safeTransferFrom(msg.sender, address(this), tBal); 
        uint256 uBalBefore = isCETH ? address(this).balance : u.balanceOf(address(this));
        if (CTokenLike(target).redeem(tBal) != 0) revert Errors.RedeemFailed();
        uint256 uBalAfter = isCETH ? address(this).balance : u.balanceOf(address(this));
        unchecked {
            uBal = uBalAfter - uBalBefore;
        }
        if (isCETH) {
            (bool success, ) = WETH.call{ value: uBal }("");
            if (!success) revert Errors.TransferFailed();
        }
        ERC20(underlying).safeTransfer(msg.sender, uBal);
    }
    function _to18Decimals(uint256 exRate) internal view returns (uint256) {
        return uDecimals >= 8 ? exRate / 10**(uDecimals - 8) : exRate * 10**(8 - uDecimals);
    }
    fallback() external payable {}
}