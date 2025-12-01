pragma solidity =0.7.6;
pragma abicoder v2;
import './Setup.sol';
import '../../../../../contracts/test/TestERC20.sol';
import '../../../../../contracts/libraries/TickMath.sol';
import '../../../../../contracts/UniswapV3Pool.sol';
import '../../../../../contracts/libraries/Position.sol';
contract E2E_mint_burn {
    SetupTokens tokens;
    SetupUniswap uniswap;
    UniswapV3Pool pool;
    TestERC20 token0;
    TestERC20 token1;
    UniswapMinter minter;
    UniswapSwapper swapper;
    int24[] usedTicks;
    bool inited;
    PoolPosition[] positions;
    struct PoolPosition {
        int24 tickLower;
        int24 tickUpper;
        uint128 amount;
        bytes32 key;
    }
    struct PoolParams {
        uint24 fee;
        int24 tickSpacing;
        int24 minTick;
        int24 maxTick;
        uint24 tickCount;
        uint160 startPrice;
        int24 startTick;
    }
    PoolParams poolParams;
    constructor() public {
        tokens = new SetupTokens();
        token0 = tokens.token0();
        token1 = tokens.token1();
        uniswap = new SetupUniswap(token0, token1);
        minter = new UniswapMinter(token0, token1);
        swapper = new UniswapSwapper(token0, token1);
        tokens.mintTo(0, address(minter), 1e10 ether);
        tokens.mintTo(1, address(minter), 1e10 ether);
    }
    function _getRandomPositionIdx(uint128 _seed, uint256 _positionsCount) internal view returns (uint128 positionIdx) {
        positionIdx = _seed % uint128(_positionsCount);
    }
    function _getRandomBurnAmount(uint128 _seed, uint128 _positionAmount) internal view returns (uint128 burnAmount) {
        burnAmount = _seed % _positionAmount;
        require(burnAmount < _positionAmount);
        require(burnAmount > 0);
    }
    function _getRandomPositionIdxAndBurnAmount(uint128 _seed)
        internal
        view
        returns (uint128 positionIdx, uint128 burnAmount)
    {
        positionIdx = _getRandomPositionIdx(_seed, positions.length);
        burnAmount = _getRandomBurnAmount(_seed, positions[positionIdx].amount);
    }
    function storeUsedTicks(int24 _tL, int24 _tU) internal {
        bool lowerAlreadyUsed = false;
        bool upperAlreadyUsed = false;
        for (uint8 j = 0; j < usedTicks.length; j++) {
            if (usedTicks[j] == _tL) lowerAlreadyUsed = true;
            else if (usedTicks[j] == _tU) upperAlreadyUsed = true;
        }
        if (!lowerAlreadyUsed) usedTicks.push(_tL);
        if (!upperAlreadyUsed) usedTicks.push(_tU);
    }
    function removePosition(uint256 _posIdx) internal {
        positions[_posIdx] = positions[positions.length - 1];
        positions.pop();
    }
    function forgePosition(
        uint128 _seed,
        int24 _poolTickSpacing,
        uint24 _poolTickCount,
        int24 _poolMaxTick
    ) internal view returns (int24 tickLower, int24 tickUpper) {
        int24 randomTick1 = int24((_seed % uint128(_poolTickCount)) * uint128(_poolTickSpacing));
        if (_seed % 2 == 0) {
            tickLower = randomTick1;
            uint24 poolTickCountLeft = uint24((_poolMaxTick - randomTick1) / _poolTickSpacing);
            int24 randomTick2 = int24((_seed % uint128(poolTickCountLeft)) * uint128(_poolTickSpacing));
            tickUpper = tickLower + randomTick2;
        } else {
            tickLower = randomTick1 == 0 ? 0 : -randomTick1;
            uint24 poolTickCountNegativeLeft = uint24((_poolMaxTick - randomTick1) / _poolTickSpacing);
            uint24 poolTickCountTotalLeft = poolTickCountNegativeLeft + _poolTickCount;
            uint24 randomIncrement = uint24((_seed % uint128(poolTickCountTotalLeft)) * uint128(_poolTickSpacing));
            if (randomIncrement <= uint24(tickLower)) {
                tickUpper = tickLower + int24(randomIncrement);
            } else {
                randomIncrement -= uint24(-tickLower);
                tickUpper = tickLower + int24(randomIncrement);
            }
        }
    }
    function check_liquidityNet_invariant() internal {
        int128 liquidityNet = 0;
        for (uint256 i = 0; i < usedTicks.length; i++) {
            (, int128 tickLiquidityNet, , ) = pool.ticks(usedTicks[i]);
            int128 result = liquidityNet + tickLiquidityNet;
            assert(
                (tickLiquidityNet >= 0 && result >= liquidityNet) || (tickLiquidityNet < 0 && result < liquidityNet)
            );
            liquidityNet = result;
        }
        assert(liquidityNet == 0);
    }
    function check_liquidity_invariant() internal {
        (, int24 currentTick, , , , , ) = pool.slot0();
        int128 liquidity = 0;
        for (uint256 i = 0; i < usedTicks.length; i++) {
            int24 tick = usedTicks[i];
            if (tick <= currentTick) {
                (, int128 tickLiquidityNet, , ) = pool.ticks(tick);
                int128 result = liquidity + tickLiquidityNet;
                assert((tickLiquidityNet >= 0 && result >= liquidity) || (tickLiquidityNet < 0 && result < liquidity));
                liquidity = result;
            }
        }
        assert(uint128(liquidity) == pool.liquidity());
        assert(liquidity >= 0);
    }
    function check_tick_feegrowth_invariant() internal {
        (, int24 currentTick, , , , , ) = pool.slot0();
        if (currentTick == poolParams.maxTick || currentTick == poolParams.minTick) return;
        int24 tickBelow = currentTick - poolParams.tickSpacing;
        int24 tickAbove = currentTick + poolParams.tickSpacing;
        (, , uint256 tB_feeGrowthOutside0X128, uint256 tB_feeGrowthOutside1X128) = pool.ticks(tickBelow);
        (, , uint256 tA_feeGrowthOutside0X128, uint256 tA_feeGrowthOutside1X128) = pool.ticks(tickAbove);
        assert(tB_feeGrowthOutside0X128 + tA_feeGrowthOutside0X128 <= pool.feeGrowthGlobal0X128());
        assert(tB_feeGrowthOutside1X128 + tA_feeGrowthOutside1X128 <= pool.feeGrowthGlobal1X128());
    }
    function check_mint_invariants(
        int24 _tickLower,
        int24 _tickUpper,
        UniswapMinter.MinterStats memory bfre,
        UniswapMinter.MinterStats memory aftr
    ) internal {
        (, int24 currentTick, , , , , ) = pool.slot0();
        if (currentTick >= _tickLower && currentTick < _tickUpper) {
            assert(aftr.liq > bfre.liq);
        } else {
            assert(aftr.liq == bfre.liq);
        }
        assert(aftr.tL_liqGross > bfre.tL_liqGross);
        assert(aftr.tU_liqGross > bfre.tU_liqGross);
        assert(aftr.tL_liqNet > bfre.tL_liqNet);
        assert(aftr.tU_liqNet < bfre.tU_liqNet);
    }
    function check_burn_invariants(
        uint128 _burnAmount,
        int24 _tickLower,
        int24 _tickUpper,
        uint128 _newPosAmount,
        UniswapMinter.MinterStats memory bfre,
        UniswapMinter.MinterStats memory aftr
    ) internal {
        (, int24 currentTick, , , , , ) = pool.slot0();
        if (_burnAmount > 0) {
            if (currentTick >= _tickLower && currentTick < _tickUpper) {
                assert(aftr.liq < bfre.liq);
            } else {
                assert(aftr.liq == bfre.liq);
            }
        } else {
            assert(aftr.liq == bfre.liq);
        }
        assert(aftr.tL_liqGross <= bfre.tL_liqGross);
        assert(aftr.tU_liqGross <= bfre.tU_liqGross);
        assert(aftr.tL_liqNet <= bfre.tL_liqNet);
        assert(aftr.tU_liqNet >= bfre.tU_liqNet);
        bytes32 positionKey = keccak256(abi.encodePacked(address(minter), _tickLower, _tickUpper));
        (uint128 positionLiquidity, , , , ) = pool.positions(positionKey);
        assert(positionLiquidity == _newPosAmount);
    }
    function viewInitRandomPoolParams(uint128 _seed) public view returns (PoolParams memory _poolParams) {
        _poolParams = forgePoolParams(_seed);
    }
    function viewMintRandomNewPosition(
        uint128 _seed,
        int24 _poolTickSpacing,
        uint24 _poolTickCount,
        int24 _poolMaxTick
    )
        public
        view
        returns (
            int24 tickLower,
            int24 tickUpper,
            uint128 amount
        )
    {
        (tickLower, tickUpper) = forgePosition(_seed, _poolTickSpacing, _poolTickCount, _poolMaxTick);
        amount = _seed;
    }
    function viewBurnRandomPositionIdx(uint128 _seed, uint128 _positionsCount)
        public
        view
        returns (uint128 positionIdx)
    {
        positionIdx = _getRandomPositionIdx(_seed, _positionsCount);
    }
    function viewBurnRandomPositionBurnAmount(uint128 _seed, uint128 _positionAmount)
        public
        view
        returns (uint128 burnAmount)
    {
        burnAmount = _getRandomBurnAmount(_seed, _positionAmount);
    }
    function forgePoolParams(uint128 _seed) internal view returns (PoolParams memory _poolParams) {
        if (_seed % 3 == 0) {
            _poolParams.fee = uint24(500);
            _poolParams.tickSpacing = int24(10);
        } else if (_seed % 3 == 1) {
            _poolParams.fee = uint24(3000);
            _poolParams.tickSpacing = int24(60);
        } else if (_seed % 3 == 2) {
            _poolParams.fee = uint24(10000);
            _poolParams.tickSpacing = int24(2000);
        }
        _poolParams.maxTick = (int24(887272) / _poolParams.tickSpacing) * _poolParams.tickSpacing;
        _poolParams.minTick = -_poolParams.maxTick;
        _poolParams.tickCount = uint24(_poolParams.maxTick / _poolParams.tickSpacing);
        _poolParams.startTick = int24((_seed % uint128(_poolParams.tickCount)) * uint128(_poolParams.tickSpacing));
        if (_seed % 3 == 0) {
            _poolParams.startPrice = TickMath.getSqrtRatioAtTick(-_poolParams.startTick);
        } else if (_seed % 3 == 1) {
            _poolParams.startPrice = TickMath.getSqrtRatioAtTick(0);
            _poolParams.startTick = 0;
        } else if (_seed % 3 == 2) {
            _poolParams.startPrice = TickMath.getSqrtRatioAtTick(_poolParams.startTick);
        }
    }
    function _init(uint128 _seed) internal {
        poolParams = forgePoolParams(_seed);
        uniswap.createPool(poolParams.fee, poolParams.startPrice);
        pool = uniswap.pool();
        minter.setPool(pool);
        inited = true;
    }
    function test_mint(uint128 _amount) public {
        if (!inited) _init(_amount);
        (int24 _tL, int24 _tU) =
            forgePosition(_amount, poolParams.tickSpacing, poolParams.tickCount, poolParams.maxTick);
        (UniswapMinter.MinterStats memory bfre, UniswapMinter.MinterStats memory aftr) =
            minter.doMint(_tL, _tU, _amount);
        storeUsedTicks(_tL, _tU);
        check_mint_invariants(_tL, _tU, bfre, aftr);
        check_liquidityNet_invariant();
        check_liquidity_invariant();
        check_tick_feegrowth_invariant();
        bytes32 positionKey = keccak256(abi.encodePacked(address(minter), _tL, _tU));
        bool mintingToExistingPos = false;
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].key == positionKey) {
                positions[i].amount += _amount;
                mintingToExistingPos = true;
                break;
            }
        }
        if (!mintingToExistingPos) {
            positions.push(PoolPosition(_tL, _tU, _amount, positionKey));
        }
    }
    function test_burn_partial(uint128 _amount) public {
        require(positions.length > 0);
        (uint128 posIdx, uint128 burnAmount) = _getRandomPositionIdxAndBurnAmount(_amount);
        PoolPosition storage pos = positions[posIdx];
        UniswapMinter.MinterStats memory bfre;
        UniswapMinter.MinterStats memory aftr;
        try minter.doBurn(pos.tickLower, pos.tickUpper, burnAmount) returns (
            UniswapMinter.MinterStats memory bfre_burn,
            UniswapMinter.MinterStats memory aftr_burn
        ) {
            bfre = bfre_burn;
            aftr = aftr_burn;
        } catch {
            assert(false);
        }
        check_burn_invariants(burnAmount, pos.tickLower, pos.tickUpper, pos.amount - burnAmount, bfre, aftr);
        check_liquidityNet_invariant();
        check_liquidity_invariant();
        check_tick_feegrowth_invariant();
        pos.amount = pos.amount - burnAmount;
    }
    function test_burn_full(uint128 _amount) public {
        require(positions.length > 0);
        uint128 posIdx = _getRandomPositionIdx(_amount, positions.length);
        PoolPosition storage pos = positions[posIdx];
        UniswapMinter.MinterStats memory bfre;
        UniswapMinter.MinterStats memory aftr;
        try minter.doBurn(pos.tickLower, pos.tickUpper, pos.amount) returns (
            UniswapMinter.MinterStats memory bfre_burn,
            UniswapMinter.MinterStats memory aftr_burn
        ) {
            bfre = bfre_burn;
            aftr = aftr_burn;
        } catch {
            assert(false);
        }
        check_burn_invariants(pos.amount, pos.tickLower, pos.tickUpper, 0, bfre, aftr);
        check_liquidityNet_invariant();
        check_liquidity_invariant();
        check_tick_feegrowth_invariant();
        removePosition(posIdx);
    }
    function test_burn_zero(uint128 _amount) public {
        require(positions.length > 0);
        uint128 posIdx = _getRandomPositionIdx(_amount, positions.length);
        PoolPosition storage pos = positions[posIdx];
        UniswapMinter.MinterStats memory bfre;
        UniswapMinter.MinterStats memory aftr;
        try minter.doBurn(pos.tickLower, pos.tickUpper, 0) returns (
            UniswapMinter.MinterStats memory bfre_burn,
            UniswapMinter.MinterStats memory aftr_burn
        ) {
            bfre = bfre_burn;
            aftr = aftr_burn;
        } catch {
            assert(false);
        }
        check_burn_invariants(0, pos.tickLower, pos.tickUpper, pos.amount, bfre, aftr);
        check_liquidityNet_invariant();
        check_liquidity_invariant();
        check_tick_feegrowth_invariant();
    }
}