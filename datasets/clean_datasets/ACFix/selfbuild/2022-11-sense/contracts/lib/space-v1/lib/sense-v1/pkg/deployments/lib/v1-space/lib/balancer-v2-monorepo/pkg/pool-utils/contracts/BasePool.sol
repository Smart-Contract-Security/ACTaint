pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/math/Math.sol";
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/InputHelpers.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/TemporarilyPausable.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/WordCodec.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/ERC20.sol";
import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
import "@balancer-labs/v2-vault/contracts/interfaces/IBasePool.sol";
import "@balancer-labs/v2-asset-manager-utils/contracts/IAssetManager.sol";
import "./BalancerPoolToken.sol";
import "./BasePoolAuthorization.sol";
abstract contract BasePool is IBasePool, BasePoolAuthorization, BalancerPoolToken, TemporarilyPausable {
    using WordCodec for bytes32;
    using FixedPoint for uint256;
    uint256 private constant _MIN_TOKENS = 2;
    uint256 private constant _MINIMUM_BPT = 1e6;
    uint256 private constant _MIN_SWAP_FEE_PERCENTAGE = 1e12; 
    uint256 private constant _MAX_SWAP_FEE_PERCENTAGE = 1e17; 
    bytes32 private _miscData;
    uint256 private constant _SWAP_FEE_PERCENTAGE_OFFSET = 192;
    IVault private immutable _vault;
    bytes32 private immutable _poolId;
    event SwapFeePercentageChanged(uint256 swapFeePercentage);
    constructor(
        IVault vault,
        IVault.PoolSpecialization specialization,
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        address[] memory assetManagers,
        uint256 swapFeePercentage,
        uint256 pauseWindowDuration,
        uint256 bufferPeriodDuration,
        address owner
    )
        Authentication(bytes32(uint256(msg.sender)))
        BalancerPoolToken(name, symbol)
        BasePoolAuthorization(owner)
        TemporarilyPausable(pauseWindowDuration, bufferPeriodDuration)
    {
        _require(tokens.length >= _MIN_TOKENS, Errors.MIN_TOKENS);
        _require(tokens.length <= _getMaxTokens(), Errors.MAX_TOKENS);
        InputHelpers.ensureArrayIsSorted(tokens);
        _setSwapFeePercentage(swapFeePercentage);
        bytes32 poolId = vault.registerPool(specialization);
        vault.registerTokens(poolId, tokens, assetManagers);
        _vault = vault;
        _poolId = poolId;
    }
    function getVault() public view returns (IVault) {
        return _vault;
    }
    function getPoolId() public view override returns (bytes32) {
        return _poolId;
    }
    function _getTotalTokens() internal view virtual returns (uint256);
    function _getMaxTokens() internal pure virtual returns (uint256);
    function _getMinimumBpt() internal pure virtual returns (uint256) {
        return _MINIMUM_BPT;
    }
    function getSwapFeePercentage() public view returns (uint256) {
        return _miscData.decodeUint64(_SWAP_FEE_PERCENTAGE_OFFSET);
    }
    function setSwapFeePercentage(uint256 swapFeePercentage) external virtual authenticate whenNotPaused {
        _setSwapFeePercentage(swapFeePercentage);
    }
    function _setSwapFeePercentage(uint256 swapFeePercentage) private {
        _require(swapFeePercentage >= _MIN_SWAP_FEE_PERCENTAGE, Errors.MIN_SWAP_FEE_PERCENTAGE);
        _require(swapFeePercentage <= _MAX_SWAP_FEE_PERCENTAGE, Errors.MAX_SWAP_FEE_PERCENTAGE);
        _miscData = _miscData.insertUint64(swapFeePercentage, _SWAP_FEE_PERCENTAGE_OFFSET);
        emit SwapFeePercentageChanged(swapFeePercentage);
    }
    function setAssetManagerPoolConfig(IERC20 token, bytes memory poolConfig)
        public
        virtual
        authenticate
        whenNotPaused
    {
        _setAssetManagerPoolConfig(token, poolConfig);
    }
    function _setAssetManagerPoolConfig(IERC20 token, bytes memory poolConfig) private {
        bytes32 poolId = getPoolId();
        (, , , address assetManager) = getVault().getPoolTokenInfo(poolId, token);
        IAssetManager(assetManager).setConfig(poolId, poolConfig);
    }
    function setPaused(bool paused) external authenticate {
        _setPaused(paused);
    }
    function _isOwnerOnlyAction(bytes32 actionId) internal view virtual override returns (bool) {
        return
            (actionId == getActionId(this.setSwapFeePercentage.selector)) ||
            (actionId == getActionId(this.setAssetManagerPoolConfig.selector));
    }
    function _getMiscData() internal view returns (bytes32) {
        return _miscData;
    }
    function _setMiscData(bytes32 newData) internal {
        _miscData = _miscData.insertBits192(newData, 0);
    }
    modifier onlyVault(bytes32 poolId) {
        _require(msg.sender == address(getVault()), Errors.CALLER_NOT_VAULT);
        _require(poolId == getPoolId(), Errors.INVALID_POOL_ID);
        _;
    }
    function onJoinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) public virtual override onlyVault(poolId) returns (uint256[] memory, uint256[] memory) {
        uint256[] memory scalingFactors = _scalingFactors();
        if (totalSupply() == 0) {
            (uint256 bptAmountOut, uint256[] memory amountsIn) = _onInitializePool(
                poolId,
                sender,
                recipient,
                scalingFactors,
                userData
            );
            _require(bptAmountOut >= _getMinimumBpt(), Errors.MINIMUM_BPT);
            _mintPoolTokens(address(0), _getMinimumBpt());
            _mintPoolTokens(recipient, bptAmountOut - _getMinimumBpt());
            _downscaleUpArray(amountsIn, scalingFactors);
            return (amountsIn, new uint256[](_getTotalTokens()));
        } else {
            _upscaleArray(balances, scalingFactors);
            (uint256 bptAmountOut, uint256[] memory amountsIn, uint256[] memory dueProtocolFeeAmounts) = _onJoinPool(
                poolId,
                sender,
                recipient,
                balances,
                lastChangeBlock,
                protocolSwapFeePercentage,
                scalingFactors,
                userData
            );
            _mintPoolTokens(recipient, bptAmountOut);
            _downscaleUpArray(amountsIn, scalingFactors);
            _downscaleDownArray(dueProtocolFeeAmounts, scalingFactors);
            return (amountsIn, dueProtocolFeeAmounts);
        }
    }
    function onExitPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) public virtual override onlyVault(poolId) returns (uint256[] memory, uint256[] memory) {
        uint256[] memory scalingFactors = _scalingFactors();
        _upscaleArray(balances, scalingFactors);
        (uint256 bptAmountIn, uint256[] memory amountsOut, uint256[] memory dueProtocolFeeAmounts) = _onExitPool(
            poolId,
            sender,
            recipient,
            balances,
            lastChangeBlock,
            protocolSwapFeePercentage,
            scalingFactors,
            userData
        );
        _burnPoolTokens(sender, bptAmountIn);
        _downscaleDownArray(amountsOut, scalingFactors);
        _downscaleDownArray(dueProtocolFeeAmounts, scalingFactors);
        return (amountsOut, dueProtocolFeeAmounts);
    }
    function queryJoin(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) external returns (uint256 bptOut, uint256[] memory amountsIn) {
        InputHelpers.ensureInputLengthMatch(balances.length, _getTotalTokens());
        _queryAction(
            poolId,
            sender,
            recipient,
            balances,
            lastChangeBlock,
            protocolSwapFeePercentage,
            userData,
            _onJoinPool,
            _downscaleUpArray
        );
        return (bptOut, amountsIn);
    }
    function queryExit(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) external returns (uint256 bptIn, uint256[] memory amountsOut) {
        InputHelpers.ensureInputLengthMatch(balances.length, _getTotalTokens());
        _queryAction(
            poolId,
            sender,
            recipient,
            balances,
            lastChangeBlock,
            protocolSwapFeePercentage,
            userData,
            _onExitPool,
            _downscaleDownArray
        );
        return (bptIn, amountsOut);
    }
    function _onInitializePool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal virtual returns (uint256 bptAmountOut, uint256[] memory amountsIn);
    function _onJoinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        uint256[] memory scalingFactors,
        bytes memory userData
    )
        internal
        virtual
        returns (
            uint256 bptAmountOut,
            uint256[] memory amountsIn,
            uint256[] memory dueProtocolFeeAmounts
        );
    function _onExitPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        uint256[] memory scalingFactors,
        bytes memory userData
    )
        internal
        virtual
        returns (
            uint256 bptAmountIn,
            uint256[] memory amountsOut,
            uint256[] memory dueProtocolFeeAmounts
        );
    function _addSwapFeeAmount(uint256 amount) internal view returns (uint256) {
        return amount.divUp(FixedPoint.ONE.sub(getSwapFeePercentage()));
    }
    function _subtractSwapFeeAmount(uint256 amount) internal view returns (uint256) {
        uint256 feeAmount = amount.mulUp(getSwapFeePercentage());
        return amount.sub(feeAmount);
    }
    function _computeScalingFactor(IERC20 token) internal view returns (uint256) {
        uint256 tokenDecimals = ERC20(address(token)).decimals();
        uint256 decimalsDifference = Math.sub(18, tokenDecimals);
        return FixedPoint.ONE * 10**decimalsDifference;
    }
    function _scalingFactor(IERC20 token) internal view virtual returns (uint256);
    function _scalingFactors() internal view virtual returns (uint256[] memory);
    function getScalingFactors() external view returns (uint256[] memory) {
        return _scalingFactors();
    }
    function _upscale(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        return FixedPoint.mulDown(amount, scalingFactor);
    }
    function _upscaleArray(uint256[] memory amounts, uint256[] memory scalingFactors) internal view {
        for (uint256 i = 0; i < _getTotalTokens(); ++i) {
            amounts[i] = FixedPoint.mulDown(amounts[i], scalingFactors[i]);
        }
    }
    function _downscaleDown(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        return FixedPoint.divDown(amount, scalingFactor);
    }
    function _downscaleDownArray(uint256[] memory amounts, uint256[] memory scalingFactors) internal view {
        for (uint256 i = 0; i < _getTotalTokens(); ++i) {
            amounts[i] = FixedPoint.divDown(amounts[i], scalingFactors[i]);
        }
    }
    function _downscaleUp(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        return FixedPoint.divUp(amount, scalingFactor);
    }
    function _downscaleUpArray(uint256[] memory amounts, uint256[] memory scalingFactors) internal view {
        for (uint256 i = 0; i < _getTotalTokens(); ++i) {
            amounts[i] = FixedPoint.divUp(amounts[i], scalingFactors[i]);
        }
    }
    function _getAuthorizer() internal view override returns (IAuthorizer) {
        return getVault().getAuthorizer();
    }
    function _queryAction(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData,
        function(bytes32, address, address, uint256[] memory, uint256, uint256, uint256[] memory, bytes memory)
            internal
            returns (uint256, uint256[] memory, uint256[] memory) _action,
        function(uint256[] memory, uint256[] memory) internal view _downscaleArray
    ) private {
        if (msg.sender != address(this)) {
            (bool success, ) = address(this).call(msg.data);
            assembly {
                switch success
                    case 0 {
                        returndatacopy(0, 0, 0x04)
                        let error := and(mload(0), 0xffffffff00000000000000000000000000000000000000000000000000000000)
                        if eq(eq(error, 0x43adbafb00000000000000000000000000000000000000000000000000000000), 0) {
                            returndatacopy(0, 0, returndatasize())
                            revert(0, returndatasize())
                        }
                        returndatacopy(0, 0x04, 32)
                        mstore(0x20, 64)
                        returndatacopy(0x40, 0x24, sub(returndatasize(), 36))
                        return(0, add(returndatasize(), 28))
                    }
                    default {
                        invalid()
                    }
            }
        } else {
            uint256[] memory scalingFactors = _scalingFactors();
            _upscaleArray(balances, scalingFactors);
            (uint256 bptAmount, uint256[] memory tokenAmounts, ) = _action(
                poolId,
                sender,
                recipient,
                balances,
                lastChangeBlock,
                protocolSwapFeePercentage,
                scalingFactors,
                userData
            );
            _downscaleArray(tokenAmounts, scalingFactors);
            assembly {
                let size := mul(mload(tokenAmounts), 32)
                let start := sub(tokenAmounts, 0x20)
                mstore(start, bptAmount)
                mstore(sub(start, 0x20), 0x0000000000000000000000000000000000000000000000000000000043adbafb)
                start := sub(start, 0x04)
                revert(start, add(size, 68))
            }
        }
    }
}