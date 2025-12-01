pragma solidity ^0.8.4;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {EulerMock} from "./EulerMock.sol";
import {IEulerEToken} from "../../../euler/external/IEulerEToken.sol";
contract EulerETokenMock is IEulerEToken, ERC20("EulerETokenMock", "eMOCK", 18) {
    using FixedPointMathLib for uint256;
    EulerMock public euler;
    ERC20 public underlying;
    constructor(ERC20 underlying_, EulerMock euler_) {
        euler = euler_;
        underlying = underlying_;
    }
    function balanceOfUnderlying(address account) external view returns (uint256) {
        uint256 supply = totalSupply; 
        uint256 shares = balanceOf[account];
        return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
    }
    function deposit(uint256, uint256 amount) external override {
        euler.transferTokenFrom(underlying, msg.sender, address(this), amount);
        _mint(msg.sender, convertToShares(amount));
    }
    function withdraw(uint256, uint256 amount) external override {
        _burn(msg.sender, previewWithdraw(amount));
        underlying.transfer(msg.sender, amount);
    }
    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply; 
        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
    }
    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply; 
        return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
    }
    function totalAssets() public view virtual returns (uint256) {
        return underlying.balanceOf(address(this));
    }
}