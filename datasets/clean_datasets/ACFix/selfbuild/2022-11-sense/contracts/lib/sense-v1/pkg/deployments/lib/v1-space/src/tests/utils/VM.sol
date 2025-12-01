pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
abstract contract VM {
    function load(address,bytes32) external virtual returns (bytes32);
    function store(address,bytes32,bytes32) external virtual;
    function warp(uint256 x) public virtual;
    function roll(uint256 x) public virtual;
    function ffi(string[] calldata) public virtual returns (bytes memory);
    function prank(address,address) virtual external;
    function startPrank(address,address) virtual external;
    function stopPrank() virtual external;
    function label(address, string calldata) virtual external;
    function assume(bool) virtual external;
    function expectRevert(bytes calldata) external virtual;
}