pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/ERC20.sol";
import "../interfaces/IwstETH.sol";
contract MockWstETH is ERC20, IwstETH {
    using FixedPoint for uint256;
    IERC20 public override stETH;
    uint256 public rate = 1.5e18;
    constructor(IERC20 token) ERC20("Wrapped Staked Ether", "wstETH") {
        stETH = token;
    }
    function wrap(uint256 _stETHAmount) external override returns (uint256) {
        stETH.transferFrom(msg.sender, address(this), _stETHAmount);
        uint256 wstETHAmount = getWstETHByStETH(_stETHAmount);
        _mint(msg.sender, wstETHAmount);
        return wstETHAmount;
    }
    function unwrap(uint256 _wstETHAmount) external override returns (uint256) {
        _burn(msg.sender, _wstETHAmount);
        uint256 stETHAmount = getStETHByWstETH(_wstETHAmount);
        stETH.transfer(msg.sender, stETHAmount);
        return stETHAmount;
    }
    function getWstETHByStETH(uint256 _stETHAmount) public view override returns (uint256) {
        return _stETHAmount.divDown(rate);
    }
    function getStETHByWstETH(uint256 _wstETHAmount) public view override returns (uint256) {
        return _wstETHAmount.mulDown(rate);
    }
    function stEthPerToken() external view override returns (uint256) {
        return getStETHByWstETH(1 ether);
    }
    function tokensPerStEth() external view override returns (uint256) {
        return getWstETHByStETH(1 ether);
    }
}