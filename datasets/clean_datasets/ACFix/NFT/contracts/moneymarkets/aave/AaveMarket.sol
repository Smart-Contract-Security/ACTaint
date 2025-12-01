pragma solidity 0.5.17;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../IMoneyMarket.sol";
import "./imports/ILendingPool.sol";
import "./imports/ILendingPoolAddressesProvider.sol";
contract AaveMarket is IMoneyMarket, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    using Address for address;
    uint16 internal constant REFERRALCODE = 20; 
    ILendingPoolAddressesProvider public provider; 
    ERC20 public stablecoin;
    ERC20 public aToken;
    constructor(
        address _provider,
        address _aToken,
        address _stablecoin
    ) public {
        require(
            _provider.isContract() &&
                _aToken.isContract() &&
                _stablecoin.isContract(),
            "AaveMarket: An input address is not a contract"
        );
        provider = ILendingPoolAddressesProvider(_provider);
        stablecoin = ERC20(_stablecoin);
        aToken = ERC20(_aToken);
    }
    function deposit(uint256 amount) external onlyOwner {
        require(amount > 0, "AaveMarket: amount is 0");
        ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);
        stablecoin.safeIncreaseAllowance(address(lendingPool), amount);
        lendingPool.deposit(
            address(stablecoin),
            amount,
            address(this),
            REFERRALCODE
        );
    }
    function withdraw(uint256 amountInUnderlying)
        external
        onlyOwner
        returns (uint256 actualAmountWithdrawn)
    {
        require(amountInUnderlying > 0, "AaveMarket: amountInUnderlying is 0");
        ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
        lendingPool.withdraw(
            address(stablecoin),
            amountInUnderlying,
            msg.sender
        );
        return amountInUnderlying;
    }
    function claimRewards() external {}
    function totalValue() external returns (uint256) {
        return aToken.balanceOf(address(this));
    }
    function incomeIndex() external returns (uint256) {
        ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
        return lendingPool.getReserveNormalizedIncome(address(stablecoin));
    }
    function setRewards(address newValue) external {}
}