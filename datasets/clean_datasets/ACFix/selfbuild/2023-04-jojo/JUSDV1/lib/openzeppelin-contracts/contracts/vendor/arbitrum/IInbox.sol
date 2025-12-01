pragma solidity >=0.6.9 <0.9.0;
import "./IBridge.sol";
import "./IDelayedMessageProvider.sol";
interface IInbox is IDelayedMessageProvider {
    function bridge() external view returns (IBridge);
    function sequencerInbox() external view returns (address);
    function sendL2MessageFromOrigin(bytes calldata messageData) external returns (uint256);
    function sendL2Message(bytes calldata messageData) external returns (uint256);
    function sendL1FundedUnsignedTransaction(
        uint256 gasLimit,
        uint256 maxFeePerGas,
        uint256 nonce,
        address to,
        bytes calldata data
    ) external payable returns (uint256);
    function sendL1FundedContractTransaction(
        uint256 gasLimit,
        uint256 maxFeePerGas,
        address to,
        bytes calldata data
    ) external payable returns (uint256);
    function sendUnsignedTransaction(
        uint256 gasLimit,
        uint256 maxFeePerGas,
        uint256 nonce,
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (uint256);
    function sendContractTransaction(
        uint256 gasLimit,
        uint256 maxFeePerGas,
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (uint256);
    function calculateRetryableSubmissionFee(uint256 dataLength, uint256 baseFee) external view returns (uint256);
    function depositEth() external payable returns (uint256);
    function createRetryableTicket(
        address to,
        uint256 l2CallValue,
        uint256 maxSubmissionCost,
        address excessFeeRefundAddress,
        address callValueRefundAddress,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        bytes calldata data
    ) external payable returns (uint256);
    function unsafeCreateRetryableTicket(
        address to,
        uint256 l2CallValue,
        uint256 maxSubmissionCost,
        address excessFeeRefundAddress,
        address callValueRefundAddress,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        bytes calldata data
    ) external payable returns (uint256);
    function pause() external;
    function unpause() external;
    function postUpgradeInit(IBridge _bridge) external;
    function initialize(IBridge _bridge, address _sequencerInbox) external;
}