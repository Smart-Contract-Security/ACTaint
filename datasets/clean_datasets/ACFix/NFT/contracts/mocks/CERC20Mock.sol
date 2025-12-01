pragma solidity 0.5.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
contract CERC20Mock is ERC20, ERC20Detailed {
    address public dai;
    uint256 internal _supplyRate;
    uint256 internal _exchangeRate;
    constructor(address _dai) public ERC20Detailed("cDAI", "cDAI", 8) {
        dai = _dai;
        uint256 daiDecimals = ERC20Detailed(_dai).decimals();
        _exchangeRate = 2 * (10**(daiDecimals + 8)); 
        _supplyRate = 45290900000; 
    }
    function mint(uint256 amount) external returns (uint256) {
        require(
            ERC20(dai).transferFrom(msg.sender, address(this), amount),
            "Error during transferFrom"
        ); 
        _mint(msg.sender, (amount * 10**18) / _exchangeRate);
        return 0;
    }
    function redeemUnderlying(uint256 amount) external returns (uint256) {
        _burn(msg.sender, (amount * 10**18) / _exchangeRate);
        require(
            ERC20(dai).transfer(msg.sender, amount),
            "Error during transfer"
        ); 
        return 0;
    }
    function exchangeRateStored() external view returns (uint256) {
        return _exchangeRate;
    }
    function exchangeRateCurrent() external view returns (uint256) {
        return _exchangeRate;
    }
    function _setExchangeRateStored(uint256 _rate) external returns (uint256) {
        _exchangeRate = _rate;
    }
    function supplyRatePerBlock() external view returns (uint256) {
        return _supplyRate;
    }
    function _setSupplyRatePerBlock(uint256 _rate) external {
        _supplyRate = _rate;
    }
}