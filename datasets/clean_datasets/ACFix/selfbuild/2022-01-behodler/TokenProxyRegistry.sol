pragma solidity 0.8.4;
import "./DAO/Governable.sol";
contract TokenProxyRegistry is Governable {
    struct TokenConfig{
        address baseToken;
        bool migrateBaseToBehodler;
    }
    mapping (address=>TokenConfig) public tokenProxy;
    constructor (address dao) Governable(dao){
    }
    function setProxy (address baseToken, address proxy, bool migrateBase) public onlySuccessfulProposal {
        tokenProxy[proxy] = TokenConfig(baseToken, migrateBase);
    }
}