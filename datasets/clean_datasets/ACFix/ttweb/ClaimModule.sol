pragma solidity 0.6.10;
pragma experimental "ABIEncoderV2";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AddressArrayUtils } from "../../../lib/AddressArrayUtils.sol";
import { IClaimAdapter } from "../../../interfaces/IClaimAdapter.sol";
import { IController } from "../../../interfaces/IController.sol";
import { ISetToken } from "../../../interfaces/ISetToken.sol";
import { ModuleBase } from "../../lib/ModuleBase.sol";
contract ClaimModule is ModuleBase {
    using AddressArrayUtils for address[];
    event RewardClaimed(
        ISetToken indexed _setToken,
        address indexed _rewardPool,
        IClaimAdapter indexed _adapter,
        uint256 _amount
    );
    event AnyoneClaimUpdated(
        ISetToken indexed _setToken,
        bool _anyoneClaim
    );
    modifier onlyValidCaller(ISetToken _setToken) {
        require(_isValidCaller(_setToken), "Must be valid caller");
        _;
    }
    mapping(ISetToken => bool) public anyoneClaim;
    mapping(ISetToken => address[]) public rewardPoolList;
    mapping(ISetToken => mapping(address => bool)) public rewardPoolStatus;
    mapping(ISetToken => mapping(address => address[])) public claimSettings;
    mapping(ISetToken => mapping(address => mapping(address => bool))) public claimSettingsStatus;
    constructor(IController _controller) public ModuleBase(_controller) {}
    function claim(
        ISetToken _setToken,
        address _rewardPool,
        string calldata _integrationName
    )
        external
        onlyValidAndInitializedSet(_setToken)
        onlyValidCaller(_setToken)
    {
        _claim(_setToken, _rewardPool, _integrationName);
    }
    function batchClaim(
        ISetToken _setToken,
        address[] calldata _rewardPools,
        string[] calldata _integrationNames
    )
        external
        onlyValidAndInitializedSet(_setToken)
        onlyValidCaller(_setToken)
    {
        uint256 poolArrayLength = _validateBatchArrays(_rewardPools, _integrationNames);
        for (uint256 i = 0; i < poolArrayLength; i++) {
            _claim(_setToken, _rewardPools[i], _integrationNames[i]);
        }
    }
    function updateAnyoneClaim(ISetToken _setToken, bool _anyoneClaim) external onlyManagerAndValidSet(_setToken) {
        anyoneClaim[_setToken] = _anyoneClaim;
        emit AnyoneClaimUpdated(_setToken, _anyoneClaim);
    }
    function addClaim(
        ISetToken _setToken,
        address _rewardPool,
        string calldata _integrationName
    )
        external
        onlyManagerAndValidSet(_setToken)
    {
        _addClaim(_setToken, _rewardPool, _integrationName);
    }
    function batchAddClaim(
        ISetToken _setToken,
        address[] calldata _rewardPools,
        string[] calldata _integrationNames
    )
        external
        onlyManagerAndValidSet(_setToken)
    {
        _batchAddClaim(_setToken, _rewardPools, _integrationNames);
    }
    function removeClaim(
        ISetToken _setToken,
        address _rewardPool,
        string calldata _integrationName
    )
        external
        onlyManagerAndValidSet(_setToken)
    {
        _removeClaim(_setToken, _rewardPool, _integrationName);
    }
    function batchRemoveClaim(
        ISetToken _setToken,
        address[] calldata _rewardPools,
        string[] calldata _integrationNames
    )
        external
        onlyManagerAndValidSet(_setToken)
    {
        uint256 poolArrayLength = _validateBatchArrays(_rewardPools, _integrationNames);
        for (uint256 i = 0; i < poolArrayLength; i++) {
            _removeClaim(_setToken, _rewardPools[i], _integrationNames[i]);
        }
    }
    function initialize(
        ISetToken _setToken,
        bool _anyoneClaim,
        address[] calldata _rewardPools,
        string[] calldata _integrationNames
    )
        external
        onlySetManager(_setToken, msg.sender)
        onlyValidAndPendingSet(_setToken)
    {
        _batchAddClaim(_setToken, _rewardPools, _integrationNames);
        anyoneClaim[_setToken] = _anyoneClaim;
        _setToken.initializeModule();
    }
    function removeModule() external override {
        delete anyoneClaim[ISetToken(msg.sender)];
        address[] memory setTokenPoolList = rewardPoolList[ISetToken(msg.sender)];
        for (uint256 i = 0; i < setTokenPoolList.length; i++) {
            address[] storage adapterList = claimSettings[ISetToken(msg.sender)][setTokenPoolList[i]];
            for (uint256 j = 0; j < adapterList.length; j++) {
                address toRemove = adapterList[j];
                claimSettingsStatus[ISetToken(msg.sender)][setTokenPoolList[i]][toRemove] = false;
                delete adapterList[j];
            }
            delete claimSettings[ISetToken(msg.sender)][setTokenPoolList[i]];
        }
        for (uint256 i = 0; i < rewardPoolList[ISetToken(msg.sender)].length; i++) {
            address toRemove = rewardPoolList[ISetToken(msg.sender)][i];
            rewardPoolStatus[ISetToken(msg.sender)][toRemove] = false;
            delete rewardPoolList[ISetToken(msg.sender)][i];
        }
        delete rewardPoolList[ISetToken(msg.sender)];
    }
    function getRewardPools(ISetToken _setToken) external view returns (address[] memory) {
        return rewardPoolList[_setToken];
    }
    function isRewardPool(ISetToken _setToken, address _rewardPool) public view returns (bool) {
        return rewardPoolStatus[_setToken][_rewardPool];
    }
    function getRewardPoolClaims(ISetToken _setToken, address _rewardPool) external view returns (address[] memory) {
        return claimSettings[_setToken][_rewardPool];
    }
    function isRewardPoolClaim(
        ISetToken _setToken,
        address _rewardPool,
        string calldata _integrationName
    )
        external
        view
        returns (bool)
    {
        address adapter = getAndValidateAdapter(_integrationName);
        return claimSettingsStatus[_setToken][_rewardPool][adapter];
    }
    function getRewards(
        ISetToken _setToken,
        address _rewardPool,
        string calldata _integrationName
    )
        external
        view
        returns (uint256)
    {
        IClaimAdapter adapter = _getAndValidateIntegrationAdapter(_setToken, _rewardPool, _integrationName);
        return adapter.getRewardsAmount(_setToken, _rewardPool);
    }
    function _claim(ISetToken _setToken, address _rewardPool, string calldata _integrationName) internal {
        require(isRewardPool(_setToken, _rewardPool), "RewardPool not present");
        IClaimAdapter adapter = _getAndValidateIntegrationAdapter(_setToken, _rewardPool, _integrationName);
        IERC20 rewardsToken = IERC20(adapter.getTokenAddress(_rewardPool));
        uint256 initRewardsBalance = rewardsToken.balanceOf(address(_setToken));
        (
            address callTarget,
            uint256 callValue,
            bytes memory callByteData
        ) = adapter.getClaimCallData(
            _setToken,
            _rewardPool
        );
        _setToken.invoke(callTarget, callValue, callByteData);
        uint256 finalRewardsBalance = rewardsToken.balanceOf(address(_setToken));
        emit RewardClaimed(_setToken, _rewardPool, adapter, finalRewardsBalance.sub(initRewardsBalance));
    }
    function _getAndValidateIntegrationAdapter(
        ISetToken _setToken,
        address _rewardsPool,
        string calldata _integrationName
    )
        internal
        view
        returns (IClaimAdapter)
    {
        address adapter = getAndValidateAdapter(_integrationName);
        require(claimSettingsStatus[_setToken][_rewardsPool][adapter], "Adapter integration not present");
        return IClaimAdapter(adapter);
    }
    function _addClaim(ISetToken _setToken, address _rewardPool, string calldata _integrationName) internal {
        address adapter = getAndValidateAdapter(_integrationName);
        address[] storage _rewardPoolClaimSettings = claimSettings[_setToken][_rewardPool];
        require(!claimSettingsStatus[_setToken][_rewardPool][adapter], "Integration names must be unique");
        _rewardPoolClaimSettings.push(adapter);
        claimSettingsStatus[_setToken][_rewardPool][adapter] = true;
        if (!rewardPoolStatus[_setToken][_rewardPool]) {
            rewardPoolList[_setToken].push(_rewardPool);
            rewardPoolStatus[_setToken][_rewardPool] = true;
        }
    }
    function _batchAddClaim(
        ISetToken _setToken,
        address[] calldata _rewardPools,
        string[] calldata _integrationNames
    )
        internal
    {
        uint256 poolArrayLength = _validateBatchArrays(_rewardPools, _integrationNames);
        for (uint256 i = 0; i < poolArrayLength; i++) {
            _addClaim(_setToken, _rewardPools[i], _integrationNames[i]);
        }
    }
    function _removeClaim(ISetToken _setToken, address _rewardPool, string calldata _integrationName) internal {
        address adapter = getAndValidateAdapter(_integrationName);
        require(claimSettingsStatus[_setToken][_rewardPool][adapter], "Integration must be added");
        claimSettings[_setToken][_rewardPool].removeStorage(adapter);
        claimSettingsStatus[_setToken][_rewardPool][adapter] = false;
        if (claimSettings[_setToken][_rewardPool].length == 0) {
            rewardPoolList[_setToken].removeStorage(_rewardPool);
            rewardPoolStatus[_setToken][_rewardPool] = false;
        }
    }
    function _validateBatchArrays(
        address[] memory _rewardPools,
        string[] calldata _integrationNames
    )
        internal
        pure
        returns(uint256)
    {
        uint256 poolArrayLength = _rewardPools.length;
        require(poolArrayLength == _integrationNames.length, "Array length mismatch");
        require(poolArrayLength > 0, "Arrays must not be empty");
        return poolArrayLength;
    }
    function _isValidCaller(ISetToken _setToken) internal view returns(bool) {
        return anyoneClaim[_setToken] || isSetManager(_setToken, msg.sender);
    }
}