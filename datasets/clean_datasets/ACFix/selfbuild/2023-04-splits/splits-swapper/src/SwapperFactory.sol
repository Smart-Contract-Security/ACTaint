pragma solidity ^0.8.17;
import {OracleImpl} from "splits-oracle/OracleImpl.sol";
import {OracleParams} from "splits-oracle/peripherals/OracleParams.sol";
import {LibClone} from "splits-utils/LibClone.sol";
import {SwapperImpl} from "./SwapperImpl.sol";
contract SwapperFactory {
    using LibClone for address;
    event CreateSwapper(SwapperImpl indexed swapper, SwapperImpl.InitParams params);
    struct CreateSwapperParams {
        address owner;
        bool paused;
        address beneficiary;
        address tokenToBeneficiary;
        OracleParams oracleParams;
    }
    SwapperImpl public immutable swapperImpl;
    mapping(SwapperImpl => bool) internal $isSwapper;
    constructor() {
        swapperImpl = new SwapperImpl();
    }
    function createSwapper(CreateSwapperParams calldata params_) external returns (SwapperImpl swapper) {
        OracleImpl oracle = params_.oracleParams._parseIntoOracle();
        swapper = SwapperImpl(payable(address(swapperImpl).clone()));
        SwapperImpl.InitParams memory swapperInitParams = SwapperImpl.InitParams({
            owner: params_.owner,
            paused: params_.paused,
            beneficiary: params_.beneficiary,
            tokenToBeneficiary: params_.tokenToBeneficiary,
            oracle: oracle
        });
        swapper.initializer(swapperInitParams);
        $isSwapper[swapper] = true;
        emit CreateSwapper({swapper: swapper, params: swapperInitParams});
    }
    function isSwapper(SwapperImpl swapper) external view returns (bool) {
        return $isSwapper[swapper];
    }
}