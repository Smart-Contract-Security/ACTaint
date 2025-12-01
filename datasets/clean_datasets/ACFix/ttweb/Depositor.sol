pragma solidity =0.8.9;
import "./DepositReceipt_USDC.sol";
import "./Interfaces/IGauge.sol";
import "./Interfaces/IRouter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract Depositor is Ownable {
    using SafeERC20 for IERC20;
    DepositReceipt_USDC public immutable depositReceipt;
    IERC20 public immutable AMMToken;
    IGauge public immutable gauge;
    constructor(
                address _depositReceipt,
                address _AMMToken,
                address _gauge
                ){
        AMMToken = IERC20(_AMMToken);
        gauge = IGauge(_gauge);
        depositReceipt = DepositReceipt_USDC(_depositReceipt);
    }
    function onERC721Received(
        address operator,
        address from,
        uint tokenId,
        bytes calldata data
    ) external returns (bytes4){
        return(IERC721Receiver.onERC721Received.selector);
    }
    function depositToGauge(uint256 _amount) onlyOwner() external returns(uint256){
        AMMToken.transferFrom(msg.sender, address(this), _amount);
        AMMToken.safeIncreaseAllowance(address(gauge), _amount);
        gauge.deposit(_amount, 0);
        uint256 NFTId = depositReceipt.safeMint(_amount);
        depositReceipt.safeTransferFrom(address(this), msg.sender, NFTId);
        return(NFTId);
    }
    function partialWithdrawFromGauge(uint256 _NFTId, uint256 _percentageSplit, address[] memory _tokens) public {
        uint256 newNFTId = depositReceipt.split(_NFTId, _percentageSplit);
        withdrawFromGauge(newNFTId, _tokens);
    }
    function multiWithdrawFromGauge(
        uint256[] memory _NFTIds,
        bool _usingPartial,
        uint256 _partialNFTId,
        uint256 _percentageSplit,
        address[] memory _tokens
        ) external {
        uint256 length = _NFTIds.length;
        for (uint256 i = 0; i < length; i++ ){
            withdrawFromGauge(_NFTIds[i], _tokens);
        }
        if(_usingPartial){
            partialWithdrawFromGauge(_partialNFTId, _percentageSplit, _tokens);
        }
    }
    function withdrawFromGauge(uint256 _NFTId, address[] memory _tokens)  public  {
        uint256 amount = depositReceipt.pooledTokens(_NFTId);
        depositReceipt.burn(_NFTId);
        gauge.getReward(address(this), _tokens);
        gauge.withdraw(amount);
        AMMToken.transfer(msg.sender, amount);
    }
    function claimRewards( address[] memory _tokens) onlyOwner() external {
        require(_tokens.length > 0, "Empty tokens array");
        gauge.getReward(address(this), _tokens);
        uint256 length =  _tokens.length;
        for (uint i = 0; i < length; i++) {
            uint256 balance = IERC20(_tokens[i]).balanceOf(address(this));
            IERC20(_tokens[i]).safeTransfer(msg.sender, balance);
        }
    }
    function viewPendingRewards(address _token) external view returns(uint256){
        return gauge.earned(_token, address(this));
    }
}