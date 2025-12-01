pragma solidity ^0.5.10;
contract DepositLog {
    event Created(
        address indexed _depositContractAddress,
        address indexed _keepAddress,
        uint256 _timestamp
    );
    event RedemptionRequested(
        address indexed _depositContractAddress,
        address indexed _requester,
        bytes32 indexed _digest,
        uint256 _utxoSize,
        bytes _redeemerOutputScript,
        uint256 _requestedFee,
        bytes _outpoint
    );
    event GotRedemptionSignature(
        address indexed _depositContractAddress,
        bytes32 indexed _digest,
        bytes32 _r,
        bytes32 _s,
        uint256 _timestamp
    );
    event RegisteredPubkey(
        address indexed _depositContractAddress,
        bytes32 _signingGroupPubkeyX,
        bytes32 _signingGroupPubkeyY,
        uint256 _timestamp
    );
    event SetupFailed(
        address indexed _depositContractAddress,
        uint256 _timestamp
    );
    event FraudDuringSetup(
        address indexed _depositContractAddress,
        uint256 _timestamp
    );
    event Funded(address indexed _depositContractAddress, uint256 _timestamp);
    event CourtesyCalled(
        address indexed _depositContractAddress,
        uint256 _timestamp
    );
    event ExitedCourtesyCall(
        address indexed _depositContractAddress,
        uint256 _timestamp
    );
    event StartedLiquidation(
        address indexed _depositContractAddress,
        bool _wasFraud,
        uint256 _timestamp
    );
    event Redeemed(
        address indexed _depositContractAddress,
        bytes32 indexed _txid,
        uint256 _timestamp
    );
    event Liquidated(
        address indexed _depositContractAddress,
        uint256 _timestamp
    );
    function approvedToLog(address _caller) public pure returns (bool) {
        _caller;
        return true;
    }
    function logCreated(address _keepAddress) public returns (bool) {
        if (!approvedToLog(msg.sender)) return false;
        emit Created(msg.sender, _keepAddress, block.timestamp);
        return true;
    }
    function logRedemptionRequested(
        address _requester,
        bytes32 _digest,
        uint256 _utxoSize,
        bytes memory _redeemerOutputScript,
        uint256 _requestedFee,
        bytes memory _outpoint
    ) public returns (bool) {
        if (!approvedToLog(msg.sender)) return false;
        emit RedemptionRequested(
            msg.sender,
            _requester,
            _digest,
            _utxoSize,
            _redeemerOutputScript,
            _requestedFee,
            _outpoint
        );
        return true;
    }
    function logGotRedemptionSignature(bytes32 _digest, bytes32 _r, bytes32 _s)
        public
        returns (bool)
    {
        if (!approvedToLog(msg.sender)) return false;
        emit GotRedemptionSignature(
            msg.sender,
            _digest,
            _r,
            _s,
            block.timestamp
        );
        return true;
    }
    function logRegisteredPubkey(
        bytes32 _signingGroupPubkeyX,
        bytes32 _signingGroupPubkeyY
    ) public returns (bool) {
        if (!approvedToLog(msg.sender)) return false;
        emit RegisteredPubkey(
            msg.sender,
            _signingGroupPubkeyX,
            _signingGroupPubkeyY,
            block.timestamp
        );
        return true;
    }
    function logSetupFailed() public returns (bool) {
        if (!approvedToLog(msg.sender)) return false;
        emit SetupFailed(msg.sender, block.timestamp);
        return true;
    }
    function logFraudDuringSetup() public returns (bool) {
        if (!approvedToLog(msg.sender)) return false;
        emit FraudDuringSetup(msg.sender, block.timestamp);
        return true;
    }
    function logFunded() public returns (bool) {
        if (!approvedToLog(msg.sender)) return false;
        emit Funded(msg.sender, block.timestamp);
        return true;
    }
    function logCourtesyCalled() public returns (bool) {
        if (!approvedToLog(msg.sender)) return false;
        emit CourtesyCalled(msg.sender, block.timestamp);
        return true;
    }
    function logStartedLiquidation(bool _wasFraud) public returns (bool) {
        if (!approvedToLog(msg.sender)) return false;
        emit StartedLiquidation(msg.sender, _wasFraud, block.timestamp);
        return true;
    }
    function logRedeemed(bytes32 _txid) public returns (bool) {
        if (!approvedToLog(msg.sender)) return false;
        emit Redeemed(msg.sender, _txid, block.timestamp);
        return true;
    }
    function logLiquidated() public returns (bool) {
        if (!approvedToLog(msg.sender)) return false;
        emit Liquidated(msg.sender, block.timestamp);
        return true;
    }
    function logExitedCourtesyCall() public returns (bool) {
        if (!approvedToLog(msg.sender)) return false;
        emit ExitedCourtesyCall(msg.sender, block.timestamp);
        return true;
    }
}