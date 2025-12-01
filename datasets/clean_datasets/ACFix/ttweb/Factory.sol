pragma solidity ^0.8.0;
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./lib/ITemplate.sol";
contract Factory is AccessControlUpgradeable {
    uint256 public constant CODE_VERSION = 1_01_00;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    event TemplateAdded(string name, uint256 version, address implementation);
    event TemplateDeployed(string name, uint256 version, address destination);
    event OperatorChanged(address instance, address operator, bool allowed);
    string[] private _templateNames;
    mapping(string => address) public latestImplementation;
    mapping(address => bool) public whitelisted;
    uint256 public deploymentFee;
    uint256 public callFee;
    uint256 public version;
    mapping(string => uint256) public latestVersion;
    mapping(string => uint256[]) private _templateVersions;
    mapping(string => mapping(uint256 => address))
        private _templateImplementations;
    constructor() initializer {}
    function initialize(address factoryOwner, address factorySigner)
        public
        initializer
    {
        _grantRole(ADMIN_ROLE, factoryOwner);
        _grantRole(SIGNER_ROLE, factorySigner);
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(SIGNER_ROLE, ADMIN_ROLE);
    }
    function upgrade() external {
        require(version < CODE_VERSION, "Already upgraded");
        version = CODE_VERSION;
    }
    function deploy(string calldata name, bytes calldata initdata)
        external
        payable
        paidOnly(deploymentFee)
    {
        _deploy(name, latestVersion[name], initdata);
    }
    function call(address instance, bytes calldata data)
        external
        payable
        operatorOnly(instance)
        paidOnly(callFee)
    {
        _call(instance, data, msg.value - callFee);
    }
    function deploy(
        string calldata templateName,
        bytes calldata initdata,
        bytes calldata signature
    )
        external
        payable
        signedOnly(
            abi.encodePacked(msg.sender, templateName, initdata),
            signature
        )
    {
        _deploy(templateName, latestVersion[templateName], initdata);
    }
    function deploy(
        string calldata templateName,
        uint256 templateVersion,
        bytes calldata initdata,
        bytes calldata signature
    )
        external
        payable
        signedOnly(
            abi.encodePacked(
                msg.sender,
                templateName,
                templateVersion,
                initdata
            ),
            signature
        )
    {
        _deploy(templateName, templateVersion, initdata);
    }
    function call(
        address instance,
        bytes calldata data,
        bytes calldata signature
    )
        external
        payable
        operatorOnly(instance)
        signedOnly(abi.encodePacked(msg.sender, instance, data), signature)
    {
        _call(instance, data, msg.value);
    }
    function setOperator(
        address instance,
        address operator,
        bool allowed
    ) external operatorOnly(instance) {
        require(msg.sender != operator, "Cannot change own role");
        _setOperator(instance, operator, allowed);
    }
    function templates() external view returns (string[] memory templateNames) {
        uint256 count = _templateNames.length;
        templateNames = new string[](count);
        for (uint256 i = 0; i < count; i++) {
            templateNames[i] = _templateNames[i];
        }
    }
    function versions(string memory templateName)
        external
        view
        returns (uint256[] memory templateVersions)
    {
        uint256 count = _templateVersions[templateName].length;
        templateVersions = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            templateVersions[i] = _templateVersions[templateName][i];
        }
    }
    function implementation(string memory templateName, uint256 templateVersion)
        external
        view
        returns (address)
    {
        return _templateImplementations[templateName][templateVersion];
    }
    function isOperator(address instance, address operator)
        public
        view
        returns (bool)
    {
        return hasRole(OPERATOR_ROLE(instance), operator);
    }
    function setDeploymentFee(uint256 newFee) external onlyRole(ADMIN_ROLE) {
        deploymentFee = newFee;
    }
    function setCallFee(uint256 newFee) external onlyRole(ADMIN_ROLE) {
        callFee = newFee;
    }
    function OPERATOR_ROLE(address instance) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(instance, "OPERATOR"));
    }
    function registerTemplate(address implementationAddress)
        public
        onlyRole(ADMIN_ROLE)
    {
        require(
            Address.isContract(implementationAddress),
            "Not a valid contract"
        );
        ITemplate templateImplementation = ITemplate(implementationAddress);
        string memory templateName = templateImplementation.NAME();
        uint256 templateVersion = templateImplementation.VERSION();
        _setTemplate(templateName, templateVersion, implementationAddress);
    }
    function setWhitelisted(address instance, bool newStatus)
        external
        onlyRole(ADMIN_ROLE)
    {
        _setWhitelisted(instance, newStatus);
    }
    function withdrawFees(address to) external onlyRole(ADMIN_ROLE) {
        Address.sendValue(payable(to), address(this).balance);
    }
    function _setTemplate(
        string memory templateName,
        uint256 templateVersion,
        address implementationAddress
    ) internal {
        require(
            _templateImplementations[templateName][templateVersion] ==
                address(0),
            "Version already exists"
        );
        _templateImplementations[templateName][
            templateVersion
        ] = implementationAddress;
        _templateVersions[templateName].push(templateVersion);
        if (latestImplementation[templateName] == address(0)) {
            _templateNames.push(templateName);
        }
        if (templateVersion > latestVersion[templateName]) {
            latestVersion[templateName] = templateVersion;
            latestImplementation[templateName] = implementationAddress;
        }
        emit TemplateAdded(
            templateName,
            templateVersion,
            implementationAddress
        );
    }
    function _setWhitelisted(address instance, bool newStatus) internal {
        whitelisted[instance] = newStatus;
    }
    function _setOperator(
        address instance,
        address operator,
        bool allowed
    ) internal {
        if (allowed) {
            _grantRole(OPERATOR_ROLE(instance), operator);
        } else {
            _revokeRole(OPERATOR_ROLE(instance), operator);
        }
        emit OperatorChanged(instance, operator, allowed);
    }
    function _deploy(
        string calldata templateName,
        uint256 templateVersion,
        bytes calldata initdata
    ) internal {
        address implementationAddress = _templateImplementations[templateName][
            templateVersion
        ];
        require(implementationAddress != address(0), "Missing implementation");
        address clone = Clones.clone(implementationAddress);
        emit TemplateDeployed(templateName, templateVersion, clone);
        _setOperator(clone, msg.sender, true);
        _setWhitelisted(clone, true);
        _call(clone, initdata, 0);
    }
    function _call(
        address instance,
        bytes calldata data,
        uint256 value
    ) internal {
        require(whitelisted[instance], "Contract not whitelisted");
        assembly {
            let _calldata := mload(0x40)
            calldatacopy(_calldata, data.offset, data.length)
            let result := call(
                gas(),
                instance,
                value,
                _calldata,
                data.length,
                0,
                0
            )
            let returndata := mload(0x40)
            let size := returndatasize()
            returndatacopy(returndata, 0, size)
            switch result
            case 0 {
                revert(returndata, size)
            }
            default {
                return(returndata, size)
            }
        }
    }
    modifier operatorOnly(address instance) {
        require(isOperator(instance, msg.sender), "Access denied");
        _;
    }
    modifier signedOnly(bytes memory message, bytes calldata signature) {
        address messageSigner = ECDSA.recover(
            ECDSA.toEthSignedMessageHash(message),
            signature
        );
        require(hasRole(SIGNER_ROLE, messageSigner), "Signer not recognized");
        _;
    }
    modifier paidOnly(uint256 fee) {
        require(msg.value >= fee, "Insufficient payment");
        _;
    }
}