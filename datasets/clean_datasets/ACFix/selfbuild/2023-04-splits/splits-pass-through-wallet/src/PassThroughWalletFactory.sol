pragma solidity ^0.8.17;
import {LibClone} from "splits-utils/LibClone.sol";
import {PassThroughWalletImpl} from "./PassThroughWalletImpl.sol";
contract PassThroughWalletFactory {
    using LibClone for address;
    event CreatePassThroughWallet(
        PassThroughWalletImpl indexed passThroughWallet, PassThroughWalletImpl.InitParams params
    );
    PassThroughWalletImpl public immutable passThroughWalletImpl;
    constructor() {
        passThroughWalletImpl = new PassThroughWalletImpl();
    }
    function createPassThroughWallet(PassThroughWalletImpl.InitParams calldata params_)
        external
        returns (PassThroughWalletImpl passThroughWallet)
    {
        passThroughWallet = PassThroughWalletImpl(payable(address(passThroughWalletImpl).clone()));
        passThroughWallet.initializer(params_);
        emit CreatePassThroughWallet({passThroughWallet: passThroughWallet, params: params_});
    }
}