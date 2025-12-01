pragma solidity ^0.8.11;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../Interfaces/ExternalInterfaces/IYearn.sol";
import "../Interfaces/IProvider.sol";
contract YearnProvider is IProvider {
  using SafeERC20 for IERC20;
  function deposit(
    uint256 _amount,
    address _yToken,
    address _uToken
  ) external override returns (uint256) {
    uint256 balanceBefore = IERC20(_uToken).balanceOf(address(this));
    IERC20(_uToken).safeTransferFrom(msg.sender, address(this), _amount);
    IERC20(_uToken).safeIncreaseAllowance(_yToken, _amount);
    uint256 balanceAfter = IERC20(_uToken).balanceOf(address(this));
    require((balanceAfter - balanceBefore - _amount) == 0, "Error Deposit: under/overflow");
    uint256 yTokenReceived = IYearn(_yToken).deposit(_amount);
    IYearn(_yToken).transfer(msg.sender, yTokenReceived);
    return yTokenReceived;
  }
  function withdraw(
    uint256 _amount,
    address _yToken,
    address _uToken
  ) external override returns (uint256) {
    uint256 balanceBefore = IERC20(_uToken).balanceOf(msg.sender);
    require(
      IYearn(_yToken).transferFrom(msg.sender, address(this), _amount) == true,
      "Error transferFrom"
    );
    uint256 uAmountReceived = IYearn(_yToken).withdraw(_amount);
    IERC20(_uToken).safeTransfer(msg.sender, uAmountReceived);
    uint256 balanceAfter = IERC20(_uToken).balanceOf(msg.sender);
    require(
      (balanceAfter - balanceBefore - uAmountReceived) == 0,
      "Error Withdraw: under/overflow"
    );
    return uAmountReceived;
  }
  function balanceUnderlying(
    address _address,
    address _yToken
  ) public view override returns (uint256) {
    uint256 balanceShares = balance(_address, _yToken);
    uint256 price = exchangeRate(_yToken);
    return (balanceShares * price) / 10 ** IYearn(_yToken).decimals();
  }
  function calcShares(uint256 _amount, address _yToken) external view override returns (uint256) {
    uint256 shares = (_amount * (10 ** IYearn(_yToken).decimals())) / exchangeRate(_yToken);
    return shares;
  }
  function balance(address _address, address _yToken) public view override returns (uint256) {
    uint256 balanceShares = IYearn(_yToken).balanceOf(_address);
    return balanceShares;
  }
  function exchangeRate(address _yToken) public view override returns (uint256) {
    uint256 price = IYearn(_yToken).pricePerShare();
    return price;
  }
  function claim(address _yToken, address _claimer) public override returns (bool) {}
}