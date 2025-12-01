pragma solidity ^0.8.17;
interface ISwapperFlashCallback {
    function swapperFlashCallback(address tokenToBeneficiary, uint256 amountToBeneficiary, bytes calldata data)
        external;
}