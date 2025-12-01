pragma solidity 0.5.17;
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../IMoneyMarket.sol";
import "../../libs/DecMath.sol";
import "./imports/ICERC20.sol";
contract CreamERC20Market is IMoneyMarket, Ownable {
    using DecMath for uint256;
    using SafeERC20 for ERC20;
    using Address for address;
    uint256 internal constant ERRCODE_OK = 0;
    ICERC20 public cToken;
    ERC20 public stablecoin;
    constructor(address _cToken, address _stablecoin) public {
        require(
            _cToken.isContract() && _stablecoin.isContract(),
            "CreamERC20Market: An input address is not a contract"
        );
        cToken = ICERC20(_cToken);
        stablecoin = ERC20(_stablecoin);
    }
    function deposit(uint256 amount) external onlyOwner {
        require(amount > 0, "CreamERC20Market: amount is 0");
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);
        stablecoin.safeIncreaseAllowance(address(cToken), amount);
        require(
            cToken.mint(amount) == ERRCODE_OK,
            "CreamERC20Market: Failed to mint cTokens"
        );
    }
    function withdraw(uint256 amountInUnderlying)
        external
        onlyOwner
        returns (uint256 actualAmountWithdrawn)
    {
        require(
            amountInUnderlying > 0,
            "CreamERC20Market: amountInUnderlying is 0"
        );
        require(
            cToken.redeemUnderlying(amountInUnderlying) == ERRCODE_OK,
            "CreamERC20Market: Failed to redeem"
        );
        stablecoin.safeTransfer(msg.sender, amountInUnderlying);
        return amountInUnderlying;
    }
    function claimRewards() external {}
    function totalValue() external returns (uint256) {
        uint256 cTokenBalance = cToken.balanceOf(address(this));
        uint256 cTokenPrice = cToken.exchangeRateCurrent();
        return cTokenBalance.decmul(cTokenPrice);
    }
    function incomeIndex() external returns (uint256) {
        return cToken.exchangeRateCurrent();
    }
    function setRewards(address newValue) external onlyOwner {}
}