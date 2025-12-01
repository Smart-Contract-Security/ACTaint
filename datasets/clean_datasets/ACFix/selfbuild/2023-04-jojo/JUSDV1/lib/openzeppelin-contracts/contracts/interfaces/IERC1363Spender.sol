pragma solidity ^0.8.0;
interface IERC1363Spender {
    function onApprovalReceived(address owner, uint256 amount, bytes memory data) external returns (bytes4);
}