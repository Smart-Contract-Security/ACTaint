pragma solidity 0.8.13;
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ReentrancyGuard } from "solmate/utils/ReentrancyGuard.sol";
import { DateTime } from "./external/DateTime.sol";
import { FixedMath } from "./external/FixedMath.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { Levels } from "@sense-finance/v1-utils/src/libs/Levels.sol";
import { Trust } from "@sense-finance/v1-utils/src/Trust.sol";
import { YT } from "./tokens/YT.sol";
import { Token } from "./tokens/Token.sol";
import { BaseAdapter as Adapter } from "./adapters/abstract/BaseAdapter.sol";
contract Divider is Trust, ReentrancyGuard, Pausable {
    using SafeTransferLib for ERC20;
    using FixedMath for uint256;
    using Levels for uint256;
    uint256 public constant SPONSOR_WINDOW = 3 hours;
    uint256 public constant SETTLEMENT_WINDOW = 3 hours;
    uint256 public constant ISSUANCE_FEE_CAP = 0.05e18;
    address public periphery;
    address public immutable cup;
    address public immutable tokenHandler;
    bool public permissionless;
    bool public guarded = true;
    uint248 public adapterCounter;
    mapping(uint256 => address) public adapterAddresses;
    mapping(address => AdapterMeta) public adapterMeta;
    mapping(address => mapping(uint256 => Series)) public series;
    mapping(address => mapping(uint256 => mapping(address => uint256))) public lscales;
    struct Series {
        address pt;
        uint48 issuance;
        address yt;
        uint96 tilt;
        address sponsor;
        uint256 reward;
        uint256 iscale;
        uint256 mscale;
        uint256 maxscale;
    }
    struct AdapterMeta {
        uint248 id;
        bool enabled;
        uint256 guard;
        uint248 level;
    }
    constructor(address _cup, address _tokenHandler) Trust(msg.sender) {
        cup = _cup;
        tokenHandler = _tokenHandler;
    }
    function addAdapter(address adapter) external whenNotPaused {
        if (!permissionless && msg.sender != periphery) revert Errors.OnlyPermissionless();
        if (adapterMeta[adapter].id > 0 && !adapterMeta[adapter].enabled) revert Errors.InvalidAdapter();
        _setAdapter(adapter, true);
    }
    function initSeries(
        address adapter,
        uint256 maturity,
        address sponsor
    ) external nonReentrant whenNotPaused returns (address pt, address yt) {
        if (periphery != msg.sender) revert Errors.OnlyPeriphery();
        if (!adapterMeta[adapter].enabled) revert Errors.InvalidAdapter();
        if (_exists(adapter, maturity)) revert Errors.DuplicateSeries();
        if (!_isValid(adapter, maturity)) revert Errors.InvalidMaturity();
        (address target, address stake, uint256 stakeSize) = Adapter(adapter).getStakeAndTarget();
        (pt, yt) = TokenHandler(tokenHandler).deploy(adapter, adapterMeta[adapter].id, maturity);
        uint256 scale = Adapter(adapter).scale();
        series[adapter][maturity].pt = pt;
        series[adapter][maturity].issuance = uint48(block.timestamp);
        series[adapter][maturity].yt = yt;
        series[adapter][maturity].tilt = uint96(Adapter(adapter).tilt());
        series[adapter][maturity].sponsor = sponsor;
        series[adapter][maturity].iscale = scale;
        series[adapter][maturity].maxscale = scale;
        ERC20(stake).safeTransferFrom(msg.sender, adapter, stakeSize);
        emit SeriesInitialized(adapter, maturity, pt, yt, sponsor, target);
    }
    function settleSeries(address adapter, uint256 maturity) external nonReentrant whenNotPaused {
        if (!adapterMeta[adapter].enabled) revert Errors.InvalidAdapter();
        if (!_exists(adapter, maturity)) revert Errors.SeriesDoesNotExist();
        if (_settled(adapter, maturity)) revert Errors.AlreadySettled();
        if (!_canBeSettled(adapter, maturity)) revert Errors.OutOfWindowBoundaries();
        uint256 mscale = Adapter(adapter).scale();
        series[adapter][maturity].mscale = mscale;
        if (mscale > series[adapter][maturity].maxscale) {
            series[adapter][maturity].maxscale = mscale;
        }
        (address target, address stake, uint256 stakeSize) = Adapter(adapter).getStakeAndTarget();
        ERC20(target).safeTransferFrom(adapter, msg.sender, series[adapter][maturity].reward);
        ERC20(stake).safeTransferFrom(adapter, msg.sender, stakeSize);
        emit SeriesSettled(adapter, maturity, msg.sender);
    }
    function issue(
        address adapter,
        uint256 maturity,
        uint256 tBal
    ) external nonReentrant whenNotPaused returns (uint256 uBal) {
        if (!adapterMeta[adapter].enabled) revert Errors.InvalidAdapter();
        if (!_exists(adapter, maturity)) revert Errors.SeriesDoesNotExist();
        if (_settled(adapter, maturity)) revert Errors.IssueOnSettle();
        uint256 level = adapterMeta[adapter].level;
        if (level.issueRestricted() && msg.sender != adapter) revert Errors.IssuanceRestricted();
        ERC20 target = ERC20(Adapter(adapter).target());
        uint256 issuanceFee = Adapter(adapter).ifee();
        if (issuanceFee > ISSUANCE_FEE_CAP) revert Errors.IssuanceFeeCapExceeded();
        uint256 fee = tBal.fmul(issuanceFee);
        unchecked {
            series[adapter][maturity].reward += fee;
        }
        uint256 tBalSubFee = tBal - fee;
        unchecked {
            if (guarded && target.balanceOf(adapter) + tBal > adapterMeta[address(adapter)].guard)
                revert Errors.GuardCapReached();
        }
        Adapter(adapter).notify(msg.sender, tBalSubFee, true);
        uint256 scale = level.collectDisabled() ? series[adapter][maturity].iscale : Adapter(adapter).scale();
        uBal = tBalSubFee.fmul(scale);
        lscales[adapter][maturity][msg.sender] = lscales[adapter][maturity][msg.sender] == 0
            ? scale
            : _reweightLScale(
                adapter,
                maturity,
                YT(series[adapter][maturity].yt).balanceOf(msg.sender),
                uBal,
                msg.sender,
                scale
            );
        Token(series[adapter][maturity].pt).mint(msg.sender, uBal);
        YT(series[adapter][maturity].yt).mint(msg.sender, uBal);
        target.safeTransferFrom(msg.sender, adapter, tBal);
        emit Issued(adapter, maturity, uBal, msg.sender);
    }
    function combine(
        address adapter,
        uint256 maturity,
        uint256 uBal
    ) external nonReentrant whenNotPaused returns (uint256 tBal) {
        if (!adapterMeta[adapter].enabled) revert Errors.InvalidAdapter();
        if (!_exists(adapter, maturity)) revert Errors.SeriesDoesNotExist();
        uint256 level = adapterMeta[adapter].level;
        if (level.combineRestricted() && msg.sender != adapter) revert Errors.CombineRestricted();
        Token(series[adapter][maturity].pt).burn(msg.sender, uBal);
        uint256 collected = _collect(msg.sender, adapter, maturity, uBal, uBal, address(0));
        uint256 cscale = series[adapter][maturity].mscale;
        bool settled = _settled(adapter, maturity);
        if (!settled) {
            YT(series[adapter][maturity].yt).burn(msg.sender, uBal);
            cscale = level.collectDisabled()
                ? series[adapter][maturity].iscale
                : lscales[adapter][maturity][msg.sender];
        }
        tBal = uBal.fdiv(cscale);
        ERC20(Adapter(adapter).target()).safeTransferFrom(adapter, msg.sender, tBal);
        if (!settled) Adapter(adapter).notify(msg.sender, tBal, false);
        unchecked {
            tBal += collected;
        }
        emit Combined(adapter, maturity, tBal, msg.sender);
    }
    function redeem(
        address adapter,
        uint256 maturity,
        uint256 uBal
    ) external nonReentrant whenNotPaused returns (uint256 tBal) {
        if (!_settled(adapter, maturity)) revert Errors.NotSettled();
        uint256 level = adapterMeta[adapter].level;
        if (level.redeemRestricted() && msg.sender != adapter) revert Errors.RedeemRestricted();
        Token(series[adapter][maturity].pt).burn(msg.sender, uBal);
        uint256 zShare = FixedMath.WAD - series[adapter][maturity].tilt;
        if (series[adapter][maturity].mscale.fdiv(series[adapter][maturity].maxscale) >= zShare) {
            tBal = (uBal * zShare) / series[adapter][maturity].mscale;
        } else {
            tBal = uBal.fdiv(series[adapter][maturity].maxscale);
        }
        if (!level.redeemHookDisabled()) {
            Adapter(adapter).onRedeem(uBal, series[adapter][maturity].mscale, series[adapter][maturity].maxscale, tBal);
        }
        ERC20(Adapter(adapter).target()).safeTransferFrom(adapter, msg.sender, tBal);
        emit PTRedeemed(adapter, maturity, tBal);
    }
    function collect(
        address usr,
        address adapter,
        uint256 maturity,
        uint256 uBalTransfer,
        address to
    ) external nonReentrant onlyYT(adapter, maturity) whenNotPaused returns (uint256 collected) {
        uint256 uBal = YT(msg.sender).balanceOf(usr);
        return _collect(usr, adapter, maturity, uBal, uBalTransfer > 0 ? uBalTransfer : uBal, to);
    }
    function _collect(
        address usr,
        address adapter,
        uint256 maturity,
        uint256 uBal,
        uint256 uBalTransfer,
        address to
    ) internal returns (uint256 collected) {
        if (!_exists(adapter, maturity)) revert Errors.SeriesDoesNotExist();
        if (!adapterMeta[adapter].enabled && !_settled(adapter, maturity)) revert Errors.InvalidAdapter();
        Series memory _series = series[adapter][maturity];
        uint256 lscale = lscales[adapter][maturity][usr];
        uint256 level = adapterMeta[adapter].level;
        if (level.collectDisabled()) {
            if (_settled(adapter, maturity)) {
                lscale = series[adapter][maturity].iscale;
            } else {
                return 0;
            }
        }
        if (_settled(adapter, maturity)) {
            _redeemYT(usr, adapter, maturity, uBal);
        } else {
            if (block.timestamp > maturity + SPONSOR_WINDOW) {
                revert Errors.CollectNotSettled();
            } else {
                uint256 cscale = Adapter(adapter).scale();
                if (cscale > _series.maxscale) {
                    _series.maxscale = cscale;
                    lscales[adapter][maturity][usr] = cscale;
                } else {
                    lscales[adapter][maturity][usr] = _series.maxscale;
                }
            }
        }
        uint256 tBalNow = uBal.fdivUp(_series.maxscale); 
        uint256 tBalPrev = uBal.fdiv(lscale);
        unchecked {
            collected = tBalPrev > tBalNow ? tBalPrev - tBalNow : 0;
        }
        ERC20(Adapter(adapter).target()).safeTransferFrom(adapter, usr, collected);
        Adapter(adapter).notify(usr, collected, false); 
        if (to != address(0)) {
            uint256 ytBal = YT(_series.yt).balanceOf(to);
            lscales[adapter][maturity][to] = ytBal > 0
                ? _reweightLScale(adapter, maturity, ytBal, uBalTransfer, to, _series.maxscale)
                : _series.maxscale;
            uint256 tBalTransfer = uBalTransfer.fdiv(_series.maxscale);
            Adapter(adapter).notify(usr, tBalTransfer, false);
            Adapter(adapter).notify(to, tBalTransfer, true);
        }
        series[adapter][maturity] = _series;
        emit Collected(adapter, maturity, collected);
    }
    function _reweightLScale(
        address adapter,
        uint256 maturity,
        uint256 ytBal,
        uint256 uBal,
        address receiver,
        uint256 scale
    ) internal view returns (uint256) {
        return (ytBal + uBal).fdiv((ytBal.fdiv(lscales[adapter][maturity][receiver]) + uBal.fdiv(scale)));
    }
    function _redeemYT(
        address usr,
        address adapter,
        uint256 maturity,
        uint256 uBal
    ) internal {
        YT(series[adapter][maturity].yt).burn(usr, uBal);
        uint256 tBal = 0;
        uint256 zShare = FixedMath.WAD - series[adapter][maturity].tilt;
        if (series[adapter][maturity].mscale.fdiv(series[adapter][maturity].maxscale) >= zShare) {
            tBal = uBal.fdiv(series[adapter][maturity].maxscale) - (uBal * zShare) / series[adapter][maturity].mscale;
            ERC20(Adapter(adapter).target()).safeTransferFrom(adapter, usr, tBal);
        }
        Adapter(adapter).notify(usr, uBal.fdivUp(series[adapter][maturity].maxscale), false);
        emit YTRedeemed(adapter, maturity, tBal);
    }
    function setAdapter(address adapter, bool isOn) public requiresTrust {
        _setAdapter(adapter, isOn);
    }
    function setGuard(address adapter, uint256 cap) external requiresTrust {
        adapterMeta[adapter].guard = cap;
        emit GuardChanged(adapter, cap);
    }
    function setGuarded(bool _guarded) external requiresTrust {
        guarded = _guarded;
        emit GuardedChanged(_guarded);
    }
    function setPeriphery(address _periphery) external requiresTrust {
        periphery = _periphery;
        emit PeripheryChanged(_periphery);
    }
    function setPaused(bool _paused) external requiresTrust {
        _paused ? _pause() : _unpause();
    }
    function setPermissionless(bool _permissionless) external requiresTrust {
        permissionless = _permissionless;
        emit PermissionlessChanged(_permissionless);
    }
    function backfillScale(
        address adapter,
        uint256 maturity,
        uint256 mscale,
        address[] calldata _usrs,
        uint256[] calldata _lscales
    ) external requiresTrust {
        if (!_exists(adapter, maturity)) revert Errors.SeriesDoesNotExist();
        uint256 cutoff = maturity + SPONSOR_WINDOW + SETTLEMENT_WINDOW;
        if (block.timestamp <= cutoff) revert Errors.OutOfWindowBoundaries();
        for (uint256 i = 0; i < _usrs.length; i++) {
            lscales[adapter][maturity][_usrs[i]] = _lscales[i];
        }
        if (mscale > 0) {
            Series memory _series = series[adapter][maturity];
            series[adapter][maturity].mscale = mscale;
            if (mscale > _series.maxscale) {
                series[adapter][maturity].maxscale = mscale;
            }
            (address target, address stake, uint256 stakeSize) = Adapter(adapter).getStakeAndTarget();
            address stakeDst = adapterMeta[adapter].enabled ? cup : _series.sponsor;
            ERC20(target).safeTransferFrom(adapter, cup, _series.reward);
            series[adapter][maturity].reward = 0;
            ERC20(stake).safeTransferFrom(adapter, stakeDst, stakeSize);
        }
        emit Backfilled(adapter, maturity, mscale, _usrs, _lscales);
    }
    function _exists(address adapter, uint256 maturity) internal view returns (bool) {
        return series[adapter][maturity].pt != address(0);
    }
    function _settled(address adapter, uint256 maturity) internal view returns (bool) {
        return series[adapter][maturity].mscale > 0;
    }
    function _canBeSettled(address adapter, uint256 maturity) internal view returns (bool) {
        uint256 cutoff = maturity + SPONSOR_WINDOW + SETTLEMENT_WINDOW;
        if (msg.sender == series[adapter][maturity].sponsor) {
            return maturity - SPONSOR_WINDOW <= block.timestamp && cutoff >= block.timestamp;
        } else {
            return maturity + SPONSOR_WINDOW < block.timestamp && cutoff >= block.timestamp;
        }
    }
    function _isValid(address adapter, uint256 maturity) internal view returns (bool) {
        (uint256 minm, uint256 maxm) = Adapter(adapter).getMaturityBounds();
        if (maturity < block.timestamp + minm || maturity > block.timestamp + maxm) return false;
        (, , uint256 day, uint256 hour, uint256 minute, uint256 second) = DateTime.timestampToDateTime(maturity);
        if (hour != 0 || minute != 0 || second != 0) return false;
        uint256 mode = Adapter(adapter).mode();
        if (mode == 0) {
            return day == 1;
        }
        if (mode == 1) {
            return DateTime.getDayOfWeek(maturity) == 1;
        }
        return false;
    }
    function _setAdapter(address adapter, bool isOn) internal {
        AdapterMeta memory am = adapterMeta[adapter];
        if (am.enabled == isOn) revert Errors.ExistingValue();
        am.enabled = isOn;
        if (isOn && am.id == 0) {
            am.id = ++adapterCounter;
            adapterAddresses[am.id] = adapter;
        }
        am.level = uint248(Adapter(adapter).level());
        adapterMeta[adapter] = am;
        emit AdapterChanged(adapter, am.id, isOn);
    }
    function pt(address adapter, uint256 maturity) public view returns (address) {
        return series[adapter][maturity].pt;
    }
    function yt(address adapter, uint256 maturity) public view returns (address) {
        return series[adapter][maturity].yt;
    }
    function mscale(address adapter, uint256 maturity) public view returns (uint256) {
        return series[adapter][maturity].mscale;
    }
    modifier onlyYT(address adapter, uint256 maturity) {
        if (series[adapter][maturity].yt != msg.sender) revert Errors.OnlyYT();
        _;
    }
    event Backfilled(
        address indexed adapter,
        uint256 indexed maturity,
        uint256 mscale,
        address[] _usrs,
        uint256[] _lscales
    );
    event GuardChanged(address indexed adapter, uint256 cap);
    event AdapterChanged(address indexed adapter, uint256 indexed id, bool indexed isOn);
    event PeripheryChanged(address indexed periphery);
    event SeriesInitialized(
        address adapter,
        uint256 indexed maturity,
        address pt,
        address yt,
        address indexed sponsor,
        address indexed target
    );
    event Issued(address indexed adapter, uint256 indexed maturity, uint256 balance, address indexed sender);
    event Combined(address indexed adapter, uint256 indexed maturity, uint256 balance, address indexed sender);
    event Collected(address indexed adapter, uint256 indexed maturity, uint256 collected);
    event SeriesSettled(address indexed adapter, uint256 indexed maturity, address indexed settler);
    event PTRedeemed(address indexed adapter, uint256 indexed maturity, uint256 redeemed);
    event YTRedeemed(address indexed adapter, uint256 indexed maturity, uint256 redeemed);
    event GuardedChanged(bool indexed guarded);
    event PermissionlessChanged(bool indexed permissionless);
}
contract TokenHandler is Trust {
    address public divider;
    constructor() Trust(msg.sender) {}
    function init(address _divider) external requiresTrust {
        if (divider != address(0)) revert Errors.AlreadyInitialized();
        divider = _divider;
    }
    function deploy(
        address adapter,
        uint248 id,
        uint256 maturity
    ) external returns (address pt, address yt) {
        if (msg.sender != divider) revert Errors.OnlyDivider();
        ERC20 target = ERC20(Adapter(adapter).target());
        uint8 decimals = target.decimals();
        string memory symbol = target.symbol();
        (string memory d, string memory m, string memory y) = DateTime.toDateString(maturity);
        string memory date = DateTime.format(maturity);
        string memory datestring = string(abi.encodePacked(d, "-", m, "-", y));
        string memory adapterId = DateTime.uintToString(id);
        pt = address(
            new Token(
                string(abi.encodePacked(date, " ", symbol, " Sense Principal Token, A", adapterId)),
                string(abi.encodePacked("sP-", symbol, ":", datestring, ":", adapterId)),
                decimals,
                divider
            )
        );
        yt = address(
            new YT(
                adapter,
                maturity,
                string(abi.encodePacked(date, " ", symbol, " Sense Yield Token, A", adapterId)),
                string(abi.encodePacked("sY-", symbol, ":", datestring, ":", adapterId)),
                decimals,
                divider
            )
        );
    }
}