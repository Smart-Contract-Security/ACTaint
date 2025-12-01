// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./lib/ITemplate.sol";

/**
 * @title Factory
 * @notice Contract for managing contract templates, their implementations and deploying and calling template instances.
 * Uses {Clones} to deploy https://eips.ethereum.org/EIPS/eip-1167[EIP 1167] compliant proxy contracts
 *
 * Upgradable contract, meaning it does not make use of a constructor but rather uses `initialize` with `initializer`
 * modifier, see {Initializable}
 *
 * Allows for registering new templates and delegating calls to deployed proxies.
 * Saves versions and names for each clone that can be deployed using this factory.
 *
 * Proxies can be deployed with a signature from an address with `SIGNER_ROLE` or by paying `deploymentFee`
 * Proxies can be called with a signature from an address with `SIGNER_ROLE` or by paying `callFee`
 */
contract Factory is AccessControlUpgradeable {
    /*************
     * Constants *
     *************/

    /// Contract code version
    /// @dev Should follow semver-like format of `MAJOR_MINOR_PATCH`
    uint256 public constant CODE_VERSION = 1_01_00;

    /// Contract administrator role
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    /// Transaction signer role
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    /**********
     * Events *
     **********/

    /// A new version of a template implementation has been added to the Factory
    event TemplateAdded(string name, uint256 version, address implementation);

    /// An instance of a template has been deployed
    event TemplateDeployed(string name, uint256 version, address destination);

    /// Permissions for address `operator` to operate contract `instance` have changed to `allowed`
    event OperatorChanged(address instance, address operator, bool allowed);

    /***********
     * Storage *
     ***********/

    /// Template names
    string[] private _templateNames;

    /// Latest template implementations for `_templateNames`
    mapping(string => address) public latestImplementation;

    /// Contracts that are whitelisted for proxy calls
    mapping(address => bool) public whitelisted;

    /// Deployment fee, used for deploying clones without a signature
    uint256 public deploymentFee;

    /// Call fee, used for calling clones without a signature
    uint256 public callFee;

    /// Current contract version
    uint256 public version;

    /// Latest template versions for `_templateNames`
    mapping(string => uint256) public latestVersion;

    /// All template versions for `_templateNames`
    mapping(string => uint256[]) private _templateVersions;

    /// Implementation addresses for all template versions
    mapping(string => mapping(uint256 => address))
        private _templateImplementations;

    /****************************
     * Contract init & upgrades *
     ****************************/

    /**
     * @dev Empty constructor to disable direct initialization of this contract
     */
    constructor() initializer {}

    /**
     * Initialize the Factory
     * @dev Callable only once
     * @param factoryOwner The address that should be assigned ADMIN_ROLE
     * @param factorySigner The address that should be assigned SIGNER_ROLE
     */
    function initialize(address factoryOwner, address factorySigner)
        public
        initializer
    {
        _grantRole(ADMIN_ROLE, factoryOwner);
        _grantRole(SIGNER_ROLE, factorySigner);

        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(SIGNER_ROLE, ADMIN_ROLE);
    }

    /**
     * Perform any necessary state migrations between Factory versions
     * @dev Callable by anyone but in practice will get called atomically when the Factory implementation is updated.
     */
    function upgrade() external {
        require(version < CODE_VERSION, "Already upgraded");

        /* Start migration code */
        /* End migration code */

        version = CODE_VERSION;
    }

    /***********
     * Actions *
     ***********/

    /**
     * Deploy an instance of the latest version of the specified template
     * @dev Requires `deploymentFee` to be paid by the caller. Deprecated and will be removed.
     * @param name The name of the template to be deployed
     * @param initdata Payload for initializing the instance
     */
    function deploy(string calldata name, bytes calldata initdata)
        external
        payable
        paidOnly(deploymentFee)
    {
        _deploy(name, latestVersion[name], initdata);
    }

    /**
     * Call a deployed template instance
     * @dev Requires `callFee` to be paid by the caller. Deprecated and will be removed.
     * @param instance Address of the contract we want to call
     * @param data Call data to be forwarded to the target contract
     */
    function call(address instance, bytes calldata data)
        external
        payable
        operatorOnly(instance)
        paidOnly(callFee)
    {
        _call(instance, data, msg.value - callFee);
    }

    /**
     * Deploy the latest version of the specified template
     * @dev Requires a signature of the deployment payload (caller, template name and initialization data) by a `SIGNER_ROLE` wallet. Deprecated and will be removed once the API has migrated to the version-specific deploy() method below.
     * @param templateName Name of the template to be deployed
     * @param initdata Payload for initializing the instance
     * @param signature Signature for authorizing the deployment
     */
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

    /**
     * Deploy a specific version of the specified template
     * @dev Requires a signature of the deployment payload (caller, template name and initialization data) by a `SIGNER_ROLE` wallet
     * @param templateName Name of the template to be deployed
     * @param templateVersion Version to be deployed
     * @param initdata Payload for initializing the instance
     * @param signature Signature for authorizing the deployment
     */
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

    /**
     * Call a deployed template instance
     * @dev Requires a signature of the call payload (caller, instance address and call data) by a `SIGNER_ROLE` wallet
     * @param instance Address of the contract we want to call
     * @param data Call data to be forwarded to the target contract
     * @param signature Signature for authorizing the contract call
     */
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

    /**
     * Update the operator status of `instance` for `operator`
     * @param instance The template instance that will be operated on
     * @param operator The address of the operator that we want to update the status of
     * @param allowed New operator status
     */
    function setOperator(
        address instance,
        address operator,
        bool allowed
    ) external operatorOnly(instance) {
        require(msg.sender != operator, "Cannot change own role");

        _setOperator(instance, operator, allowed);
    }

    /******************
     * View functions *
     ******************/

    /**
     * Get a list of all templates registered with the factory
     * @return templateNames List of all template names that have been registered
     */
    function templates() external view returns (string[] memory templateNames) {
        uint256 count = _templateNames.length;
        templateNames = new string[](count);

        for (uint256 i = 0; i < count; i++) {
            templateNames[i] = _templateNames[i];
        }
    }

    /**
     * Get a list of all registered versions of a template
     * @param templateName Name of the template
     * @return templateVersions List of all version numbers that have been registered for that template
     */
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

    /**
     * Get the implementation address of a specific version of a template
     * @param templateName Name of the template
     * @param templateVersion Version of the implementation
     * @return Address of the implementation contract
     */
    function implementation(string memory templateName, uint256 templateVersion)
        external
        view
        returns (address)
    {
        return _templateImplementations[templateName][templateVersion];
    }

    /**
     * Check if the `operator` address is allowed to operate on template instance `instance`
     * @param instance Address of the template instance
     * @param operator Address of the operator
     */
    function isOperator(address instance, address operator)
        public
        view
        returns (bool)
    {
        return hasRole(OPERATOR_ROLE(instance), operator);
    }

    /**
     * Update template instance deployment fee
     * @dev Deprecated
     * @param newFee New deployment fee
     */
    function setDeploymentFee(uint256 newFee) external onlyRole(ADMIN_ROLE) {
        deploymentFee = newFee;
    }

    /**
     * Update template instance call fee
     * @dev deprecated
     * @param newFee New call fee
     */
    function setCallFee(uint256 newFee) external onlyRole(ADMIN_ROLE) {
        callFee = newFee;
    }

    /**
     * Get the operator role for the specified instance
     * @param instance Address of the template instance that the role will be operating on
     * @return Operator role identifier
     */
    function OPERATOR_ROLE(address instance) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(instance, "OPERATOR"));
    }

    /*******************
     * Admin functions *
     *******************/

    /**
     * Register a new implementation with the Factory
     * @dev Implementation details will be read and validated on-chain
     * @param implementationAddress Address of the template implementation contract
     */
    function registerTemplate(address implementationAddress)
        public
        onlyRole(ADMIN_ROLE)
    {
        require(
            Address.isContract(implementationAddress),
            "Not a valid contract"
        );

        // Read template information from the implementation contract
        ITemplate templateImplementation = ITemplate(implementationAddress);
        string memory templateName = templateImplementation.NAME();
        uint256 templateVersion = templateImplementation.VERSION();

        // Store the template information
        _setTemplate(templateName, templateVersion, implementationAddress);
    }

    /**
     * Update contract whitelist status
     * @dev For security reasons, we don't allow arbitrary contracts to be called via Factory. Contracts deployed via the Factory will be automatically whitelisted. This function is intended to allow us to disable any contracts that turn out to be vulnerable or malicious.
     * @param instance Contract address
     * @param newStatus New whitelist status
     */
    function setWhitelisted(address instance, bool newStatus)
        external
        onlyRole(ADMIN_ROLE)
    {
        _setWhitelisted(instance, newStatus);
    }

    /**
     * Withdraw all fees from the contract to an address
     * @dev Deprecated, originally intended for withdrawing deplyment and call fees.
     */
    function withdrawFees(address to) external onlyRole(ADMIN_ROLE) {
        Address.sendValue(payable(to), address(this).balance);
    }

    /*************
     * Internals *
     *************/

    /**
     * @dev Internal function without access rights checks for storing template implemetation details
     * @param templateName Name of the template
     * @param templateVersion Template version
     * @param implementationAddress Address of the implementation contract
     */
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

        // Store the template implementation address
        _templateImplementations[templateName][
            templateVersion
        ] = implementationAddress;

        // Update the list of available versions for a template
        _templateVersions[templateName].push(templateVersion);

        // Check if we're adding a new template and update template list if needed
        if (latestImplementation[templateName] == address(0)) {
            _templateNames.push(templateName);
        }

        // Update the current implementation version & address if needed
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

    /**
     * @dev Internal function for updating whitelist status
     * @param instance Contract address
     * @param newStatus New whitelist status
     */
    function _setWhitelisted(address instance, bool newStatus) internal {
        whitelisted[instance] = newStatus;
    }

    /**
     * @dev Internal function for granting or revoking contract operator role from an address
     * @param instance Contract address
     * @param operator Operator address
     * @param allowed New operator status
     */
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

    /**
     * @dev Internal function for deploying a template instance
     * @param templateName Name of the template to be deployed
     * @param templateVersion Version of the template implementation
     * @param initdata Initialization data for the newly deployed instance
     */
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

    /**
     * @dev Internal function for calling a template instance
     * @param instance Address of the template instance
     * @param data Call data to be forwarded to the instance
     * @param value Fees to be forwarded with the call
     */
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

    /*************
     * Modifiers *
     *************/

    /**
     * @dev Modifier for restricting the caller to be an operator of contract at address `instance`
     */
    modifier operatorOnly(address instance) {
        require(isOperator(instance, msg.sender), "Access denied");
        _;
    }

    /**
     * @dev Modifier for checking if `signature` is a valid signature of `message` by a `SIGNER_ROLE` wallet
     */
    modifier signedOnly(bytes memory message, bytes calldata signature) {
        // Gets the address that signed the message with signature
        address messageSigner = ECDSA.recover(
            ECDSA.toEthSignedMessageHash(message),
            signature
        );

        require(hasRole(SIGNER_ROLE, messageSigner), "Signer not recognized");

        _;
    }

    /**
     * @dev Modifier for enforcing a minimum payment for the function call
     */
    modifier paidOnly(uint256 fee) {
        require(msg.value >= fee, "Insufficient payment");
        _;
    }
}