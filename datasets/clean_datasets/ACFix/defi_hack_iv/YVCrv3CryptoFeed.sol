pragma solidity ^0.8.4;
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}
interface IAggregator {
    function latestAnswer() external view returns (int256 answer);
}
interface ICurvePool {
    function get_virtual_price() external view returns (uint256 price);
}
interface IFeed {
    function decimals() external view returns (uint8);
    function latestAnswer() external view returns (uint);
}
interface IYearnVault {
    function pricePerShare() external view returns (uint256 price);
}
contract YVCrv3CryptoFeed is IFeed {
    ICurvePool public constant CRV3CRYPTO = ICurvePool(0xD51a44d3FaE010294C616388b506AcdA1bfAAE46);
    IYearnVault public constant vault = IYearnVault(0xE537B5cc158EB71037D4125BDD7538421981E6AA);
    IAggregator public constant BTCFeed = IAggregator(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);
    IAggregator public constant ETHFeed = IAggregator(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    IAggregator public constant USDTFeed = IAggregator(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D);
    IERC20 public WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 public WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 public USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 public crv3CryptoLPToken = IERC20(0xc4AD29ba4B3c580e6D59105FFf484999997675Ff);
    function latestAnswer() public view returns (uint256) {
        uint256 crvPoolBtcVal = WBTC.balanceOf(address(CRV3CRYPTO)) * uint256(BTCFeed.latestAnswer()) * 1e2;
        uint256 crvPoolWethVal = WETH.balanceOf(address(CRV3CRYPTO)) * uint256(ETHFeed.latestAnswer()) / 1e8;
        uint256 crvPoolUsdtVal = USDT.balanceOf(address(CRV3CRYPTO)) * uint256(USDTFeed.latestAnswer()) * 1e4;
        uint256 crvLPTokenPrice = (crvPoolBtcVal + crvPoolWethVal + crvPoolUsdtVal) * 1e18 / crv3CryptoLPToken.totalSupply();
        return (crvLPTokenPrice * vault.pricePerShare()) / 1e18;
    }
    function decimals() public pure returns (uint8) {
        return 18;
    }
}