pragma solidity ^0.8.11;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../Interfaces/ExternalInterfaces/ITruefi.sol";
import "../Interfaces/IProvider.sol";
contract TruefiProvider is IProvider {
  using SafeERC20 for IERC20;
  function deposit(
    uint256 _amount,
    address _tToken,
    address _uToken
  ) external override returns (uint256) {
    uint256 balanceBefore = IERC20(_uToken).balanceOf(address(this));
    IERC20(_uToken).safeTransferFrom(msg.sender, address(this), _amount);
    IERC20(_uToken).safeIncreaseAllowance(_tToken, _amount);
    uint256 balanceAfter = IERC20(_uToken).balanceOf(address(this));
    require((balanceAfter - balanceBefore - _amount) == 0, "Error Deposit: under/overflow");
    uint256 tTokenBefore = ITruefi(_tToken).balanceOf(address(this));
    ITruefi(_tToken).join(_amount);
    uint256 tTokenAfter = ITruefi(_tToken).balanceOf(address(this));
    uint tTokensReceived = tTokenAfter - tTokenBefore;
    ITruefi(_tToken).transfer(msg.sender, tTokensReceived);
    return tTokensReceived;
  }
  function withdraw(
    uint256 _amount,
    address _tToken,
    address _uToken
  ) external override returns (uint256) {
    uint256 balanceBefore = IERC20(_uToken).balanceOf(msg.sender);
    uint256 balanceBeforeRedeem = IERC20(_uToken).balanceOf(address(this));
    require(
      ITruefi(_tToken).transferFrom(msg.sender, address(this), _amount) == true,
      "Error: transferFrom"
    );
    ITruefi(_tToken).liquidExit(_amount);
    uint256 balanceAfterRedeem = IERC20(_uToken).balanceOf(address(this));
    uint256 uTokensReceived = balanceAfterRedeem - balanceBeforeRedeem;
    IERC20(_uToken).safeTransfer(msg.sender, uTokensReceived);
    uint256 balanceAfter = IERC20(_uToken).balanceOf(msg.sender);
    require(
      (balanceAfter - balanceBefore - uTokensReceived) == 0,
      "Error Withdraw: under/overflow"
    );
    return uTokensReceived;
  }
  function balanceUnderlying(
    address _address,
    address _tToken
  ) public view override returns (uint256) {
    uint256 balanceShares = balance(_address, _tToken);
    uint256 currentBalance = (ITruefi(_tToken).poolValue() * balanceShares) /
      ITruefi(_tToken).totalSupply();
    return currentBalance;
  }
  function calcShares(uint256 _amount, address _tToken) external view override returns (uint256) {
    uint256 shares = (ITruefi(_tToken).totalSupply() * _amount) / ITruefi(_tToken).poolValue();
    return shares;
  }
  function balance(address _address, address _tToken) public view override returns (uint256) {
    return ITruefi(_tToken).balanceOf(_address);
  }
  function exchangeRate(address _tToken) public view override returns (uint256) {
    uint256 poolValue = ITruefi(_tToken).poolValue();
    uint256 totalSupply = ITruefi(_tToken).totalSupply();
    return (poolValue * 1E6) / totalSupply;
  }
  function claim(address _tToken, address _claimer) external override returns (bool) {}
}