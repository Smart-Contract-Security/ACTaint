pragma solidity ^0.8.17;
import {SwapperFactory} from "../SwapperFactory.sol";
import {SwapperImpl} from "../SwapperImpl.sol";
library SwapperCallbackValidation {
    function verifyCallback(SwapperFactory factory_, SwapperImpl swapper_) internal view returns (bool valid) {
        return factory_.isSwapper(swapper_);
    }
}