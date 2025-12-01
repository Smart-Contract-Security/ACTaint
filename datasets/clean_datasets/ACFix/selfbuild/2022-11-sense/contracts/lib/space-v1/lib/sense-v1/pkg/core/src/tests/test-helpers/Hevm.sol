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
    function etch(address, bytes calldata) external virtual;
    function expectRevert(bytes calldata) external virtual;
    function expectRevert(bytes4) external virtual;
    function expectRevert() external virtual;
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
    function record() external virtual;
    function accesses(address) external virtual returns (bytes32[] memory reads, bytes32[] memory writes);
    function mockCall(
        address,
        bytes calldata,
        bytes calldata
    ) external virtual;
    function clearMockedCalls() external virtual;
    function expectCall(address, bytes calldata) external virtual;
    function getCode(string calldata) external virtual returns (bytes memory);
    function label(address, string calldata) external virtual;
    function assume(bool) external virtual;
}