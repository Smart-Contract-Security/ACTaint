import '../../../../../contracts/libraries/BitMath.sol';
contract VerifyBitMathLsb {
    function verify(uint256 x) external {
        uint256 lsb = BitMath.leastSignificantBit(x);
        bool property = ((x & (2**lsb)) != 0) && ((x & (2**(lsb - 1))) == 0);
        require(!property);
    }
}