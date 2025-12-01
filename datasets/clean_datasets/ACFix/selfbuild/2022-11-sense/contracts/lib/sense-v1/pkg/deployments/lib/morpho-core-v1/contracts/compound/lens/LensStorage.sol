pragma solidity 0.8.13;
import "../interfaces/compound/ICompound.sol";
import "../interfaces/IMorpho.sol";
import "../libraries/CompoundMath.sol";
import "../libraries/InterestRatesModel.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
abstract contract LensStorage is Initializable {
    uint256 public constant MAX_BASIS_POINTS = 10_000; 
    uint256 public constant WAD = 1e18;
    IMorpho public morpho;
    IComptroller public comptroller;
    IRewardsManager public rewardsManager;
    constructor() initializer {}
}