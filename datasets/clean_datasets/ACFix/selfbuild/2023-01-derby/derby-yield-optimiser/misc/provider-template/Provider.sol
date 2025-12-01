pragma solidity ^0.8.11;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../Interfaces/IProvider.sol";
import "hardhat/console.sol";
contract NameProvider is IProvider {
  using SafeERC20 for IERC20;
  address public controller; 
  mapping(uint256 => uint256) public historicalPrices;
  modifier onlyController {
    require(msg.sender == controller, "ETFProvider: only controller");
    _;
  }
  constructor(address _controller) {
    controller = _controller;
  }
  function deposit(
    address _vault, 
    uint256 _amount, 
    address _tToken,
    address _uToken
  ) external override onlyController returns(uint256) {
  }
  function withdraw(
    address _vault, 
    uint256 _amount, 
    address _tToken,
    address _uToken
  ) external override onlyController returns(uint256) {
  }
  function balanceUnderlying(address _address, address _tToken) public view override returns(uint256) {
  }
  function calcShares(uint256 _amount, address _tToken) external view override returns(uint256) {
  }
  function balance(address _address, address _tToken) public view override returns(uint256) {
  }
  function exchangeRate(address _tToken) public view override returns(uint256) {
  }
  function claim(address _tToken, address _claimer) external override returns(bool) {
  }
}