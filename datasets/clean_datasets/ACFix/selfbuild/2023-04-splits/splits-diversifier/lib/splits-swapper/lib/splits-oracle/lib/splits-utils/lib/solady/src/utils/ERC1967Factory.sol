pragma solidity ^0.8.4;
contract ERC1967Factory {
    error Unauthorized();
    error DeploymentFailed();
    error UpgradeFailed();
    error SaltDoesNotStartWithCaller();
    uint256 internal constant _UNAUTHORIZED_ERROR_SELECTOR = 0x82b42900;
    uint256 internal constant _DEPLOYMENT_FAILED_ERROR_SELECTOR = 0x30116425;
    uint256 internal constant _UPGRADE_FAILED_ERROR_SELECTOR = 0x55299b49;
    uint256 internal constant _SALT_DOES_NOT_START_WITH_CALLER_ERROR_SELECTOR = 0x2f634836;
    event AdminChanged(address indexed proxy, address indexed admin);
    event Upgraded(address indexed proxy, address indexed implementation);
    event Deployed(address indexed proxy, address indexed implementation, address indexed admin);
    uint256 internal constant _ADMIN_CHANGED_EVENT_SIGNATURE =
        0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f;
    uint256 internal constant _UPGRADED_EVENT_SIGNATURE =
        0x5d611f318680d00598bb735d61bacf0c514c6b50e1e5ad30040a4df2b12791c7;
    uint256 internal constant _DEPLOYED_EVENT_SIGNATURE =
        0xc95935a66d15e0da5e412aca0ad27ae891d20b2fb91cf3994b6a3bf2b8178082;
    uint256 internal constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    function adminOf(address proxy) public view returns (address admin) {
        assembly {
            mstore(0x0c, address())
            mstore(0x00, proxy)
            admin := sload(keccak256(0x0c, 0x20))
        }
    }
    function changeAdmin(address proxy, address admin) public {
        assembly {
            mstore(0x0c, address())
            mstore(0x00, proxy)
            let adminSlot := keccak256(0x0c, 0x20)
            if iszero(eq(sload(adminSlot), caller())) {
                mstore(0x00, _UNAUTHORIZED_ERROR_SELECTOR)
                revert(0x1c, 0x04)
            }
            sstore(adminSlot, admin)
            log3(0, 0, _ADMIN_CHANGED_EVENT_SIGNATURE, proxy, admin)
        }
    }
    function upgrade(address proxy, address implementation) public payable {
        upgradeAndCall(proxy, implementation, _emptyData());
    }
    function upgradeAndCall(address proxy, address implementation, bytes calldata data)
        public
        payable
    {
        assembly {
            mstore(0x0c, address())
            mstore(0x00, proxy)
            if iszero(eq(sload(keccak256(0x0c, 0x20)), caller())) {
                mstore(0x00, _UNAUTHORIZED_ERROR_SELECTOR)
                revert(0x1c, 0x04)
            }
            let m := mload(0x40)
            mstore(m, implementation)
            mstore(add(m, 0x20), _IMPLEMENTATION_SLOT)
            calldatacopy(add(m, 0x40), data.offset, data.length)
            if iszero(call(gas(), proxy, callvalue(), m, add(0x40, data.length), 0x00, 0x00)) {
                if iszero(returndatasize()) {
                    mstore(0x00, _UPGRADE_FAILED_ERROR_SELECTOR)
                    revert(0x1c, 0x04)
                }
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
            log3(0, 0, _UPGRADED_EVENT_SIGNATURE, proxy, implementation)
        }
    }
    function deploy(address implementation, address admin) public payable returns (address proxy) {
        proxy = deployAndCall(implementation, admin, _emptyData());
    }
    function deployAndCall(address implementation, address admin, bytes calldata data)
        public
        payable
        returns (address proxy)
    {
        proxy = _deploy(implementation, admin, bytes32(0), false, data);
    }
    function deployDeterministic(address implementation, address admin, bytes32 salt)
        public
        payable
        returns (address proxy)
    {
        proxy = deployDeterministicAndCall(implementation, admin, salt, _emptyData());
    }
    function deployDeterministicAndCall(
        address implementation,
        address admin,
        bytes32 salt,
        bytes calldata data
    ) public payable returns (address proxy) {
        assembly {
            if iszero(or(iszero(shr(96, salt)), eq(caller(), shr(96, salt)))) {
                mstore(0x00, _SALT_DOES_NOT_START_WITH_CALLER_ERROR_SELECTOR)
                revert(0x1c, 0x04)
            }
        }
        proxy = _deploy(implementation, admin, salt, true, data);
    }
    function _deploy(
        address implementation,
        address admin,
        bytes32 salt,
        bool useSalt,
        bytes calldata data
    ) internal returns (address proxy) {
        bytes memory m = _initCode();
        assembly {
            switch useSalt
            case 0 { proxy := create(0, add(m, 0x13), 0x89) }
            default { proxy := create2(0, add(m, 0x13), 0x89, salt) }
            if iszero(proxy) {
                mstore(0x00, _DEPLOYMENT_FAILED_ERROR_SELECTOR)
                revert(0x1c, 0x04)
            }
            mstore(m, implementation)
            mstore(add(m, 0x20), _IMPLEMENTATION_SLOT)
            calldatacopy(add(m, 0x40), data.offset, data.length)
            if iszero(call(gas(), proxy, callvalue(), m, add(0x40, data.length), 0x00, 0x00)) {
                if iszero(returndatasize()) {
                    mstore(0x00, _DEPLOYMENT_FAILED_ERROR_SELECTOR)
                    revert(0x1c, 0x04)
                }
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
            mstore(0x0c, address())
            mstore(0x00, proxy)
            sstore(keccak256(0x0c, 0x20), admin)
            log4(0, 0, _DEPLOYED_EVENT_SIGNATURE, proxy, implementation, admin)
        }
    }
    function predictDeterministicAddress(bytes32 salt) public view returns (address predicted) {
        bytes32 hash = initCodeHash();
        assembly {
            mstore8(0x00, 0xff) 
            mstore(0x35, hash)
            mstore(0x01, shl(96, address()))
            mstore(0x15, salt)
            predicted := keccak256(0x00, 0x55)
            mstore(0x35, 0)
        }
    }
    function initCodeHash() public view returns (bytes32 result) {
        bytes memory m = _initCode();
        assembly {
            result := keccak256(add(m, 0x13), 0x89)
        }
    }
    function _initCode() internal view returns (bytes memory m) {
        assembly {
            m := mload(0x40)
            switch shr(112, address())
            case 0 {
                mstore(add(m, 0x75), 0x604c573d6000fd) 
                mstore(add(m, 0x6e), 0x3d3560203555604080361115604c5736038060403d373d3d355af43d6000803e) 
                mstore(add(m, 0x4e), 0x3735a920a3ca505d382bbc545af43d6000803e604c573d6000fd5b3d6000f35b) 
                mstore(add(m, 0x2e), 0x14605157363d3d37363d7f360894a13ba1a3210667c828492db98dca3e2076cc) 
                mstore(add(m, 0x0e), address()) 
                mstore(m, 0x60793d8160093d39f33d3d336d) 
            }
            default {
                mstore(add(m, 0x7b), 0x6052573d6000fd) 
                mstore(add(m, 0x74), 0x3d356020355560408036111560525736038060403d373d3d355af43d6000803e) 
                mstore(add(m, 0x54), 0x3735a920a3ca505d382bbc545af43d6000803e6052573d6000fd5b3d6000f35b) 
                mstore(add(m, 0x34), 0x14605757363d3d37363d7f360894a13ba1a3210667c828492db98dca3e2076cc) 
                mstore(add(m, 0x14), address()) 
                mstore(m, 0x607f3d8160093d39f33d3d3373) 
            }
        }
    }
    function _emptyData() internal pure returns (bytes calldata data) {
        assembly {
            data.length := 0
        }
    }
}