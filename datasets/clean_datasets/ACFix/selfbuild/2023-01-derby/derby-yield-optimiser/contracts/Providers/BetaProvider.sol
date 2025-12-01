pragma solidity ^0.8.11;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../Interfaces/ExternalInterfaces/IBeta.sol";
import "../Interfaces/IProvider.sol";
contract BetaProvider is IProvider {
  using SafeERC20 for IERC20;
  function deposit(
    uint256 _amount,
    address _bToken,
    address _uToken
  ) external override returns (uint256) {
    uint256 balanceBefore = IERC20(_uToken).balanceOf(address(this));
    IERC20(_uToken).safeTransferFrom(msg.sender, address(this), _amount);
    IERC20(_uToken).safeIncreaseAllowance(_bToken, _amount);
    uint256 balanceAfter = IERC20(_uToken).balanceOf(address(this));
    require((balanceAfter - balanceBefore - _amount) == 0, "Error Deposit: under/overflow");
    uint256 tTokenBefore = IBeta(_bToken).balanceOf(address(this));
    IBeta(_bToken).mint(address(this), _amount);
    uint256 tTokenAfter = IBeta(_bToken).balanceOf(address(this));
    uint tTokensReceived = tTokenAfter - tTokenBefore;
    IBeta(_bToken).transfer(msg.sender, tTokensReceived);
    return tTokensReceived;
  }
  function withdraw(
    uint256 _amount,
    address _bToken,
    address _uToken
  ) external override returns (uint256) {
    uint256 balanceBefore = IERC20(_uToken).balanceOf(msg.sender);
    uint256 balanceBeforeRedeem = IERC20(_uToken).balanceOf(address(this));
    require(
      IBeta(_bToken).transferFrom(msg.sender, address(this), _amount) == true,
      "Error: transferFrom"
    );
    IBeta(_bToken).burn(address(this), _amount);
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
    address _bToken
  ) public view override returns (uint256) {
    uint256 balanceShares = balance(_address, _bToken);
    uint256 supply = IBeta(_bToken).totalSupply();
    uint256 totalLoanable = IBeta(_bToken).totalLoanable();
    uint256 totalLoan = IBeta(_bToken).totalLoan();
    return (balanceShares * (totalLoanable + totalLoan)) / supply;
  }
  function calcShares(uint256 _amount, address _bToken) external view override returns (uint256) {
    uint256 supply = IBeta(_bToken).totalSupply();
    uint256 totalLoanable = IBeta(_bToken).totalLoanable();
    uint256 totalLoan = IBeta(_bToken).totalLoan();
    return (_amount * supply) / (totalLoanable + totalLoan);
  }
  function balance(address _address, address _bToken) public view override returns (uint256) {
    return IBeta(_bToken).balanceOf(_address);
  }
  function exchangeRate(address _bToken) public view override returns (uint256) {
  }
  function claim(address _bToken, address _claimer) external override returns (bool) {}
}