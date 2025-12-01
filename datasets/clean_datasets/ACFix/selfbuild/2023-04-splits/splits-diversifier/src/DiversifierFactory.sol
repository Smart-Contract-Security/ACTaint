pragma solidity ^0.8.17;
import {AddressUtils, ADDRESS_ZERO} from "splits-utils/AddressUtils.sol";
import {ISplitMain} from "splits-utils/interfaces/ISplitMain.sol";
import {LibRecipients, PackedRecipient} from "splits-utils/LibRecipients.sol";
import {OracleImpl} from "splits-oracle/OracleImpl.sol";
import {OracleParams} from "splits-oracle/peripherals/OracleParams.sol";
import {PassThroughWalletImpl} from "splits-pass-through-wallet/PassThroughWalletImpl.sol";
import {PassThroughWalletFactory} from "splits-pass-through-wallet/PassThroughWalletFactory.sol";
import {SwapperImpl} from "splits-swapper/SwapperImpl.sol";
import {SwapperFactory} from "splits-swapper/SwapperFactory.sol";
import {WalletImpl} from "splits-utils/WalletImpl.sol";
contract DiversifierFactory {
    using AddressUtils for address;
    using LibRecipients for PackedRecipient[];
    using {LibRecipients._pack} for address;
    event CreateDiversifier(address indexed diversifier);
    struct CreateDiversifierParams {
        address owner;
        bool paused;
        OracleParams oracleParams;
        RecipientParams[] recipientParams;
    }
    struct RecipientParams {
        address account;
        CreateSwapperParams createSwapperParams;
        uint32 percentAllocation;
    }
    struct CreateSwapperParams {
        address beneficiary;
        address tokenToBeneficiary;
    }
    ISplitMain public immutable splitMain;
    SwapperFactory public immutable swapperFactory;
    PassThroughWalletFactory public immutable passThroughWalletFactory;
    constructor(
        ISplitMain splitMain_,
        SwapperFactory swapperFactory_,
        PassThroughWalletFactory passThroughWalletFactory_
    ) {
        splitMain = splitMain_;
        swapperFactory = swapperFactory_;
        passThroughWalletFactory = passThroughWalletFactory_;
    }
    function createDiversifier(CreateDiversifierParams calldata params_) external returns (address diversifier) {
        PassThroughWalletImpl passThroughWallet = passThroughWalletFactory.createPassThroughWallet(
            PassThroughWalletImpl.InitParams({owner: address(this), paused: params_.paused, passThrough: ADDRESS_ZERO})
        );
        diversifier = address(passThroughWallet);
        OracleImpl oracle = _parseOracleParams(diversifier, params_.oracleParams);
        (address[] memory sortedAccounts, uint32[] memory sortedPercentAllocations) =
            _parseRecipientParams(diversifier, oracle, params_.recipientParams);
        address passThroughSplit = splitMain.createSplit({
            accounts: sortedAccounts,
            percentAllocations: sortedPercentAllocations,
            distributorFee: 0,
            controller: diversifier
        });
        passThroughWallet.setPassThrough(passThroughSplit);
        passThroughWallet.transferOwnership(params_.owner);
        emit CreateDiversifier(diversifier);
    }
    function _parseRecipientParams(
        address diversifier_,
        OracleImpl oracle_,
        RecipientParams[] calldata recipientParams_
    ) internal returns (address[] memory, uint32[] memory) {
        OracleParams memory swapperOracleParams;
        swapperOracleParams.oracle = oracle_;
        uint256 length = recipientParams_.length;
        PackedRecipient[] memory packedRecipients = new PackedRecipient[](length);
        for (uint256 i; i < length;) {
            RecipientParams calldata recipientParams = recipientParams_[i];
            address account = (recipientParams.account._isNotEmpty())
                ? recipientParams.account
                : address(
                    swapperFactory.createSwapper(
                        SwapperFactory.CreateSwapperParams({
                            owner: diversifier_,
                            paused: false,
                            beneficiary: recipientParams.createSwapperParams.beneficiary,
                            tokenToBeneficiary: recipientParams.createSwapperParams.tokenToBeneficiary,
                            oracleParams: swapperOracleParams
                        })
                    )
                );
            packedRecipients[i] = account._pack(recipientParams.percentAllocation);
            unchecked {
                ++i;
            }
        }
        packedRecipients._sortInPlace();
        return packedRecipients._unpackAccountsInPlace();
    }
    function _parseOracleParams(address diversifier_, OracleParams calldata oracleParams_)
        internal
        returns (OracleImpl oracle)
    {
        oracle = oracleParams_._parseIntoOracle();
        if ((address(oracleParams_.oracle)._isEmpty()) && oracle.owner() == address(this)) {
            oracle.transferOwnership(diversifier_);
        }
    }
}