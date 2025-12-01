pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import { FixedPoint } from "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import { Math as BasicMath } from "@balancer-labs/v2-solidity-utils/contracts/math/Math.sol";
import { BalancerPoolToken } from "@balancer-labs/v2-pool-utils/contracts/BalancerPoolToken.sol";
import { ERC20 } from "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/ERC20.sol";
import { LogCompression } from "@balancer-labs/v2-solidity-utils/contracts/helpers/LogCompression.sol";
import { IMinimalSwapInfoPool } from "@balancer-labs/v2-vault/contracts/interfaces/IMinimalSwapInfoPool.sol";
import { IVault } from "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
import { IERC20 } from "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/IERC20.sol";
import { Errors, _require } from "./Errors.sol";
import { PoolPriceOracle } from "./oracle/PoolPriceOracle.sol";
interface AdapterLike {
    function scale() external returns (uint256);
    function scaleStored() external view returns (uint256);
    function target() external view returns (address);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getUnderlyingPrice() external view returns (uint256);
}
contract Space is IMinimalSwapInfoPool, BalancerPoolToken, PoolPriceOracle {
    using FixedPoint for uint256;
    struct OracleData {
        uint16 oracleIndex;
        uint32 oracleSampleInitialTimestamp;
        bool oracleEnabled;
        int200 logInvariant;
    }
    uint256 public constant MINIMUM_BPT = 1e6;
    address public immutable adapter;
    uint256 public immutable maturity;
    uint256 public immutable pti;
    uint256 public immutable ts;
    uint256 public immutable g1;
    uint256 public immutable g2;
    bytes32 internal immutable _poolId;
    IERC20 internal immutable _token0;
    IERC20 internal immutable _token1;
    uint256 internal immutable _scalingFactorPT;
    uint256 internal immutable _scalingFactorTarget;
    IVault internal immutable _vault;
    address internal immutable _protocolFeesCollector;
    uint256 internal _initScale;
    uint256 internal _lastToken0Reserve;
    uint256 internal _lastToken1Reserve;
    OracleData internal oracleData;
    constructor(
        IVault vault,
        address _adapter,
        uint256 _maturity,
        address pt,
        uint256 _ts,
        uint256 _g1,
        uint256 _g2,
        bool _oracleEnabled
    ) BalancerPoolToken(
        string(abi.encodePacked("Sense Space ", ERC20(pt).name())),
        string(abi.encodePacked("SPACE-", ERC20(pt).symbol()))
    ) {
        bytes32 poolId = vault.registerPool(IVault.PoolSpecialization.TWO_TOKEN);
        address target = AdapterLike(_adapter).target();
        IERC20[] memory tokens = new IERC20[](2);
        uint256 _pti = pt < target ? 0 : 1;
        tokens[_pti] = IERC20(pt);
        tokens[1 - _pti] = IERC20(target);
        vault.registerTokens(poolId, tokens, new address[](2));
        _vault = vault;
        _poolId = poolId;
        _token0 = tokens[0];
        _token1 = tokens[1];
        _protocolFeesCollector = address(vault.getProtocolFeesCollector());
        _scalingFactorPT = 10**(BasicMath.sub(uint256(18), ERC20(pt).decimals()));
        _scalingFactorTarget = 10**(BasicMath.sub(uint256(18), ERC20(target).decimals()));
        g1 = _g1; 
        g2 = _g2; 
        ts = _ts;
        pti = _pti;
        adapter = _adapter;
        maturity = _maturity;
        oracleData.oracleEnabled = _oracleEnabled;
    }
    function onJoinPool(
        bytes32 poolId,
        address, 
        address recipient,
        uint256[] memory reserves,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) external override onlyVault(poolId) returns (uint256[] memory, uint256[] memory) {
        _require(maturity >= block.timestamp, Errors.POOL_PAST_MATURITY);
        (uint256[] memory reqAmountsIn, uint256 minBptOut) = abi.decode(userData, (uint256[], uint256));
        _upscaleArray(reserves);
        _upscaleArray(reqAmountsIn);
        if (totalSupply() == 0) {
            uint256 initScale = AdapterLike(adapter).scale();
            uint256 underlyingIn = reqAmountsIn[1 - pti].mulDown(initScale);
            _mintPoolTokens(address(0), MINIMUM_BPT);
            uint256 bptToMint = underlyingIn.sub(MINIMUM_BPT);
            _mintPoolTokens(recipient, bptToMint);
            _require(bptToMint >= minBptOut, Errors.BPT_OUT_MIN_AMOUNT);
            _downscaleUpArray(reqAmountsIn);
            _initScale = initScale;
            delete reqAmountsIn[pti];
            reserves = reqAmountsIn;
            _cacheReserves(reserves);
            return (reqAmountsIn, new uint256[](2));
        } else {
            _updateOracle(lastChangeBlock, reserves[pti], reserves[1 - pti]);
            if (protocolSwapFeePercentage != 0) {
                _mintPoolTokens(_protocolFeesCollector, _bptFeeDue(reserves, protocolSwapFeePercentage));
            }
            (uint256 bptToMint, uint256[] memory amountsIn) = _tokensInForBptOut(reqAmountsIn, reserves);
            _require(bptToMint >= minBptOut, Errors.BPT_OUT_MIN_AMOUNT);
            _mintPoolTokens(recipient, bptToMint);
            reserves[0] += amountsIn[0];
            reserves[1] += amountsIn[1];
            _cacheReserves(reserves);
            _downscaleUpArray(amountsIn);
            return (amountsIn, new uint256[](2));
        }
    }
    function onExitPool(
        bytes32 poolId,
        address sender,
        address, 
        uint256[] memory reserves,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) external override onlyVault(poolId) returns (uint256[] memory, uint256[] memory) {
        _upscaleArray(reserves);
        _updateOracle(lastChangeBlock, reserves[pti], reserves[1 - pti]);
        if (protocolSwapFeePercentage != 0) {
            _mintPoolTokens(_protocolFeesCollector, _bptFeeDue(reserves, protocolSwapFeePercentage));
        }
        uint256 bptAmountIn = abi.decode(userData, (uint256));
        uint256[] memory amountsOut = new uint256[](2);
        uint256 _totalSupply = totalSupply();
        amountsOut[0] = reserves[0].mulUp(bptAmountIn).divUp(_totalSupply);
        amountsOut[1] = reserves[1].mulUp(bptAmountIn).divUp(_totalSupply);
        _burnPoolTokens(sender, bptAmountIn);
        reserves[0] = reserves[0].sub(amountsOut[0]);
        reserves[1] = reserves[1].sub(amountsOut[1]);
        _cacheReserves(reserves);
        _downscaleDownArray(amountsOut);
        return (amountsOut, new uint256[](2));
    }
    function onSwap(
        SwapRequest memory request,
        uint256 reservesTokenIn,
        uint256 reservesTokenOut
    ) external override returns (uint256) {
        bool pTIn = request.tokenIn == _token0 ? pti == 0 : pti == 1;
        uint256 scalingFactorTokenIn = _scalingFactor(pTIn);
        uint256 scalingFactorTokenOut = _scalingFactor(!pTIn);
        reservesTokenIn = _upscale(reservesTokenIn, scalingFactorTokenIn);
        reservesTokenOut = _upscale(reservesTokenOut, scalingFactorTokenOut);
        if (msg.sender == address(getVault())) {
            _updateOracle(
                request.lastChangeBlock,
                pTIn ? reservesTokenIn : reservesTokenOut,
                pTIn ? reservesTokenOut: reservesTokenIn
            );
        }
        uint256 scale = AdapterLike(adapter).scale();
        if (pTIn) {
            reservesTokenIn = reservesTokenIn.add(totalSupply());
            reservesTokenOut = reservesTokenOut.mulDown(_initScale);
        } else {
            reservesTokenIn = reservesTokenIn.mulDown(_initScale);
            reservesTokenOut = reservesTokenOut.add(totalSupply());
        }
        if (request.kind == IVault.SwapKind.GIVEN_IN) {
            request.amount = _upscale(request.amount, scalingFactorTokenIn);
            if (!pTIn) {
                request.amount = request.amount.mulDown(scale);
            }
            uint256 amountOut = _onSwap(pTIn, true, request.amount, reservesTokenIn, reservesTokenOut);
            if (pTIn) {
                amountOut = amountOut.divDown(scale);
            }
            return _downscaleDown(amountOut, scalingFactorTokenOut);
        } else {
            request.amount = _upscale(request.amount, scalingFactorTokenOut);
            if (pTIn) {
                request.amount = request.amount.mulDown(scale);
            }
            uint256 amountIn = _onSwap(pTIn, false, request.amount, reservesTokenIn, reservesTokenOut);
            if (!pTIn) {
                amountIn = amountIn.divDown(scale);
            }
            return _downscaleUp(amountIn, scalingFactorTokenIn);
        }
    }
    function _tokensInForBptOut(uint256[] memory reqAmountsIn, uint256[] memory reserves)
        internal
        view
        returns (uint256, uint256[] memory)
    {
        (uint256 pTReserves, uint256 targetReserves) = (reserves[pti], reserves[1 - pti]);
        uint256[] memory amountsIn = new uint256[](2);
        if (pTReserves == 0) {
            uint256 reqTargetIn = reqAmountsIn[1 - pti];
            uint256 bptToMint = reqTargetIn.mulDown(_initScale);
            amountsIn[1 - pti] = reqTargetIn;
            return (bptToMint, amountsIn);
        } else {
            (uint256 reqPTIn, uint256 reqTargetIn) = (reqAmountsIn[pti], reqAmountsIn[1 - pti]);
            uint256 _totalSupply = totalSupply();
            uint256 bptToMintTarget = BasicMath.mul(_totalSupply, reqTargetIn) / targetReserves;
            uint256 bptToMintPT = BasicMath.mul(_totalSupply, reqPTIn) / pTReserves;
            if (bptToMintTarget < bptToMintPT) {
                amountsIn[pti] = BasicMath.mul(pTReserves, reqTargetIn) / targetReserves;
                amountsIn[1 - pti] = reqTargetIn;
                return (bptToMintTarget, amountsIn);
            } else {
                amountsIn[pti] = reqPTIn;
                amountsIn[1 - pti] = BasicMath.mul(targetReserves, reqPTIn) / pTReserves;
                return (bptToMintPT, amountsIn);
            }
        }
    }
    function _onSwap(
        bool pTIn,
        bool givenIn,
        uint256 amountDelta,
        uint256 reservesTokenIn,
        uint256 reservesTokenOut
    ) internal view returns (uint256) {
        uint256 ttm = maturity > block.timestamp ? uint256(maturity - block.timestamp) * FixedPoint.ONE : 0;
        uint256 t = ts.mulDown(ttm);
        uint256 a = (pTIn ? g2 : g1).mulUp(t).complement();
        uint256 x1 = reservesTokenIn.powUp(a);
        uint256 y1 = reservesTokenOut.powUp(a);
        uint256 newReservesTokenInOrOut = givenIn ? reservesTokenIn + amountDelta : reservesTokenOut.sub(amountDelta);
        uint256 xOrY2 = newReservesTokenInOrOut.powDown(a);
        uint256 xOrYPost = (x1.add(y1).sub(xOrY2)).powUp(FixedPoint.ONE.divDown(a));
        _require(!givenIn || reservesTokenOut > xOrYPost, Errors.SWAP_TOO_SMALL);
        if (givenIn) {
            _require(
                pTIn ?
                newReservesTokenInOrOut >= xOrYPost :
                newReservesTokenInOrOut <= xOrYPost,
                Errors.NEGATIVE_RATE
            );
            return reservesTokenOut.sub(xOrYPost);
        } else {
            _require(
                pTIn ?
                xOrYPost >= newReservesTokenInOrOut :
                xOrYPost <= newReservesTokenInOrOut,
                Errors.NEGATIVE_RATE
            );
            return xOrYPost.sub(reservesTokenIn);
        }
    }
    function _bptFeeDue(uint256[] memory reserves, uint256 protocolSwapFeePercentage) internal view returns (uint256) {
        uint256 ttm = maturity > block.timestamp ? uint256(maturity - block.timestamp) * FixedPoint.ONE : 0;
        uint256 a = ts.mulDown(ttm).complement();
        uint256 timeOnlyInvariant = _lastToken0Reserve.powDown(a).add(_lastToken1Reserve.powDown(a));
        uint256 x = reserves[pti].add(totalSupply()).powDown(a);
        uint256 y = reserves[1 - pti].mulDown(_initScale).powDown(a);
        uint256 fullInvariant = x.add(y);
        if (fullInvariant <= timeOnlyInvariant) {
            return 0;
        }
        uint256 growth = fullInvariant.divDown(timeOnlyInvariant).powDown(FixedPoint.ONE.divDown(a));
        uint256 k = protocolSwapFeePercentage.mulDown(growth.sub(FixedPoint.ONE)).divDown(growth);
        return totalSupply().mulDown(k).divDown(k.complement());
    }
    function _cacheReserves(uint256[] memory reserves) internal {
        uint256 reservePT = reserves[pti].add(totalSupply());
        uint256 reserveUnderlying = reserves[1 - pti].mulDown(_initScale);
        uint256 lastToken0Reserve;
        uint256 lastToken1Reserve;
        if (pti == 0) {
            lastToken0Reserve = reservePT;
            lastToken1Reserve = reserveUnderlying;
        } else {
            lastToken0Reserve = reserveUnderlying;
            lastToken1Reserve = reservePT;
        }
        if (oracleData.oracleEnabled) {
            uint256 ttm = maturity > block.timestamp ? uint256(maturity - block.timestamp) * FixedPoint.ONE : 0;
            uint256 a = ts.mulDown(ttm).complement();
            oracleData.logInvariant = int200(
                LogCompression.toLowResLog(
                    lastToken0Reserve.powDown(a).add(lastToken1Reserve.powDown(a))
                )
            );
        }
        _lastToken0Reserve = lastToken0Reserve;
        _lastToken1Reserve = lastToken1Reserve;
    }
    function _updateOracle(
        uint256 lastChangeBlock,
        uint256 balancePT,
        uint256 balanceTarget
    ) internal {
        if (oracleData.oracleEnabled && block.number > lastChangeBlock && balanceTarget >= 1e16) {
            uint256 impliedRate = balancePT.add(totalSupply())
                .divDown(balanceTarget.mulDown(_initScale));
            impliedRate = impliedRate < FixedPoint.ONE ? 0 : impliedRate.sub(FixedPoint.ONE);
            uint256 pTPriceInTarget = getPriceFromImpliedRate(impliedRate);
            uint256 pairPrice = pti == 0 ? FixedPoint.ONE.divDown(pTPriceInTarget) : pTPriceInTarget;
            uint256 oracleUpdatedIndex = _processPriceData(
                oracleData.oracleSampleInitialTimestamp,
                oracleData.oracleIndex,
                LogCompression.toLowResLog(pairPrice),
                impliedRate < 1e6 ? LogCompression.toLowResLog(1e6) : LogCompression.toLowResLog(impliedRate),
                int256(oracleData.logInvariant)
            );
            if (oracleData.oracleIndex != oracleUpdatedIndex) {
                oracleData.oracleSampleInitialTimestamp = uint32(block.timestamp);
                oracleData.oracleIndex = uint16(oracleUpdatedIndex);
            }
        }
    }
    function _getOracleIndex() internal view override returns (uint256) {
        return oracleData.oracleIndex;
    }
    function getImpliedRateFromPrice(uint256 pTPriceInTarget) public view returns (uint256 impliedRate) {
        if (block.timestamp >= maturity) {
            return 0;
        }
        impliedRate = FixedPoint.ONE
            .divDown(pTPriceInTarget.mulDown(AdapterLike(adapter).scaleStored()))
            .powDown(FixedPoint.ONE.divDown(ts).divDown((maturity - block.timestamp) * FixedPoint.ONE))
            .sub(FixedPoint.ONE);
    }
    function getPriceFromImpliedRate(uint256 impliedRate) public view returns (uint256 pTPriceInTarget) {
        if (block.timestamp >= maturity) {
            return FixedPoint.ONE;
        }
        pTPriceInTarget = FixedPoint.ONE
            .divDown(impliedRate.add(FixedPoint.ONE)
            .powDown(((maturity - block.timestamp) * FixedPoint.ONE)
            .divDown(FixedPoint.ONE.divDown(ts))))
            .divDown(AdapterLike(adapter).scaleStored());
    }
    function getFairBPTPrice(uint256 ptTwapDuration)
        public
        view
        returns (uint256 fairBptPriceInTarget)
    {
        OracleAverageQuery[] memory queries = new OracleAverageQuery[](1);
        queries[0] = OracleAverageQuery({
            variable: Variable.PAIR_PRICE,
            secs: ptTwapDuration,
            ago: 1 hours 
        });
        uint256[] memory results = this.getTimeWeightedAverage(queries);
        uint256 pTPriceInTarget = pti == 1 ? results[0] : FixedPoint.ONE.divDown(results[0]);
        uint256 impliedRate = getImpliedRateFromPrice(pTPriceInTarget);
        (, uint256[] memory balances, ) = _vault.getPoolTokens(_poolId);
        uint256 ttm = maturity > block.timestamp
            ? uint256(maturity - block.timestamp) * FixedPoint.ONE
            : 0;
        uint256 a = ts.mulDown(ttm).complement();
        uint256 k = balances[pti].add(totalSupply()).powDown(a).add(
            balances[1 - pti].mulDown(_initScale).powDown(a)
        );
        uint256 equilibriumPTReservesPartial = k.divDown(
            FixedPoint.ONE.divDown(FixedPoint.ONE.add(impliedRate).powDown(a)).add(FixedPoint.ONE)
        ).powDown(FixedPoint.ONE.divDown(a));
        uint256 equilibriumTargetReserves = equilibriumPTReservesPartial
            .divDown(_initScale.mulDown(FixedPoint.ONE.add(impliedRate)));
        fairBptPriceInTarget = equilibriumTargetReserves
            .add(equilibriumPTReservesPartial.sub(totalSupply())
            .mulDown(pTPriceInTarget)).divDown(totalSupply());
    }
    function getIndices() public view returns (uint256 _pti, uint256 _targeti) {
        _pti = pti;
        _targeti = 1 - pti;
    }
    function getPoolId() public view override returns (bytes32) {
        return _poolId;
    }
    function getVault() public view returns (IVault) {
        return _vault;
    }
    function _scalingFactor(bool pt) internal view returns (uint256) {
        return pt ? _scalingFactorPT : _scalingFactorTarget;
    }
    function _upscale(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        return BasicMath.mul(amount, scalingFactor);
    }
    function _downscaleDown(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        return amount / scalingFactor;
    }
    function _downscaleUp(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        return BasicMath.divUp(amount, scalingFactor);
    }
    function _upscaleArray(uint256[] memory amounts) internal view {
        amounts[pti] = BasicMath.mul(amounts[pti], _scalingFactor(true));
        amounts[1 - pti] = BasicMath.mul(amounts[1 - pti], _scalingFactor(false));
    }
    function _downscaleDownArray(uint256[] memory amounts) internal view {
        amounts[pti] = amounts[pti] / _scalingFactor(true);
        amounts[1 - pti] = amounts[1 - pti] / _scalingFactor(false);
    }
    function _downscaleUpArray(uint256[] memory amounts) internal view {
        amounts[pti] = BasicMath.divUp(amounts[pti], _scalingFactor(true));
        amounts[1 - pti] = BasicMath.divUp(amounts[1 - pti], _scalingFactor(false));
    }
    modifier onlyVault(bytes32 poolId_) {
        _require(msg.sender == address(getVault()), Errors.CALLER_NOT_VAULT);
        _require(poolId_ == getPoolId(), Errors.INVALID_POOL_ID);
        _;
    }
}