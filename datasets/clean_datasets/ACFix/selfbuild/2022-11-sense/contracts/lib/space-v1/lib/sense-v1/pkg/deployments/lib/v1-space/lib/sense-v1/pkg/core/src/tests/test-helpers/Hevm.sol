pragma solidity 0.8.11;
abstract contract Hevm {
    function warp(uint256 x) public virtual;
    function roll(uint256 x) public virtual;
    function store(
        address c,
        bytes32 loc,
        bytes32 val
    ) public virtual;
    function ffi(string[] calldata) external virtual returns (bytes memory);
    function load(address, bytes32) external virtual returns (bytes32);
    function expectRevert(bytes calldata) external virtual;
    function expectEmit(
        bool,
        bool,
        bool,
        bool
    ) external virtual;
    function prank(address) external virtual;
    function prank(address, address) external virtual;
    function startPrank(address) external virtual;
    function startPrank(address, address) external virtual;
    function stopPrank() external virtual;
}