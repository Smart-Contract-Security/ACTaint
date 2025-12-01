pragma solidity 0.8.13;
import "./interfaces/IRewardsManager.sol";
import "./interfaces/IMorpho.sol";
import "./libraries/CompoundMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
contract RewardsManager is IRewardsManager, Initializable {
    using CompoundMath for uint256;
    mapping(address => uint256) public userUnclaimedCompRewards; 
    mapping(address => mapping(address => uint256)) public compSupplierIndex; 
    mapping(address => mapping(address => uint256)) public compBorrowerIndex; 
    mapping(address => IComptroller.CompMarketState) public localCompSupplyState; 
    mapping(address => IComptroller.CompMarketState) public localCompBorrowState; 
    IMorpho public morpho;
    IComptroller public comptroller;
    error OnlyMorpho();
    error InvalidCToken();
    modifier onlyMorpho() {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        _;
    }
    constructor() initializer {}
    function initialize(address _morpho) external initializer {
        morpho = IMorpho(_morpho);
        comptroller = IComptroller(morpho.comptroller());
    }
    function getLocalCompSupplyState(address _cTokenAddress)
        external
        view
        returns (IComptroller.CompMarketState memory)
    {
        return localCompSupplyState[_cTokenAddress];
    }
    function getLocalCompBorrowState(address _cTokenAddress)
        external
        view
        returns (IComptroller.CompMarketState memory)
    {
        return localCompBorrowState[_cTokenAddress];
    }
    function claimRewards(address[] calldata _cTokenAddresses, address _user)
        external
        onlyMorpho
        returns (uint256 totalUnclaimedRewards)
    {
        totalUnclaimedRewards = _accrueUserUnclaimedRewards(_cTokenAddresses, _user);
        if (totalUnclaimedRewards > 0) userUnclaimedCompRewards[_user] = 0;
    }
    function accrueUserSupplyUnclaimedRewards(
        address _user,
        address _cTokenAddress,
        uint256 _userBalance
    ) external onlyMorpho {
        _updateSupplyIndex(_cTokenAddress);
        userUnclaimedCompRewards[_user] += _accrueSupplierComp(_user, _cTokenAddress, _userBalance);
    }
    function accrueUserBorrowUnclaimedRewards(
        address _user,
        address _cTokenAddress,
        uint256 _userBalance
    ) external onlyMorpho {
        _updateBorrowIndex(_cTokenAddress);
        userUnclaimedCompRewards[_user] += _accrueBorrowerComp(_user, _cTokenAddress, _userBalance);
    }
    function _accrueUserUnclaimedRewards(address[] calldata _cTokenAddresses, address _user)
        internal
        returns (uint256 unclaimedRewards)
    {
        unclaimedRewards = userUnclaimedCompRewards[_user];
        for (uint256 i; i < _cTokenAddresses.length; ) {
            address cTokenAddress = _cTokenAddresses[i];
            (bool isListed, , ) = comptroller.markets(cTokenAddress);
            if (!isListed) revert InvalidCToken();
            _updateSupplyIndex(cTokenAddress);
            unclaimedRewards += _accrueSupplierComp(
                _user,
                cTokenAddress,
                morpho.supplyBalanceInOf(cTokenAddress, _user).onPool
            );
            _updateBorrowIndex(cTokenAddress);
            unclaimedRewards += _accrueBorrowerComp(
                _user,
                cTokenAddress,
                morpho.borrowBalanceInOf(cTokenAddress, _user).onPool
            );
            unchecked {
                ++i;
            }
        }
        userUnclaimedCompRewards[_user] = unclaimedRewards;
    }
    function _accrueSupplierComp(
        address _supplier,
        address _cTokenAddress,
        uint256 _balance
    ) internal returns (uint256) {
        uint256 supplyIndex = localCompSupplyState[_cTokenAddress].index;
        uint256 supplierIndex = compSupplierIndex[_cTokenAddress][_supplier];
        compSupplierIndex[_cTokenAddress][_supplier] = supplyIndex;
        if (supplierIndex == 0) return 0;
        return (_balance * (supplyIndex - supplierIndex)) / 1e36;
    }
    function _accrueBorrowerComp(
        address _borrower,
        address _cTokenAddress,
        uint256 _balance
    ) internal returns (uint256) {
        uint256 borrowIndex = localCompBorrowState[_cTokenAddress].index;
        uint256 borrowerIndex = compBorrowerIndex[_cTokenAddress][_borrower];
        compBorrowerIndex[_cTokenAddress][_borrower] = borrowIndex;
        if (borrowerIndex == 0) return 0;
        return (_balance * (borrowIndex - borrowerIndex)) / 1e36;
    }
    function _updateSupplyIndex(address _cTokenAddress) internal {
        IComptroller.CompMarketState storage localSupplyState = localCompSupplyState[
            _cTokenAddress
        ];
        if (localSupplyState.block == block.number) return;
        else {
            IComptroller.CompMarketState memory supplyState = comptroller.compSupplyState(
                _cTokenAddress
            );
            uint256 deltaBlocks = block.number - supplyState.block;
            uint256 supplySpeed = comptroller.compSupplySpeeds(_cTokenAddress);
            uint224 newCompSupplyIndex;
            if (deltaBlocks > 0 && supplySpeed > 0) {
                uint256 supplyTokens = ICToken(_cTokenAddress).totalSupply();
                uint256 compAccrued = deltaBlocks * supplySpeed;
                uint256 ratio = supplyTokens > 0 ? (compAccrued * 1e36) / supplyTokens : 0;
                newCompSupplyIndex = uint224(supplyState.index + ratio);
            } else newCompSupplyIndex = supplyState.index;
            localCompSupplyState[_cTokenAddress] = IComptroller.CompMarketState({
                index: newCompSupplyIndex,
                block: CompoundMath.safe32(block.number)
            });
        }
    }
    function _updateBorrowIndex(address _cTokenAddress) internal {
        IComptroller.CompMarketState storage localBorrowState = localCompBorrowState[
            _cTokenAddress
        ];
        if (localBorrowState.block == block.number) return;
        else {
            IComptroller.CompMarketState memory borrowState = comptroller.compBorrowState(
                _cTokenAddress
            );
            uint256 deltaBlocks = block.number - borrowState.block;
            uint256 borrowSpeed = comptroller.compBorrowSpeeds(_cTokenAddress);
            uint224 newCompBorrowIndex;
            if (deltaBlocks > 0 && borrowSpeed > 0) {
                ICToken cToken = ICToken(_cTokenAddress);
                uint256 borrowAmount = cToken.totalBorrows().div(cToken.borrowIndex());
                uint256 compAccrued = deltaBlocks * borrowSpeed;
                uint256 ratio = borrowAmount > 0 ? (compAccrued * 1e36) / borrowAmount : 0;
                newCompBorrowIndex = uint224(borrowState.index + ratio);
            } else newCompBorrowIndex = borrowState.index;
            localCompBorrowState[_cTokenAddress] = IComptroller.CompMarketState({
                index: newCompBorrowIndex,
                block: CompoundMath.safe32(block.number)
            });
        }
    }
}