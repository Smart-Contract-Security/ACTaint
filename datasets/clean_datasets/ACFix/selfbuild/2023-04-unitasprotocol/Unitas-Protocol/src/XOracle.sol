pragma solidity ^0.8.19;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IOracle.sol";
contract XOracle is AccessControl {
    bytes32 public constant FEEDER_ROLE = keccak256("FEEDER_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    mapping (address => IOracle.Price) public prices;
    event newPrice(address indexed _asset, uint64 _timestamp, uint256 _price);
    constructor() {
        _setRoleAdmin(GUARDIAN_ROLE, GUARDIAN_ROLE);
        _setRoleAdmin(FEEDER_ROLE, GUARDIAN_ROLE);
        _grantRole(GUARDIAN_ROLE, msg.sender);
        _grantRole(FEEDER_ROLE, msg.sender);
    }
    function putPrice(address asset, uint64 timestamp, uint256 price) public onlyRole(FEEDER_ROLE) {
        uint64 prev_timestamp = prices[asset].timestamp;
        uint256 prev_price = prices[asset].price;
        require(prev_timestamp < timestamp, "Outdated timestamp");
        prices[asset] = IOracle.Price(asset, timestamp, prev_timestamp, price, prev_price);
        emit newPrice(asset, timestamp, price);
    }
    function updatePrices(IOracle.NewPrice[] calldata _array) external onlyRole(FEEDER_ROLE) {
        uint256 arrLength = _array.length;
        for(uint256 i=0; i<arrLength; ){
            address asset = _array[i].asset;
            uint64 timestamp = _array[i].timestamp;
            uint256 price = _array[i].price;
            putPrice(asset, timestamp, price);
            unchecked {
                i++;
            }
        }
    }
    function getPrice(address asset) public view returns (uint64, uint64, uint256, uint256) {
        return (
            prices[asset].timestamp,
            prices[asset].prev_timestamp,
            prices[asset].price,
            prices[asset].prev_price
        );
    }
    function getLatestPrice(address asset) public view returns (uint256) {
        return prices[asset].price;
    }
    function decimals() public pure returns (uint8) {
        return 18;
    }
}