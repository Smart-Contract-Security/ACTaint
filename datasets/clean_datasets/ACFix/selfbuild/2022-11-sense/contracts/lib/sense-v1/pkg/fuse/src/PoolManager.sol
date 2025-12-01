pragma solidity 0.8.13;
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Bytes32AddressLib } from "solmate/utils/Bytes32AddressLib.sol";
import { PriceOracle } from "./external/PriceOracle.sol";
import { BalancerOracle } from "./external/BalancerOracle.sol";
import { UnderlyingOracle } from "./oracles/Underlying.sol";
import { TargetOracle } from "./oracles/Target.sol";
import { PTOracle } from "./oracles/PT.sol";
import { LPOracle } from "./oracles/LP.sol";
import { Trust } from "@sense-finance/v1-utils/src/Trust.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { Divider } from "@sense-finance/v1-core/src/Divider.sol";
import { BaseAdapter as Adapter } from "@sense-finance/v1-core/src/adapters/abstract/BaseAdapter.sol";
interface FuseDirectoryLike {
    function deployPool(
        string memory name,
        address implementation,
        bool enforceWhitelist,
        uint256 closeFactor,
        uint256 liquidationIncentive,
        address priceOracle
    ) external returns (uint256, address);
}
interface ComptrollerLike {
    function _deployMarket(
        bool isCEther,
        bytes calldata constructorData,
        uint256 collateralFactorMantissa
    ) external returns (uint256);
    function _acceptAdmin() external returns (uint256);
    function cTokensByUnderlying(address underlying) external view returns (address);
    function markets(address cToken) external view returns (bool, uint256);
    function _setBorrowPaused(address cToken, bool state) external returns (bool);
}
interface MasterOracleLike {
    function initialize(
        address[] memory underlyings,
        PriceOracle[] memory _oracles,
        PriceOracle _defaultOracle,
        address _restrictedAdmin,
        bool _canAdminOverwrite
    ) external;
    function add(address[] calldata underlyings, PriceOracle[] calldata _oracles) external;
    function getUnderlyingPrice(address cToken) external view returns (uint256);
}
contract PoolManager is Trust {
    address public immutable comptrollerImpl;
    address public immutable cERC20Impl;
    address public immutable fuseDirectory;
    address public immutable divider;
    address public immutable oracleImpl;
    address public immutable targetOracle;
    address public immutable ptOracle;
    address public immutable lpOracle;
    address public immutable underlyingOracle;
    address public comptroller;
    address public masterOracle;
    AssetParams public targetParams;
    AssetParams public ptParams;
    AssetParams public lpTokenParams;
    mapping(address => mapping(uint256 => Series)) public sSeries;
    enum SeriesStatus {
        NONE,
        QUEUED,
        ADDED
    }
    struct AssetParams {
        address irModel;
        uint256 reserveFactor;
        uint256 collateralFactor;
    }
    struct Series {
        SeriesStatus status;
        address pool;
    }
    constructor(
        address _fuseDirectory,
        address _comptrollerImpl,
        address _cERC20Impl,
        address _divider,
        address _oracleImpl
    ) Trust(msg.sender) {
        fuseDirectory = _fuseDirectory;
        comptrollerImpl = _comptrollerImpl;
        cERC20Impl = _cERC20Impl;
        divider = _divider;
        oracleImpl = _oracleImpl;
        targetOracle = address(new TargetOracle());
        ptOracle = address(new PTOracle());
        lpOracle = address(new LPOracle());
        underlyingOracle = address(new UnderlyingOracle());
    }
    function deployPool(
        string calldata name,
        uint256 closeFactor,
        uint256 liqIncentive,
        address fallbackOracle
    ) external requiresTrust returns (uint256 _poolIndex, address _comptroller) {
        masterOracle = Clones.cloneDeterministic(oracleImpl, Bytes32AddressLib.fillLast12Bytes(address(this)));
        MasterOracleLike(masterOracle).initialize(
            new address[](0),
            new PriceOracle[](0),
            PriceOracle(fallbackOracle), 
            address(this), 
            true 
        );
        (_poolIndex, _comptroller) = FuseDirectoryLike(fuseDirectory).deployPool(
            name,
            comptrollerImpl,
            false, 
            closeFactor,
            liqIncentive,
            masterOracle
        );
        uint256 err = ComptrollerLike(_comptroller)._acceptAdmin();
        if (err != 0) revert Errors.FailedBecomeAdmin();
        comptroller = _comptroller;
        emit PoolDeployed(name, _comptroller, _poolIndex, closeFactor, liqIncentive);
    }
    function addTarget(address target, address adapter) external requiresTrust returns (address cTarget) {
        if (comptroller == address(0)) revert Errors.PoolNotDeployed();
        if (targetParams.irModel == address(0)) revert Errors.TargetParamsNotSet();
        address underlying = Adapter(adapter).underlying();
        address[] memory underlyings = new address[](2);
        underlyings[0] = target;
        underlyings[1] = underlying;
        PriceOracle[] memory oracles = new PriceOracle[](2);
        oracles[0] = PriceOracle(targetOracle);
        oracles[1] = PriceOracle(underlyingOracle);
        UnderlyingOracle(underlyingOracle).setUnderlying(underlying, adapter);
        TargetOracle(targetOracle).setTarget(target, adapter);
        MasterOracleLike(masterOracle).add(underlyings, oracles);
        bytes memory constructorData = abi.encode(
            target,
            comptroller,
            targetParams.irModel,
            ERC20(target).name(),
            ERC20(target).symbol(),
            cERC20Impl,
            hex"", 
            targetParams.reserveFactor,
            0 
        );
        uint256 err = ComptrollerLike(comptroller)._deployMarket(false, constructorData, targetParams.collateralFactor);
        if (err != 0) revert Errors.FailedAddTargetMarket();
        cTarget = ComptrollerLike(comptroller).cTokensByUnderlying(target);
        emit TargetAdded(target, cTarget);
    }
    function queueSeries(
        address adapter,
        uint256 maturity,
        address pool
    ) external requiresTrust {
        if (Divider(divider).pt(adapter, maturity) == address(0)) revert Errors.SeriesDoesNotExist();
        if (sSeries[adapter][maturity].status != SeriesStatus.NONE) revert Errors.DuplicateSeries();
        address cTarget = ComptrollerLike(comptroller).cTokensByUnderlying(Adapter(adapter).target());
        if (cTarget == address(0)) revert Errors.TargetNotInFuse();
        (bool isListed, ) = ComptrollerLike(comptroller).markets(cTarget);
        if (!isListed) revert Errors.TargetNotInFuse();
        sSeries[adapter][maturity] = Series({ status: SeriesStatus.QUEUED, pool: pool });
        emit SeriesQueued(adapter, maturity, pool);
    }
    function addSeries(address adapter, uint256 maturity) external returns (address cPT, address cLPToken) {
        if (sSeries[adapter][maturity].status != SeriesStatus.QUEUED) revert Errors.SeriesNotQueued();
        if (ptParams.irModel == address(0)) revert Errors.PTParamsNotSet();
        if (lpTokenParams.irModel == address(0)) revert Errors.PoolParamsNotSet();
        address pt = Divider(divider).pt(adapter, maturity);
        address pool = sSeries[adapter][maturity].pool;
        (, , , , , , uint256 sampleTs) = BalancerOracle(pool).getSample(BalancerOracle(pool).getTotalSamples() - 1);
        if (sampleTs == 0) revert Errors.OracleNotReady();
        address[] memory underlyings = new address[](2);
        underlyings[0] = pt;
        underlyings[1] = pool;
        PriceOracle[] memory oracles = new PriceOracle[](2);
        oracles[0] = PriceOracle(ptOracle);
        oracles[1] = PriceOracle(lpOracle);
        PTOracle(ptOracle).setPrincipal(pt, pool);
        MasterOracleLike(masterOracle).add(underlyings, oracles);
        bytes memory constructorDataPrincipal = abi.encode(
            pt,
            comptroller,
            ptParams.irModel,
            ERC20(pt).name(),
            ERC20(pt).symbol(),
            cERC20Impl,
            hex"",
            ptParams.reserveFactor,
            0 
        );
        uint256 errPrincipal = ComptrollerLike(comptroller)._deployMarket(
            false,
            constructorDataPrincipal,
            ptParams.collateralFactor
        );
        if (errPrincipal != 0) revert Errors.FailedToAddPTMarket();
        bytes memory constructorDataLpToken = abi.encode(
            pool,
            comptroller,
            lpTokenParams.irModel,
            ERC20(pool).name(),
            ERC20(pool).symbol(),
            cERC20Impl,
            hex"",
            lpTokenParams.reserveFactor,
            0 
        );
        uint256 errLpToken = ComptrollerLike(comptroller)._deployMarket(
            false,
            constructorDataLpToken,
            lpTokenParams.collateralFactor
        );
        if (errLpToken != 0) revert Errors.FailedAddLpMarket();
        cPT = ComptrollerLike(comptroller).cTokensByUnderlying(pt);
        cLPToken = ComptrollerLike(comptroller).cTokensByUnderlying(pool);
        ComptrollerLike(comptroller)._setBorrowPaused(cLPToken, true);
        sSeries[adapter][maturity].status = SeriesStatus.ADDED;
        emit SeriesAdded(pt, pool);
    }
    function setParams(bytes32 what, AssetParams calldata data) external requiresTrust {
        if (what == "PT_PARAMS") ptParams = data;
        else if (what == "LP_TOKEN_PARAMS") lpTokenParams = data;
        else if (what == "TARGET_PARAMS") targetParams = data;
        else revert Errors.InvalidParam();
        emit ParamsSet(what, data);
    }
    function execute(
        address to,
        uint256 value,
        bytes memory data,
        uint256 txGas
    ) external requiresTrust returns (bool success) {
        assembly {
            success := call(txGas, to, value, add(data, 0x20), mload(data), 0, 0)
        }
    }
    event ParamsSet(bytes32 indexed what, AssetParams data);
    event PoolDeployed(string name, address comptroller, uint256 poolIndex, uint256 closeFactor, uint256 liqIncentive);
    event TargetAdded(address indexed target, address indexed cTarget);
    event SeriesQueued(address indexed adapter, uint256 indexed maturity, address indexed pool);
    event SeriesAdded(address indexed pt, address indexed lpToken);
}