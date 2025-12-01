pragma solidity ^0.8.17;
import {Errors} from "../utils/Errors.sol";
import {Helpers} from "../utils/Helpers.sol";
import {IAccount} from "../interface/core/IAccount.sol";
import {IERC20} from "../interface/tokens/IERC20.sol";
contract Account is IAccount {
    using Helpers for address;
    uint public activationBlock;
    address public accountManager;
    address[] public assets;
    address[] public borrows;
    mapping(address => bool) public hasAsset;
    modifier accountManagerOnly() {
        if (msg.sender != accountManager) revert Errors.AccountManagerOnly();
        _;
    }
    function init(address _accountManager) external {
        if (accountManager != address(0))
            revert Errors.ContractAlreadyInitialized();
        accountManager = _accountManager;
    }
    function activate() external accountManagerOnly {
        activationBlock = block.number;
    }
    function deactivate() external accountManagerOnly {
        activationBlock = 0;
    }
    function getAssets() external view returns (address[] memory) {
        return assets;
    }
    function getBorrows() external view returns (address[] memory) {
        return borrows;
    }
    function addAsset(address token) external accountManagerOnly {
        assets.push(token);
        hasAsset[token] = true;
    }
    function addBorrow(address token) external accountManagerOnly {
        borrows.push(token);
    }
    function removeAsset(address token) external accountManagerOnly {
        _remove(assets, token);
        hasAsset[token] = false;
    }
    function removeBorrow(address token) external accountManagerOnly {
        _remove(borrows, token);
    }
    function hasNoDebt() external view returns (bool) {
        return borrows.length == 0;
    }
    function exec(address target, uint amt, bytes calldata data)
        external
        accountManagerOnly
        returns (bool, bytes memory)
    {
        (bool success, bytes memory retData) = target.call{value: amt}(data);
        return (success, retData);
    }
    function sweepTo(address toAddress) external accountManagerOnly {
        uint assetsLen = assets.length;
        for(uint i; i < assetsLen; ++i) {
            try IERC20(assets[i]).transfer(
                toAddress, assets[i].balanceOf(address(this))
            ) {} catch {}
            if (assets[i].balanceOf(address(this)) == 0)
                hasAsset[assets[i]] = false;
        }
        delete assets;
        toAddress.safeTransferEth(address(this).balance);
    }
    function _remove(address[] storage arr, address token) internal {
        uint len = arr.length;
        for(uint i; i < len; ++i) {
            if (arr[i] == token) {
                arr[i] = arr[arr.length - 1];
                arr.pop();
                break;
            }
        }
    }
    receive() external payable {}
}