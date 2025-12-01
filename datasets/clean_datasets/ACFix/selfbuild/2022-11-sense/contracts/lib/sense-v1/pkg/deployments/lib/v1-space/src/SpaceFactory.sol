pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import { FixedPoint } from "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import { BasePoolFactory } from "@balancer-labs/v2-pool-utils/contracts/factories/BasePoolFactory.sol";
import { IVault } from "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
import { Trust } from "@sense-finance/v1-utils/src/Trust.sol";
import { Space } from "./Space.sol";
import { Errors, _require } from "./Errors.sol";
interface DividerLike {
    function series(
        address, 
        uint256 
    )
        external
        returns (
            address, 
            address, 
            address, 
            uint256, 
            uint256, 
            uint256, 
            uint256, 
            uint128, 
            uint128 
        );
    function pt(address adapter, uint256 maturity) external returns (address);
    function yt(address adapter, uint256 maturity) external returns (address);
}
contract SpaceFactory is Trust {
    IVault public immutable vault;
    DividerLike public immutable divider;
    mapping(address => mapping(uint256 => address)) public pools;
    uint256 public ts;
    uint256 public g1;
    uint256 public g2;
    bool public oracleEnabled;
    constructor(
        IVault _vault,
        address _divider,
        uint256 _ts,
        uint256 _g1,
        uint256 _g2,
        bool _oracleEnabled
    ) Trust(msg.sender) {
        vault = _vault;
        divider = DividerLike(_divider);
        ts = _ts;
        g1 = _g1;
        g2 = _g2;
        oracleEnabled = _oracleEnabled;
    }
    function create(address adapter, uint256 maturity) external returns (address pool) {
        address pt = divider.pt(adapter, maturity);
        _require(pt != address(0), Errors.INVALID_SERIES);
        _require(pools[adapter][maturity] == address(0), Errors.POOL_ALREADY_EXISTS);
        pool = address(new Space(
            vault,
            adapter,
            maturity,
            pt,
            ts,
            g1,
            g2,
            oracleEnabled
        ));
        pools[adapter][maturity] = pool;
    }
    function setParams(
        uint256 _ts,
        uint256 _g1,
        uint256 _g2,
        bool _oracleEnabled
    ) public requiresTrust {
        _require(_g1 <= FixedPoint.ONE, Errors.INVALID_G1);
        _require(_g2 >= FixedPoint.ONE, Errors.INVALID_G2);
        ts = _ts;
        g1 = _g1;
        g2 = _g2;
        oracleEnabled = _oracleEnabled;
    }
    function setPool(address adapter, uint256 maturity, address pool) public requiresTrust {
        _require(divider.pt(adapter, maturity) != address(0), Errors.INVALID_SERIES);
        _require(pools[adapter][maturity] == address(0), Errors.POOL_ALREADY_EXISTS);
        pools[adapter][maturity] = pool;
    }
}