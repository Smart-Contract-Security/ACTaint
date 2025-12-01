pragma solidity 0.8.2;
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IYieldSource } from "@pooltogether/yield-source-interface/contracts/IYieldSource.sol";
import { ISavingsContractV2 } from "@mstable/protocol/contracts/interfaces/ISavingsContract.sol";
contract MStableYieldSource is IYieldSource, ReentrancyGuard {
    using SafeERC20 for IERC20;
    ISavingsContractV2 public immutable savings;
    IERC20 public immutable mAsset;
    mapping(address => uint256) public imBalances;
    event Initialized(ISavingsContractV2 indexed savings);
    event Sponsored(address indexed sponsor, uint256 mAssetAmount);
    event Supplied(address indexed from, address indexed to, uint256 amount);
    event Redeemed(address indexed from, uint256 requestedAmount, uint256 actualAmount);
    event ApprovedMax(address indexed from);
    constructor(ISavingsContractV2 _savings) ReentrancyGuard() {
        IERC20 mAssetMemory = IERC20(_savings.underlying());
        mAssetMemory.safeApprove(address(_savings), type(uint256).max);
        savings = _savings;
        mAsset = mAssetMemory;
        emit Initialized(_savings);
    }
    function approveMax() public {
        IERC20(savings.underlying()).safeApprove(address(savings), type(uint256).max);
        emit ApprovedMax(msg.sender);
    }
    function depositToken() public view override returns (address underlyingMasset) {
        underlyingMasset = address(mAsset);
    }
    function balanceOfToken(address addr) external view override returns (uint256 mAssets) {
        uint256 exchangeRate = savings.exchangeRate();
        mAssets = (imBalances[addr] * exchangeRate) / 1e18;
    }
    function supplyTokenTo(uint256 mAssetAmount, address to) external override nonReentrant {
        mAsset.safeTransferFrom(msg.sender, address(this), mAssetAmount);
        uint256 creditsIssued = savings.depositSavings(mAssetAmount);
        imBalances[to] += creditsIssued;
        emit Supplied(msg.sender, to, mAssetAmount);
    }
    function redeemToken(uint256 mAssetAmount)
        external
        override
        nonReentrant
        returns (uint256 mAssetsActual)
    {
        uint256 mAssetBalanceBefore = mAsset.balanceOf(address(this));
        uint256 creditsBurned = savings.redeemUnderlying(mAssetAmount);
        imBalances[msg.sender] -= creditsBurned;
        uint256 mAssetBalanceAfter = mAsset.balanceOf(address(this));
        mAssetsActual = mAssetBalanceAfter - mAssetBalanceBefore;
        mAsset.safeTransfer(msg.sender, mAssetsActual);
        emit Redeemed(msg.sender, mAssetAmount, mAssetsActual);
    }
}