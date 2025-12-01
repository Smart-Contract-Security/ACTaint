pragma solidity 0.8.13;
import "./interfaces/IIncentivesVault.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IMorpho.sol";
import "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract IncentivesVault is IIncentivesVault, Ownable {
    using SafeTransferLib for ERC20;
    uint256 public constant MAX_BASIS_POINTS = 10_000;
    IMorpho public immutable morpho; 
    IComptroller public immutable comptroller; 
    ERC20 public immutable morphoToken; 
    IOracle public oracle; 
    address public morphoDao; 
    uint256 public bonus; 
    bool public isPaused; 
    event OracleSet(address newOracle);
    event MorphoDaoSet(address newMorphoDao);
    event BonusSet(uint256 newBonus);
    event PauseStatusSet(bool newStatus);
    event TokensTransferred(address indexed token, uint256 amount);
    event CompTokensTraded(address indexed receiver, uint256 compAmount, uint256 morphoAmount);
    error OnlyMorpho();
    error VaultIsPaused();
    constructor(
        IComptroller _comptroller,
        IMorpho _morpho,
        ERC20 _morphoToken,
        address _morphoDao,
        IOracle _oracle
    ) {
        morpho = _morpho;
        comptroller = _comptroller;
        morphoToken = _morphoToken;
        morphoDao = _morphoDao;
        oracle = _oracle;
    }
    function setOracle(IOracle _newOracle) external onlyOwner {
        oracle = _newOracle;
        emit OracleSet(address(_newOracle));
    }
    function setMorphoDao(address _newMorphoDao) external onlyOwner {
        morphoDao = _newMorphoDao;
        emit MorphoDaoSet(_newMorphoDao);
    }
    function setBonus(uint256 _newBonus) external onlyOwner {
        bonus = _newBonus;
        emit BonusSet(_newBonus);
    }
    function setPauseStatus(bool _newStatus) external onlyOwner {
        isPaused = _newStatus;
        emit PauseStatusSet(_newStatus);
    }
    function transferTokensToDao(address _token, uint256 _amount) external onlyOwner {
        ERC20(_token).safeTransfer(morphoDao, _amount);
        emit TokensTransferred(_token, _amount);
    }
    function tradeCompForMorphoTokens(address _receiver, uint256 _amount) external {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (isPaused) revert VaultIsPaused();
        ERC20(comptroller.getCompAddress()).safeTransferFrom(msg.sender, morphoDao, _amount);
        uint256 amountOut = (oracle.consult(_amount) * (MAX_BASIS_POINTS + bonus)) /
            MAX_BASIS_POINTS;
        morphoToken.safeTransfer(_receiver, amountOut);
        emit CompTokensTraded(_receiver, _amount, amountOut);
    }
}