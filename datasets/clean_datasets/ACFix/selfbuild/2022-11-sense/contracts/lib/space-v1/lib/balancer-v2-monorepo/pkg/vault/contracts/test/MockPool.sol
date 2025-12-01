pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/IERC20.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IGeneralPool.sol";
import "../interfaces/IMinimalSwapInfoPool.sol";
contract MockPool is IGeneralPool, IMinimalSwapInfoPool {
    using FixedPoint for uint256;
    IVault private immutable _vault;
    bytes32 private immutable _poolId;
    constructor(IVault vault, IVault.PoolSpecialization specialization) {
        _poolId = vault.registerPool(specialization);
        _vault = vault;
    }
    function getVault() external view returns (IVault) {
        return _vault;
    }
    function getPoolId() public view override returns (bytes32) {
        return _poolId;
    }
    function registerTokens(IERC20[] memory tokens, address[] memory assetManagers) external {
        _vault.registerTokens(_poolId, tokens, assetManagers);
    }
    function deregisterTokens(IERC20[] memory tokens) external {
        _vault.deregisterTokens(_poolId, tokens);
    }
    event OnJoinPoolCalled(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] currentBalances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes userData
    );
    event OnExitPoolCalled(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] currentBalances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes userData
    );
    function onJoinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory currentBalances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) external override returns (uint256[] memory amountsIn, uint256[] memory dueProtocolFeeAmounts) {
        emit OnJoinPoolCalled(
            poolId,
            sender,
            recipient,
            currentBalances,
            lastChangeBlock,
            protocolSwapFeePercentage,
            userData
        );
        (amountsIn, dueProtocolFeeAmounts) = abi.decode(userData, (uint256[], uint256[]));
    }
    function onExitPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory currentBalances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) external override returns (uint256[] memory amountsOut, uint256[] memory dueProtocolFeeAmounts) {
        emit OnExitPoolCalled(
            poolId,
            sender,
            recipient,
            currentBalances,
            lastChangeBlock,
            protocolSwapFeePercentage,
            userData
        );
        (amountsOut, dueProtocolFeeAmounts) = abi.decode(userData, (uint256[], uint256[]));
    }
    uint256 private _multiplier = FixedPoint.ONE;
    function setMultiplier(uint256 newMultiplier) external {
        _multiplier = newMultiplier;
    }
    function onSwap(
        SwapRequest memory swapRequest,
        uint256[] memory,
        uint256,
        uint256
    ) external view override returns (uint256 amount) {
        return
            swapRequest.kind == IVault.SwapKind.GIVEN_IN
                ? swapRequest.amount.mulDown(_multiplier)
                : swapRequest.amount.divDown(_multiplier);
    }
    function onSwap(
        SwapRequest memory swapRequest,
        uint256,
        uint256
    ) external view override returns (uint256) {
        return
            swapRequest.kind == IVault.SwapKind.GIVEN_IN
                ? swapRequest.amount.mulDown(_multiplier)
                : swapRequest.amount.divDown(_multiplier);
    }
}