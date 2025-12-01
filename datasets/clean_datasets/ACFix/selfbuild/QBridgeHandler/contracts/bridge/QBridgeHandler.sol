pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IQBridgeHandler.sol";
import "../interfaces/IQBridgeDelegator.sol";
import "../library/SafeToken.sol";
import "./QBridgeToken.sol";
contract QBridgeHandler is IQBridgeHandler, OwnableUpgradeable {
    using SafeMath for uint;
    using SafeToken for address;
    uint public constant OPTION_QUBIT_BNB_NONE = 100;
    uint public constant OPTION_QUBIT_BNB_0100 = 110;
    uint public constant OPTION_QUBIT_BNB_0050 = 105;
    uint public constant OPTION_BUNNY_XLP_0150 = 215;
    address public constant ETH = 0x0000000000000000000000000000000000000000;
    address public _bridgeAddress;
    mapping(bytes32 => address) public resourceIDToTokenContractAddress; 
    mapping(address => bytes32) public tokenContractAddressToResourceID; 
    mapping(address => bool) public burnList; 
    mapping(address => bool) public contractWhitelist; 
    mapping(uint => address) public delegators; 
    mapping(bytes32 => uint) public withdrawalFees; 
    mapping(bytes32 => mapping(uint => uint)) public minAmounts; 
    receive() external payable {}
    function initialize(address bridgeAddress) external initializer {
        __Ownable_init();
        _bridgeAddress = bridgeAddress;
    }
    modifier onlyBridge() {
        require(msg.sender == _bridgeAddress, "QBridgeHandler: caller is not the bridge contract");
        _;
    }
    function setResource(bytes32 resourceID, address contractAddress) external override onlyBridge {
        resourceIDToTokenContractAddress[resourceID] = contractAddress;
        tokenContractAddressToResourceID[contractAddress] = resourceID;
        contractWhitelist[contractAddress] = true;
    }
    function setBurnable(address contractAddress) external override onlyBridge {
        require(contractWhitelist[contractAddress], "QBridgeHandler: contract address is not whitelisted");
        burnList[contractAddress] = true;
    }
    function setDelegator(uint option, address newDelegator) external onlyOwner {
        delegators[option] = newDelegator;
    }
    function setWithdrawalFee(bytes32 resourceID, uint withdrawalFee) external onlyOwner {
        withdrawalFees[resourceID] = withdrawalFee;
    }
    function setMinDepositAmount(bytes32 resourceID, uint option, uint minAmount) external onlyOwner {
        minAmounts[resourceID][option] = minAmount;
    }
    function deposit(bytes32 resourceID, address depositer, bytes calldata data) external override onlyBridge {
        uint option;
        uint amount;
        (option, amount) = abi.decode(data, (uint, uint));
        address tokenAddress = resourceIDToTokenContractAddress[resourceID];
        require(contractWhitelist[tokenAddress], "provided tokenAddress is not whitelisted");
        if (burnList[tokenAddress]) {
            require(amount >= withdrawalFees[resourceID], "less than withdrawal fee");
            QBridgeToken(tokenAddress).burnFrom(depositer, amount);
        } else {
            require(amount >= minAmounts[resourceID][option], "less than minimum amount");
            tokenAddress.safeTransferFrom(depositer, address(this), amount);
        }
    }
    function depositETH(bytes32 resourceID, address depositer, bytes calldata data) external payable override onlyBridge {
        uint option;
        uint amount;
        (option, amount) = abi.decode(data, (uint, uint));
        require(amount == msg.value);
        address tokenAddress = resourceIDToTokenContractAddress[resourceID];
        require(contractWhitelist[tokenAddress], "provided tokenAddress is not whitelisted");
        require(amount >= minAmounts[resourceID][option], "less than minimum amount");
    }
    function executeProposal(bytes32 resourceID, bytes calldata data) external override onlyBridge {
        uint option;
        uint amount;
        address recipientAddress;
        (option, amount, recipientAddress) = abi.decode(data, (uint, uint, address));
        address tokenAddress = resourceIDToTokenContractAddress[resourceID];
        require(contractWhitelist[tokenAddress], "provided tokenAddress is not whitelisted");
        if (burnList[tokenAddress]) {
            address delegatorAddress = delegators[option];
            if (delegatorAddress == address(0)) {
                QBridgeToken(tokenAddress).mint(recipientAddress, amount);
            } else {
                QBridgeToken(tokenAddress).mint(delegatorAddress, amount);
                IQBridgeDelegator(delegatorAddress).delegate(tokenAddress, recipientAddress, option, amount);
            }
        } else if (tokenAddress == ETH) {
            SafeToken.safeTransferETH(recipientAddress, amount.sub(withdrawalFees[resourceID]));
        } else {
            tokenAddress.safeTransfer(recipientAddress, amount.sub(withdrawalFees[resourceID]));
        }
    }
    function withdraw(address tokenAddress, address recipient, uint amount) external override onlyBridge {
        if (tokenAddress == ETH)
            SafeToken.safeTransferETH(recipient, amount);
        else
            tokenAddress.safeTransfer(recipient, amount);
    }
}