pragma solidity 0.8.9;
library Types {
    struct State {
        address primaryAsset;
        address secondaryAsset;
        mapping(address => int256) primaryCredit;
        mapping(address => uint256) secondaryCredit;
        uint256 withdrawTimeLock;
        mapping(address => uint256) pendingPrimaryWithdraw;
        mapping(address => uint256) pendingSecondaryWithdraw;
        mapping(address => uint256) withdrawExecutionTimestamp;
        mapping(address => Types.RiskParams) perpRiskParams;
        address[] registeredPerp;
        mapping(address => address[]) openPositions;
        mapping(address => mapping(address => uint256)) positionSerialNum;
        mapping(bytes32 => uint256) orderFilledPaperAmount;
        mapping(address => bool) validOrderSender;
        mapping(address => mapping(address => bool)) operatorRegistry;
        address insurance;
        address fundingRateKeeper;
    }
    struct Order {
        address perp;
        address signer;
        int128 paperAmount;
        int128 creditAmount;
        bytes32 info;
    }
    bytes32 public constant ORDER_TYPEHASH =
        keccak256(
            "Order(address perp,address signer,int128 paperAmount,int128 creditAmount,bytes32 info)"
        );
    struct RiskParams {
        uint256 liquidationThreshold;
        uint256 liquidationPriceOff;
        uint256 insuranceFeeRate;
        address markPriceSource;
        string name;
        bool isRegistered;
    }
    struct MatchResult {
        address[] traderList;
        int256[] paperChangeList;
        int256[] creditChangeList;
        int256 orderSenderFee;
    }
    uint256 constant ONE = 10**18;
}