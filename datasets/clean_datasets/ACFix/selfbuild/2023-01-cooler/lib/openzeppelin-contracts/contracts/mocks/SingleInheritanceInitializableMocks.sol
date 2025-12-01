pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";
contract MigratableMockV1 is Initializable {
    uint256 public x;
    function initialize(uint256 value) public payable initializer {
        x = value;
    }
}
contract MigratableMockV2 is MigratableMockV1 {
    bool internal _migratedV2;
    uint256 public y;
    function migrate(uint256 value, uint256 anotherValue) public payable {
        require(!_migratedV2);
        x = value;
        y = anotherValue;
        _migratedV2 = true;
    }
}
contract MigratableMockV3 is MigratableMockV2 {
    bool internal _migratedV3;
    function migrate() public payable {
        require(!_migratedV3);
        uint256 oldX = x;
        x = y;
        y = oldX;
        _migratedV3 = true;
    }
}