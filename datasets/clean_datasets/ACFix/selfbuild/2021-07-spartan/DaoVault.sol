pragma solidity 0.8.3;
import "./interfaces/iBEP20.sol";
import "./interfaces/iDAO.sol";
import "./interfaces/iBASE.sol";
import "./interfaces/iPOOL.sol";
import "./interfaces/iUTILS.sol";
import "./interfaces/iROUTER.sol";
import "./interfaces/iRESERVE.sol";
contract DaoVault {
    address public BASE;
    address public DEPLOYER;
    uint256 public totalWeight; 
    constructor(address _base) {
        BASE = _base;
        DEPLOYER = msg.sender;
    }
    mapping(address => uint256) private mapMember_weight; 
    mapping(address => mapping(address => uint256)) private mapMemberPool_balance; 
    mapping(address => mapping(address => uint256)) public mapMember_depositTime; 
    mapping(address => mapping(address => uint256)) private mapMemberPool_weight; 
    modifier onlyDAO() {
        require(msg.sender == _DAO().DAO() || msg.sender == DEPLOYER, "!DAO");
        _;
    }
    function _DAO() internal view returns (iDAO) {
        return iBASE(BASE).DAO();
    }
    function depositLP(address pool, uint256 amount, address member) external onlyDAO returns (bool) {
        mapMemberPool_balance[member][pool] += amount; 
        increaseWeight(pool, member); 
        return true;
    }
    function increaseWeight(address pool, address member) internal returns (uint256){
        if (mapMemberPool_weight[member][pool] > 0) {
            totalWeight -= mapMemberPool_weight[member][pool]; 
            mapMember_weight[member] -= mapMemberPool_weight[member][pool]; 
            mapMemberPool_weight[member][pool] = 0; 
        }
        uint256 weight = iUTILS(_DAO().UTILS()).getPoolShareWeight(iPOOL(pool).TOKEN(), mapMemberPool_balance[member][pool]); 
        mapMemberPool_weight[member][pool] = weight; 
        mapMember_weight[member] += weight; 
        totalWeight += weight; 
        mapMember_depositTime[member][pool] = block.timestamp; 
        return weight;
    }
    function decreaseWeight(address pool, address member) internal {
        uint256 weight = mapMemberPool_weight[member][pool]; 
        mapMemberPool_balance[member][pool] = 0; 
        mapMemberPool_weight[member][pool] = 0; 
        totalWeight -= weight; 
        mapMember_weight[member] -= weight; 
    }
    function withdraw(address pool, address member) external onlyDAO returns (bool){
        require(block.timestamp > (mapMember_depositTime[member][pool] + 86400), '!unlocked'); 
        uint256 _balance = mapMemberPool_balance[member][pool]; 
        require(_balance > 0, "!balance"); 
        decreaseWeight(pool, member); 
        require(iBEP20(pool).transfer(member, _balance), "!transfer"); 
        return true;
    }
    function getMemberWeight(address member) external view returns (uint256) {
        if (mapMember_weight[member] > 0) {
            return mapMember_weight[member];
        } else {
            return 0;
        }
    }
    function getMemberPoolBalance(address pool, address member)  external view returns (uint256){
        return mapMemberPool_balance[member][pool];
    }
    function getMemberPoolWeight(address pool, address member) external view returns (uint256){
        return mapMemberPool_weight[member][pool];
    }
}