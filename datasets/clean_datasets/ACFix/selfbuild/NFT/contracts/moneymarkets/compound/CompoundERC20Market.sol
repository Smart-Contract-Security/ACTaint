pragma solidity 0.5.17;
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../IMoneyMarket.sol";
import "../../libs/DecMath.sol";
import "./imports/ICERC20.sol";
import "./imports/IComptroller.sol";
contract CompoundERC20Market is IMoneyMarket, Ownable {
    using DecMath for uint256;
    using SafeERC20 for ERC20;
    using Address for address;
    uint256 internal constant ERRCODE_OK = 0;
    ICERC20 public cToken;
    IComptroller public comptroller;
    address public rewards;
    ERC20 public stablecoin;
    constructor(
        address _cToken,
        address _comptroller,
        address _rewards,
        address _stablecoin
    ) public {
        require(
            _cToken.isContract() &&
                _comptroller.isContract() &&
                _rewards.isContract() &&
                _stablecoin.isContract(),
            "CompoundERC20Market: An input address is not a contract"
        );
        cToken = ICERC20(_cToken);
        comptroller = IComptroller(_comptroller);
        rewards = _rewards;
        stablecoin = ERC20(_stablecoin);
    }
    function deposit(uint256 amount) external onlyOwner {
        require(amount > 0, "CompoundERC20Market: amount is 0");
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);
        stablecoin.safeIncreaseAllowance(address(cToken), amount);
        require(
            cToken.mint(amount) == ERRCODE_OK,
            "CompoundERC20Market: Failed to mint cTokens"
        );
    }
    function withdraw(uint256 amountInUnderlying)
        external
        onlyOwner
        returns (uint256 actualAmountWithdrawn)
    {
        require(
            amountInUnderlying > 0,
            "CompoundERC20Market: amountInUnderlying is 0"
        );
        require(
            cToken.redeemUnderlying(amountInUnderlying) == ERRCODE_OK,
            "CompoundERC20Market: Failed to redeem"
        );
        stablecoin.safeTransfer(msg.sender, amountInUnderlying);
        return amountInUnderlying;
    }
    function claimRewards() external {
        comptroller.claimComp(address(this));
        ERC20 comp = ERC20(comptroller.getCompAddress());
        comp.safeTransfer(rewards, comp.balanceOf(address(this)));
    }
    function totalValue() external returns (uint256) {
        uint256 cTokenBalance = cToken.balanceOf(address(this));
        uint256 cTokenPrice = cToken.exchangeRateCurrent();
        return cTokenBalance.decmul(cTokenPrice);
    }
    function incomeIndex() external returns (uint256) {
        return cToken.exchangeRateCurrent();
    }
    function setRewards(address newValue) external onlyOwner {
        require(newValue.isContract(), "CompoundERC20Market: not contract");
        rewards = newValue;
        emit ESetParamAddress(msg.sender, "rewards", newValue);
    }
}