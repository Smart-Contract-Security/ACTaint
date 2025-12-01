pragma solidity 0.8.17;
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {OwnableUpgradeable, UUPSUpgradeableBase} from "../UUPSUpgradeableBase.sol";
import {ERC1967Proxy} from "../external/openzeppelin/ERC1967/ERC1967Proxy.sol";
import {IProtectionPool, ProtectionPoolParams, ProtectionPoolInfo, ProtectionPoolPhase} from "../interfaces/IProtectionPool.sol";
import {IPremiumCalculator} from "../interfaces/IPremiumCalculator.sol";
import {IReferenceLendingPools} from "../interfaces/IReferenceLendingPools.sol";
import {ProtectionPoolCycleParams, IProtectionPoolCycleManager} from "../interfaces/IProtectionPoolCycleManager.sol";
import {IDefaultStateManager} from "../interfaces/IDefaultStateManager.sol";
import {IReferenceLendingPools, LendingProtocol} from "../interfaces/IReferenceLendingPools.sol";
import {ILendingProtocolAdapter} from "../interfaces/ILendingProtocolAdapter.sol";
import {ILendingProtocolAdapterFactory} from "../interfaces/ILendingProtocolAdapterFactory.sol";
import "../libraries/Constants.sol";
contract ContractFactory is
  UUPSUpgradeableBase,
  ILendingProtocolAdapterFactory
{
  IProtectionPoolCycleManager private protectionPoolCycleManager;
  IDefaultStateManager private defaultStateManager;
  address[] private protectionPools;
  address[] private referenceLendingPoolsList;
  mapping(LendingProtocol => ILendingProtocolAdapter)
    private lendingProtocolAdapters;
  event ProtectionPoolCreated(
    address poolAddress,
    uint256 floor,
    uint256 ceiling,
    IERC20MetadataUpgradeable underlyingToken,
    IReferenceLendingPools referenceLendingPools,
    IPremiumCalculator premiumCalculator
  );
  event ReferenceLendingPoolsCreated(address referenceLendingPools);
  event LendingProtocolAdapterCreated(
    LendingProtocol indexed lendingProtocol,
    address lendingProtocolAdapter
  );
  error LendingProtocolAdapterAlreadyAdded(LendingProtocol protocol);
  function initialize(
    IProtectionPoolCycleManager _protectionPoolCycleManager,
    IDefaultStateManager _defaultStateManager
  ) external initializer {
    __UUPSUpgradeableBase_init();
    protectionPoolCycleManager = _protectionPoolCycleManager;
    defaultStateManager = _defaultStateManager;
  }
  function createProtectionPool(
    address _poolImpl,
    ProtectionPoolParams calldata _poolParameters,
    ProtectionPoolCycleParams calldata _poolCycleParams,
    IERC20MetadataUpgradeable _underlyingToken,
    IReferenceLendingPools _referenceLendingPools,
    IPremiumCalculator _premiumCalculator,
    string calldata _name,
    string calldata _symbol
  ) external payable onlyOwner {
    ERC1967Proxy _poolProxy = new ERC1967Proxy(
      _poolImpl,
      abi.encodeWithSelector(
        IProtectionPool(address(0)).initialize.selector,
        _msgSender(),
        ProtectionPoolInfo({
          params: _poolParameters,
          underlyingToken: _underlyingToken,
          referenceLendingPools: _referenceLendingPools,
          currentPhase: ProtectionPoolPhase.OpenToSellers
        }),
        _premiumCalculator,
        protectionPoolCycleManager,
        defaultStateManager,
        _name,
        _symbol
      )
    );
    address _poolProxyAddress = address(_poolProxy);
    protectionPools.push(_poolProxyAddress);
    protectionPoolCycleManager.registerProtectionPool(
      _poolProxyAddress,
      _poolCycleParams
    );
    defaultStateManager.registerProtectionPool(_poolProxyAddress);
    emit ProtectionPoolCreated(
      _poolProxyAddress,
      _poolParameters.leverageRatioFloor,
      _poolParameters.leverageRatioCeiling,
      _underlyingToken,
      _referenceLendingPools,
      _premiumCalculator
    );
  }
  function createReferenceLendingPools(
    address _referenceLendingPoolsImplementation,
    address[] calldata _lendingPools,
    LendingProtocol[] calldata _lendingPoolProtocols,
    uint256[] calldata _protectionPurchaseLimitsInDays,
    address _lendingProtocolAdapterFactory
  ) external payable onlyOwner {
    ERC1967Proxy _referenceLendingPools = new ERC1967Proxy(
      _referenceLendingPoolsImplementation,
      abi.encodeWithSelector(
        IReferenceLendingPools(address(0)).initialize.selector,
        _msgSender(),
        _lendingPools,
        _lendingPoolProtocols,
        _protectionPurchaseLimitsInDays,
        _lendingProtocolAdapterFactory
      )
    );
    address _referenceLendingPoolsAddress = address(_referenceLendingPools);
    referenceLendingPoolsList.push(_referenceLendingPoolsAddress);
    emit ReferenceLendingPoolsCreated(_referenceLendingPoolsAddress);
  }
  function createLendingProtocolAdapter(
    LendingProtocol _lendingProtocol,
    address _lendingProtocolAdapterImplementation,
    bytes memory _lendingProtocolAdapterInitData
  ) external payable onlyOwner {
    _createLendingProtocolAdapter(
      _lendingProtocol,
      _lendingProtocolAdapterImplementation,
      _lendingProtocolAdapterInitData
    );
  }
  function getProtectionPools() external view returns (address[] memory) {
    return protectionPools;
  }
  function getReferenceLendingPoolsList()
    external
    view
    returns (address[] memory)
  {
    return referenceLendingPoolsList;
  }
  function getLendingProtocolAdapter(LendingProtocol _lendingProtocol)
    external
    view
    returns (ILendingProtocolAdapter)
  {
    return lendingProtocolAdapters[_lendingProtocol];
  }
  function _createLendingProtocolAdapter(
    LendingProtocol _lendingProtocol,
    address _lendingProtocolAdapterImplementation,
    bytes memory _lendingProtocolAdapterInitData
  ) internal {
    if (
      address(lendingProtocolAdapters[_lendingProtocol]) ==
      Constants.ZERO_ADDRESS
    ) {
      address _lendingProtocolAdapterAddress = address(
        new ERC1967Proxy(
          _lendingProtocolAdapterImplementation,
          _lendingProtocolAdapterInitData
        )
      );
      lendingProtocolAdapters[_lendingProtocol] = ILendingProtocolAdapter(
        _lendingProtocolAdapterAddress
      );
      emit LendingProtocolAdapterCreated(
        _lendingProtocol,
        _lendingProtocolAdapterAddress
      );
    } else {
      revert LendingProtocolAdapterAlreadyAdded(_lendingProtocol);
    }
  }
}