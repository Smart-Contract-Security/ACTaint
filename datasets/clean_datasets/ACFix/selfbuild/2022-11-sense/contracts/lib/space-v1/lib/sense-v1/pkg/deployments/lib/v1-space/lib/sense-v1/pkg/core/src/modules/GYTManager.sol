pragma solidity 0.8.11;
import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { SafeTransferLib } from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import { FixedMath } from "../external/FixedMath.sol";
import { Divider } from "../Divider.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { YT } from "../tokens/YT.sol";
import { Token } from "../tokens/Token.sol";
import { BaseAdapter as Adapter } from "../adapters/BaseAdapter.sol";
contract GYTManager {
    using SafeTransferLib for ERC20;
    using FixedMath for uint256;
    mapping(address => uint256) public inits;
    mapping(address => uint256) public totals;
    mapping(address => uint256) public mscales;
    mapping(address => Token) public gyields;
    address public divider;
    constructor(address _divider) {
        divider = _divider;
    }
    function join(
        address adapter,
        uint256 maturity,
        uint256 uBal
    ) external {
        if (maturity <= block.timestamp) revert Errors.InvalidMaturity();
        address yt = Divider(divider).yt(adapter, maturity);
        if (yt == address(0)) revert Errors.SeriesDoesNotExist();
        if (address(gyields[yt]) == address(0)) {
            uint256 scale = Adapter(adapter).scale();
            mscales[yt] = scale;
            inits[yt] = scale;
            string memory name = string(abi.encodePacked("G-", ERC20(yt).name(), "-G"));
            string memory symbol = string(abi.encodePacked("G-", ERC20(yt).symbol(), "-G"));
            gyields[yt] = new Token(name, symbol, ERC20(Adapter(adapter).target()).decimals(), address(this));
        } else {
            uint256 tBal = excess(adapter, maturity, uBal);
            if (tBal > 0) {
                ERC20(Adapter(adapter).target()).safeTransferFrom(msg.sender, address(this), tBal);
                totals[yt] += tBal;
            }
        }
        ERC20(yt).safeTransferFrom(msg.sender, address(this), uBal);
        gyields[yt].mint(msg.sender, uBal);
        emit Joined(adapter, maturity, msg.sender, uBal);
    }
    function exit(
        address adapter,
        uint256 maturity,
        uint256 uBal
    ) external {
        address yt = Divider(divider).yt(adapter, maturity);
        if (yt == address(0)) revert Errors.SeriesDoesNotExist();
        uint256 collected = YT(yt).collect();
        uint256 total = totals[yt] + collected;
        uint256 tBal = uBal.fdiv(gyields[yt].totalSupply(), total);
        totals[yt] = total - tBal;
        ERC20(Adapter(adapter).target()).safeTransfer(msg.sender, tBal);
        ERC20(yt).safeTransfer(msg.sender, uBal);
        gyields[yt].burn(msg.sender, uBal);
        emit Exited(adapter, maturity, msg.sender, uBal);
    }
    function excess(
        address adapter,
        uint256 maturity,
        uint256 uBal
    ) public returns (uint256 tBal) {
        address yt = Divider(divider).yt(adapter, maturity);
        uint256 initScale = inits[yt];
        uint256 scale = Adapter(adapter).scale();
        uint256 mscale = mscales[yt];
        if (scale <= mscale) {
            scale = mscale;
        } else {
            mscales[yt] = scale;
        }
        if (scale - initScale > 0) {
            tBal = ((uBal.fmul(scale)).fdiv(scale - initScale)).fdivUp(10**18, FixedMath.WAD);
        }
    }
    event Joined(address indexed adapter, uint256 maturity, address indexed guy, uint256 balance);
    event Exited(address indexed adapter, uint256 maturity, address indexed guy, uint256 balance);
}