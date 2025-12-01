pragma solidity 0.8.13;
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { IERC3156FlashLender } from "../../external/flashloan/IERC3156FlashLender.sol";
import { IERC3156FlashBorrower } from "../../external/flashloan/IERC3156FlashBorrower.sol";
import { Divider } from "../../Divider.sol";
import { Crop } from "./extensions/Crop.sol";
import { Crops } from "./extensions/Crops.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
abstract contract BaseAdapter is IERC3156FlashLender {
    using SafeTransferLib for ERC20;
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    address public immutable divider;
    address public immutable target;
    address public immutable underlying;
    uint128 public immutable ifee;
    AdapterParams public adapterParams;
    struct AdapterParams {
        address oracle;
        address stake;
        uint256 stakeSize;
        uint256 minm;
        uint256 maxm;
        uint64 tilt;
        uint48 level;
        uint16 mode;
    }
    string public name;
    string public symbol;
    constructor(
        address _divider,
        address _target,
        address _underlying,
        uint128 _ifee,
        AdapterParams memory _adapterParams
    ) {
        divider = _divider;
        target = _target;
        underlying = _underlying;
        ifee = _ifee;
        adapterParams = _adapterParams;
        name = string(abi.encodePacked(ERC20(_target).name(), " Adapter"));
        symbol = string(abi.encodePacked(ERC20(_target).symbol(), "-adapter"));
        ERC20(_target).safeApprove(divider, type(uint256).max);
        ERC20(_adapterParams.stake).safeApprove(divider, type(uint256).max);
    }
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address, 
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        if (Divider(divider).periphery() != msg.sender) revert Errors.OnlyPeriphery();
        ERC20(target).safeTransfer(address(receiver), amount);
        bytes32 keccak = IERC3156FlashBorrower(receiver).onFlashLoan(msg.sender, target, amount, 0, data);
        if (keccak != CALLBACK_SUCCESS) revert Errors.FlashCallbackFailed();
        ERC20(target).safeTransferFrom(address(receiver), address(this), amount);
        return true;
    }
    function scale() external virtual returns (uint256);
    function scaleStored() external view virtual returns (uint256);
    function getUnderlyingPrice() external view virtual returns (uint256);
    function wrapUnderlying(uint256 amount) external virtual returns (uint256);
    function unwrapTarget(uint256 amount) external virtual returns (uint256);
    function flashFee(address token, uint256) external view returns (uint256) {
        if (token != target) revert Errors.TokenNotSupported();
        return 0;
    }
    function maxFlashLoan(address token) external view override returns (uint256) {
        return ERC20(token).balanceOf(address(this));
    }
    function notify(
        address, 
        uint256, 
        bool 
    ) public virtual {
        return;
    }
    function onRedeem(
        uint256, 
        uint256, 
        uint256, 
        uint256 
    ) public virtual {
        return;
    }
    function getMaturityBounds() external view virtual returns (uint256, uint256) {
        return (adapterParams.minm, adapterParams.maxm);
    }
    function getStakeAndTarget()
        external
        view
        returns (
            address,
            address,
            uint256
        )
    {
        return (target, adapterParams.stake, adapterParams.stakeSize);
    }
    function mode() external view returns (uint256) {
        return adapterParams.mode;
    }
    function tilt() external view returns (uint256) {
        return adapterParams.tilt;
    }
    function level() external view returns (uint256) {
        return adapterParams.level;
    }
}