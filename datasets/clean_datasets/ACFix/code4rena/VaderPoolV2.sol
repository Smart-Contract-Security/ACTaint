pragma solidity 0.8.9;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./BasePoolV2.sol";
import "../../interfaces/shared/IERC20Extended.sol";
import "../../interfaces/dex-v2/pool/IVaderPoolV2.sol";
import "../../interfaces/dex-v2/wrapper/ILPWrapper.sol";
import "../../interfaces/dex-v2/synth/ISynthFactory.sol";
contract VaderPoolV2 is IVaderPoolV2, BasePoolV2, Ownable {
    using SafeERC20 for IERC20;
    ILPWrapper public wrapper;
    ISynthFactory public synthFactory;
    bool public queueActive;
    constructor(bool _queueActive, IERC20 _nativeAsset)
        BasePoolV2(_nativeAsset)
    {
        queueActive = _queueActive;
    }
    function cumulativePrices(IERC20 foreignAsset)
        public
        view
        returns (
            uint256 price0CumulativeLast,
            uint256 price1CumulativeLast,
            uint32 blockTimestampLast
        )
    {
        PriceCumulative memory priceCumulative = pairInfo[foreignAsset]
            .priceCumulative;
        price0CumulativeLast = priceCumulative.nativeLast;
        price1CumulativeLast = priceCumulative.foreignLast;
        blockTimestampLast = pairInfo[foreignAsset].blockTimestampLast;
    }
    function initialize(
        ILPWrapper _wrapper,
        ISynthFactory _synthFactory,
        address _router
    ) external onlyOwner {
        require(
            wrapper == ILPWrapper(_ZERO_ADDRESS),
            "VaderPoolV2::initialize: Already initialized"
        );
        require(
            _wrapper != ILPWrapper(_ZERO_ADDRESS),
            "VaderPoolV2::initialize: Incorrect Wrapper Specified"
        );
        require(
            _synthFactory != ISynthFactory(_ZERO_ADDRESS),
            "VaderPoolV2::initialize: Incorrect SynthFactory Specified"
        );
        require(
            _router != _ZERO_ADDRESS,
            "VaderPoolV2::initialize: Incorrect Router Specified"
        );
        wrapper = _wrapper;
        synthFactory = _synthFactory;
        router = _router;
    }
    function mintSynth(
        IERC20 foreignAsset,
        uint256 nativeDeposit,
        address from,
        address to
    )
        external
        override
        nonReentrant
        supportedToken(foreignAsset)
        returns (uint256 amountSynth)
    {
        nativeAsset.safeTransferFrom(from, address(this), nativeDeposit);
        ISynth synth = synthFactory.synths(foreignAsset);
        if (synth == ISynth(_ZERO_ADDRESS))
            synth = synthFactory.createSynth(
                IERC20Extended(address(foreignAsset))
            );
        (uint112 reserveNative, uint112 reserveForeign, ) = getReserves(
            foreignAsset
        ); 
        amountSynth = VaderMath.calculateSwap(
            nativeDeposit,
            reserveNative,
            reserveForeign
        );
        _update(
            foreignAsset,
            reserveNative + nativeDeposit,
            reserveForeign,
            reserveNative,
            reserveForeign
        );
        synth.mint(to, amountSynth);
    }
    function burnSynth(
        IERC20 foreignAsset,
        uint256 synthAmount,
        address to
    ) external override nonReentrant returns (uint256 amountNative) {
        ISynth synth = synthFactory.synths(foreignAsset);
        require(
            synth != ISynth(_ZERO_ADDRESS),
            "VaderPoolV2::burnSynth: Inexistent Synth"
        );
        require(
            synthAmount > 0,
            "VaderPoolV2::burnSynth: Insufficient Synth Amount"
        );
        IERC20(synth).safeTransferFrom(msg.sender, address(this), synthAmount);
        synth.burn(synthAmount);
        (uint112 reserveNative, uint112 reserveForeign, ) = getReserves(
            foreignAsset
        ); 
        amountNative = VaderMath.calculateSwap(
            synthAmount,
            reserveForeign,
            reserveNative
        );
        _update(
            foreignAsset,
            reserveNative - amountNative,
            reserveForeign,
            reserveNative,
            reserveForeign
        );
        nativeAsset.safeTransfer(to, amountNative);
    }
    function burn(uint256 id, address to)
        external
        override
        onlyRouter
        returns (
            uint256 amountNative,
            uint256 amountForeign,
            uint256 coveredLoss
        )
    {
        (amountNative, amountForeign) = _burn(id, to);
        Position storage position = positions[id];
        uint256 creation = position.creation;
        uint256 originalNative = position.originalNative;
        uint256 originalForeign = position.originalForeign;
        delete positions[id];
        uint256 loss = VaderMath.calculateLoss(
            originalNative,
            originalForeign,
            amountNative,
            amountForeign
        );
        coveredLoss =
            (loss * _min(block.timestamp - creation, _ONE_YEAR)) /
            _ONE_YEAR;
    }
    function mintFungible(
        IERC20 foreignAsset,
        uint256 nativeDeposit,
        uint256 foreignDeposit,
        address from,
        address to
    ) external override nonReentrant returns (uint256 liquidity) {
        IERC20Extended lp = wrapper.tokens(foreignAsset);
        require(
            lp != IERC20Extended(_ZERO_ADDRESS),
            "VaderPoolV2::mintFungible: Unsupported Token"
        );
        (uint112 reserveNative, uint112 reserveForeign, ) = getReserves(
            foreignAsset
        ); 
        nativeAsset.safeTransferFrom(from, address(this), nativeDeposit);
        foreignAsset.safeTransferFrom(from, address(this), foreignDeposit);
        PairInfo storage pair = pairInfo[foreignAsset];
        uint256 totalLiquidityUnits = pair.totalSupply;
        if (totalLiquidityUnits == 0) liquidity = nativeDeposit;
        else
            liquidity = VaderMath.calculateLiquidityUnits(
                nativeDeposit,
                reserveNative,
                foreignDeposit,
                reserveForeign,
                totalLiquidityUnits
            );
        require(
            liquidity > 0,
            "VaderPoolV2::mintFungible: Insufficient Liquidity Provided"
        );
        pair.totalSupply = totalLiquidityUnits + liquidity;
        _update(
            foreignAsset,
            reserveNative + nativeDeposit,
            reserveForeign + foreignDeposit,
            reserveNative,
            reserveForeign
        );
        lp.mint(to, liquidity);
        emit Mint(from, to, nativeDeposit, foreignDeposit);
    }
    function burnFungible(
        IERC20 foreignAsset,
        uint256 liquidity,
        address to
    )
        external
        override
        nonReentrant
        returns (uint256 amountNative, uint256 amountForeign)
    {
        IERC20Extended lp = wrapper.tokens(foreignAsset);
        require(
            lp != IERC20Extended(_ZERO_ADDRESS),
            "VaderPoolV2::burnFungible: Unsupported Token"
        );
        IERC20(lp).safeTransferFrom(msg.sender, address(this), liquidity);
        lp.burn(liquidity);
        (uint112 reserveNative, uint112 reserveForeign, ) = getReserves(
            foreignAsset
        ); 
        PairInfo storage pair = pairInfo[foreignAsset];
        uint256 _totalSupply = pair.totalSupply;
        amountNative = (liquidity * reserveNative) / _totalSupply;
        amountForeign = (liquidity * reserveForeign) / _totalSupply;
        require(
            amountNative > 0 && amountForeign > 0,
            "VaderPoolV2::burnFungible: Insufficient Liquidity Burned"
        );
        pair.totalSupply = _totalSupply - liquidity;
        nativeAsset.safeTransfer(to, amountNative);
        foreignAsset.safeTransfer(to, amountForeign);
        _update(
            foreignAsset,
            reserveNative - amountNative,
            reserveForeign - amountForeign,
            reserveNative,
            reserveForeign
        );
        emit Burn(msg.sender, amountNative, amountForeign, to);
    }
    function toggleQueue() external override onlyOwner {
        bool _queueActive = !queueActive;
        queueActive = _queueActive;
        emit QueueActive(_queueActive);
    }
    function setTokenSupport(IERC20 foreignAsset, bool support)
        external
        override
        onlyOwner
    {
        require(
            supported[foreignAsset] != support,
            "VaderPoolV2::supportToken: Already At Desired State"
        );
        supported[foreignAsset] = support;
    }
    function setFungibleTokenSupport(IERC20 foreignAsset)
        external
        override
        onlyOwner
    {
        wrapper.createWrapper(foreignAsset);
    }
    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}