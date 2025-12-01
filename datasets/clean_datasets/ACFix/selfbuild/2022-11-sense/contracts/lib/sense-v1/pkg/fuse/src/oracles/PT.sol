pragma solidity 0.8.13;
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { PriceOracle } from "../external/PriceOracle.sol";
import { CToken } from "../external/CToken.sol";
import { BalancerOracle } from "../external/BalancerOracle.sol";
import { BalancerVault } from "@sense-finance/v1-core/src/external/balancer/Vault.sol";
import { Trust } from "@sense-finance/v1-utils/src/Trust.sol";
import { Errors } from "@sense-finance/v1-utils/src/libs/Errors.sol";
import { Token } from "@sense-finance/v1-core/src/tokens/Token.sol";
import { FixedMath } from "@sense-finance/v1-core/src/external/FixedMath.sol";
import { BaseAdapter as Adapter } from "@sense-finance/v1-core/src/adapters/abstract/BaseAdapter.sol";
interface SpaceLike {
    function getImpliedRateFromPrice(uint256 pTPriceInTarget) external view returns (uint256);
    function getPriceFromImpliedRate(uint256 impliedRate) external view returns (uint256);
    function getTotalSamples() external pure returns (uint256);
    function adapter() external view returns (address);
}
contract PTOracle is PriceOracle, Trust {
    using FixedMath for uint256;
    mapping(address => address) public pools;
    uint256 public floorRate;
    uint256 public twapPeriod;
    constructor() Trust(msg.sender) {
        floorRate = 3e18; 
        twapPeriod = 5.5 hours;
    }
    function setFloorRate(uint256 _floorRate) external requiresTrust {
        floorRate = _floorRate;
    }
    function setTwapPeriod(uint256 _twapPeriod) external requiresTrust {
        twapPeriod = _twapPeriod;
    }
    function setPrincipal(address pt, address pool) external requiresTrust {
        pools[pt] = pool;
    }
    function getUnderlyingPrice(CToken cToken) external view override returns (uint256) {
        return _price(cToken.underlying());
    }
    function price(address pt) external view override returns (uint256) {
        return _price(pt);
    }
    function _price(address pt) internal view returns (uint256) {
        BalancerOracle pool = BalancerOracle(pools[address(pt)]);
        if (pool == BalancerOracle(address(0))) revert Errors.PoolNotSet();
        (, , , , , , uint256 sampleTs) = pool.getSample(SpaceLike(address(pool)).getTotalSamples() - 1);
        if (sampleTs == 0) revert Errors.OracleNotReady();
        BalancerOracle.OracleAverageQuery[] memory queries = new BalancerOracle.OracleAverageQuery[](1);
        queries[0] = BalancerOracle.OracleAverageQuery({
            variable: BalancerOracle.Variable.BPT_PRICE,
            secs: twapPeriod,
            ago: 1 hours 
        });
        uint256[] memory results = pool.getTimeWeightedAverage(queries);
        uint256 impliedRate = results[0];
        if (impliedRate > floorRate) {
            impliedRate = floorRate;
        }
        address target = Adapter(SpaceLike(address(pool)).adapter()).target();
        return
            SpaceLike(address(pool)).getPriceFromImpliedRate(impliedRate).fmul(PriceOracle(msg.sender).price(target));
    }
}