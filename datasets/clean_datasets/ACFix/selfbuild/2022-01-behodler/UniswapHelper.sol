pragma solidity 0.8.4;
import "./facades/UniPairLike.sol";
import "./facades/BehodlerLike.sol";
import "./DAO/Governable.sol";
import "./ERC677/ERC20Burnable.sol";
import "./facades/FlanLike.sol";
import "./testing/realUniswap/interfaces/IUniswapV2Factory.sol";
import "./facades/AMMHelper.sol";
contract BlackHole {}
contract UniswapHelper is Governable, AMMHelper {
  address limbo;
  struct UniVARS {
    UniPairLike Flan_SCX_tokenPair;
    address behodler;
    address blackHole;
    address flan;
    uint256 divergenceTolerance;
    uint256 minQuoteWaitDuration;
    address DAI;
    uint8 precision; 
    IUniswapV2Factory factory;
    uint8 priceBoostOvershoot; 
  }
  struct FlanQuote {
    uint256 DaiScxSpotPrice;
    uint256 DaiBalanceOnBehodler;
    uint256 blockProduced;
  }
  FlanQuote[2] public latestFlanQuotes; 
  UniVARS VARS;
  uint256 constant EXA = 1e18;
  uint256 constant year = (1 days * 365);
  modifier ensurePriceStability() {
    _ensurePriceStability();
    _;
  }
  modifier onlyLimbo() {
    require(msg.sender == limbo);
    _;
  }
  constructor(address _limbo, address limboDAO) Governable(limboDAO) {
    limbo = _limbo;
    VARS.blackHole = address(new BlackHole());
    VARS.factory = IUniswapV2Factory(address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f));
    VARS.DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
  }
  function blackHole() public view returns (address) {
    return VARS.blackHole;
  }
  function setFactory(address factory) public {
    require(block.chainid != 1, "Uniswap factory hardcoded on mainnet");
    VARS.factory = IUniswapV2Factory(factory);
  }
  function setDAI(address dai) public {
    require(block.chainid != 1, "DAI hardcoded on mainnet");
    VARS.DAI = dai;
  }
  function configure(
    address _limbo,
    address FlanSCXPair,
    address behodler,
    address flan,
    uint256 divergenceTolerance,
    uint256 minQuoteWaitDuration,
    uint8 precision,
    uint8 priceBoostOvershoot
  ) public onlySuccessfulProposal {
    limbo = _limbo;
    VARS.Flan_SCX_tokenPair = UniPairLike(FlanSCXPair);
    VARS.behodler = behodler;
    VARS.flan = flan;
    require(divergenceTolerance >= 100, "Divergence of 100 is parity");
    VARS.divergenceTolerance = divergenceTolerance;
    VARS.minQuoteWaitDuration = minQuoteWaitDuration;
    VARS.DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    VARS.precision = precision == 0 ? precision : precision;
    require(priceBoostOvershoot < 100, "Set overshoot to number between 1 and 100.");
    VARS.priceBoostOvershoot = priceBoostOvershoot;
  }
  function generateFLNQuote() public override {
    latestFlanQuotes[1] = latestFlanQuotes[0];
    (
      latestFlanQuotes[0].DaiScxSpotPrice,
      latestFlanQuotes[0].DaiBalanceOnBehodler
    ) = getLatestFLNQuote();
    latestFlanQuotes[0].blockProduced = block.number;
  }
  function getLatestFLNQuote() internal view returns (uint256 dai_scx, uint256 daiBalanceOnBehodler) {
    uint256 daiToRelease = BehodlerLike(VARS.behodler).withdrawLiquidityFindSCX(
      VARS.DAI,
      10000,
      1 ether,
      VARS.precision
    );
    dai_scx = (daiToRelease * EXA) / (1 ether);
    daiBalanceOnBehodler = IERC20(VARS.DAI).balanceOf(VARS.behodler);
  }
  function stabilizeFlan(uint256 rectangleOfFairness) public override onlyLimbo ensurePriceStability returns (uint256 lpMinted) {
    uint256 localSCXBalance = IERC20(VARS.behodler).balanceOf(address(this));
    require((localSCXBalance * 100) / rectangleOfFairness == 98, "EM");
    rectangleOfFairness = localSCXBalance;
    uint256 existingSCXBalanceOnLP = IERC20(VARS.behodler).balanceOf(address(VARS.Flan_SCX_tokenPair));
    uint256 finalSCXBalanceOnLP = existingSCXBalanceOnLP + rectangleOfFairness;
    uint256 DesiredFinalFlanOnLP = ((finalSCXBalanceOnLP * latestFlanQuotes[0].DaiScxSpotPrice) / EXA);
    address pair = address(VARS.Flan_SCX_tokenPair);
    uint256 existingFlanOnLP = IERC20(VARS.flan).balanceOf(pair);
    if (existingFlanOnLP < DesiredFinalFlanOnLP) {
      uint256 flanToMint = ((DesiredFinalFlanOnLP - existingFlanOnLP) * (100 - VARS.priceBoostOvershoot)) / 100;
      flanToMint = flanToMint == 0 ? DesiredFinalFlanOnLP - existingFlanOnLP : flanToMint;
      FlanLike(VARS.flan).mint(pair, flanToMint);
      IERC20(VARS.behodler).transfer(pair, rectangleOfFairness);
      {
        lpMinted = VARS.Flan_SCX_tokenPair.mint(VARS.blackHole);
      }
    } else {
      uint256 minFlan = existingFlanOnLP / VARS.Flan_SCX_tokenPair.totalSupply();
      FlanLike(VARS.flan).mint(pair, minFlan + 2);
      IERC20(VARS.behodler).transfer(pair, rectangleOfFairness);
      lpMinted = VARS.Flan_SCX_tokenPair.mint(VARS.blackHole);
    }
    _zeroOutQuotes();
  }
  function minAPY_to_FPS(
    uint256 minAPY, 
    uint256 daiThreshold
  ) public override view ensurePriceStability returns (uint256 fps) {
    daiThreshold = daiThreshold == 0 ? latestFlanQuotes[0].DaiBalanceOnBehodler : daiThreshold;
    uint256 returnOnThreshold = (minAPY * daiThreshold) / 1e4;
    fps = returnOnThreshold / (year);
  }
  function buyFlanAndBurn(
    address inputToken,
    uint256 amount,
    address recipient
  ) public override {
    address pair = VARS.factory.getPair(inputToken, VARS.flan);
    uint256 flanBalance = IERC20(VARS.flan).balanceOf(pair);
    uint256 inputBalance = IERC20(inputToken).balanceOf(pair);
    uint256 amountOut = getAmountOut(amount, inputBalance, flanBalance);
    uint256 amount0Out = inputToken < VARS.flan ? 0 : amountOut;
    uint256 amount1Out = inputToken < VARS.flan ? amountOut : 0;
    IERC20(inputToken).transfer(pair, amount);
    UniPairLike(pair).swap(amount0Out, amount1Out, address(this), "");
    uint256 reward = (amountOut / 100);
    ERC20Burnable(VARS.flan).transfer(recipient, reward);
    ERC20Burnable(VARS.flan).burn(amountOut - reward);
  }
  function getAmountOut(
    uint256 amountIn,
    uint256 reserveIn,
    uint256 reserveOut
  ) internal pure returns (uint256 amountOut) {
    uint256 amountInWithFee = amountIn * 997;
    uint256 numerator = amountInWithFee * reserveOut;
    uint256 denominator = reserveIn * 1000 + amountInWithFee;
    amountOut = numerator / denominator;
  }
  function getAmountIn(
    uint256 amountOut,
    uint256 reserveIn,
    uint256 reserveOut
  ) internal pure returns (uint256 amountIn) {
    uint256 numerator = reserveIn * amountOut * 1000;
    uint256 denominator = (reserveOut - amountOut) * 997;
    amountIn = (numerator / denominator) + 1;
  }
  function _zeroOutQuotes() internal {
    delete latestFlanQuotes[0];
    delete latestFlanQuotes[1];
  }
  function _ensurePriceStability() internal view {
    FlanQuote[2] memory localFlanQuotes; 
    localFlanQuotes[0] = latestFlanQuotes[0];
    localFlanQuotes[1] = latestFlanQuotes[1];
    uint256 daiSCXSpotPriceDivergence = localFlanQuotes[0].DaiScxSpotPrice > localFlanQuotes[1].DaiScxSpotPrice
      ? (localFlanQuotes[0].DaiScxSpotPrice * 100) / localFlanQuotes[1].DaiScxSpotPrice
      : (localFlanQuotes[1].DaiScxSpotPrice * 100) / localFlanQuotes[0].DaiScxSpotPrice;
    uint256 daiBalanceDivergence = localFlanQuotes[0].DaiBalanceOnBehodler > localFlanQuotes[1].DaiBalanceOnBehodler
      ? (localFlanQuotes[0].DaiBalanceOnBehodler * 100) / localFlanQuotes[1].DaiBalanceOnBehodler
      : (localFlanQuotes[1].DaiBalanceOnBehodler * 100) / localFlanQuotes[0].DaiBalanceOnBehodler;
    require(
      daiSCXSpotPriceDivergence < VARS.divergenceTolerance && daiBalanceDivergence < VARS.divergenceTolerance,
      "EG"
    );
    require(
      localFlanQuotes[0].blockProduced - localFlanQuotes[1].blockProduced > VARS.minQuoteWaitDuration &&
        localFlanQuotes[1].blockProduced > 0,
      "EH"
    );
  }
}