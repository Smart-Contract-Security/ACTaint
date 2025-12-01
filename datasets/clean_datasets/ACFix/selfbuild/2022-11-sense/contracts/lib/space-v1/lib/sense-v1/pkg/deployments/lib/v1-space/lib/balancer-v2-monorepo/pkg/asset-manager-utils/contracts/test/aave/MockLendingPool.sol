pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/IERC20.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/ERC20.sol";
import "../../aave/DataTypes.sol";
contract MockAToken is ERC20 {
    address public owner;
    constructor(
        address admin,
        string memory name,
        string memory symbol,
        uint8 
    ) ERC20(name, symbol) {
        owner = admin;
    }
    function mint(address recipient, uint256 amount) external {
        require(msg.sender == owner, "only owner can mint");
        _mint(recipient, amount);
    }
    function burn(address from, uint256 amount) external {
        require(msg.sender == owner, "only owner can burn");
        _burn(from, amount);
    }
}
contract MockAaveLendingPool {
    uint256 public liquidityIndex = 1e27;
    mapping(address => address) public aTokens;
    function registerAToken(address asset, address aToken) external {
        aTokens[asset] = aToken;
    }
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 
    ) external {
        MockAToken t = MockAToken(aTokens[asset]);
        t.mint(address(onBehalfOf), amount);
        IERC20(asset).transferFrom(onBehalfOf, address(this), amount);
    }
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256) {
        MockAToken t = MockAToken(aTokens[asset]);
        t.burn(to, amount);
        IERC20(asset).transfer(to, amount);
        return amount;
    }
    function getReserveData(
        address 
    ) external view returns (DataTypes.ReserveData memory) {
        return
            DataTypes.ReserveData({
                configuration: DataTypes.ReserveConfigurationMap({ data: 0 }),
                liquidityIndex: 0,
                variableBorrowIndex: 0,
                currentLiquidityRate: 0,
                currentVariableBorrowRate: 0,
                currentStableBorrowRate: 0,
                lastUpdateTimestamp: 0,
                aTokenAddress: address(this),
                stableDebtTokenAddress: address(0),
                variableDebtTokenAddress: address(0),
                interestRateStrategyAddress: address(0),
                id: 0
            });
    }
    function simulateATokenIncrease(
        address asset,
        uint256 amount,
        address to
    ) public {
        MockAToken t = MockAToken(aTokens[asset]);
        t.mint(to, amount);
    }
}