pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import "../src/ERC20Token.sol";
import "../src/interfaces/IERC20Token.sol";
contract ERC20TokenTest is Test {
    ERC20Token token;
    address immutable Governor = vm.addr(0x1);
    address immutable Guardian = vm.addr(0x2);
    address immutable Minter = vm.addr(0x3);
    address immutable userA = vm.addr(0x4);
    address immutable userB = vm.addr(0x5);
    address immutable userC = vm.addr(0x6);
    function setUp() public {
        vm.startPrank(Governor);
        token = new ERC20Token("TOKEN-91", "T-91", Governor, Guardian, Minter);
        vm.stopPrank();
    }
    function testName() public {
        assertEq("TOKEN-91", token.name());
    }
    function testSymbol() public {
        assertEq("T-91", token.symbol());
    }
    function testDecimals() public {
        assertEq(18, token.decimals());
    }
    function invariant_totalSuuply() public {
        uint256 governorBalance = token.balanceOf(Governor);
        uint256 guardianBalance = token.balanceOf(Guardian);
        uint256 minterBalance = token.balanceOf(Minter);
        uint256 userA_Balance = token.balanceOf(userA);
        uint256 userB_Balance = token.balanceOf(userB);
        uint256 expectTotal = governorBalance + guardianBalance + minterBalance + userA_Balance + userB_Balance;
        assertEq(token.totalSupply(), expectTotal);
    }
    function testMint() public {
        vm.prank(Minter);
        token.mint(userA, 2e18);
        assertEq(2e18, token.balanceOf(userA));
    }
    function testBurn() public {
        testMint();
        assertEq(2e18, token.balanceOf(userA));
        assertEq(2e18, token.totalSupply());
        vm.prank(Minter);
        token.burn(userA, 2e18);
        assertEq(0, token.balanceOf(userA));
        assertEq(0, token.totalSupply());
    }
    function testMint_ShouldFail_WhenCallerIsNonMinter() public {
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("NotMinter(address)", userA)
        );
        token.mint(userA, 1e18);
        vm.stopPrank();
    }
    function testMint_ShouldFail_WhenPaused() public {
        vm.prank(Guardian);
        token.pause();
        vm.startPrank(Minter);
        vm.expectRevert("Pausable: paused");
        token.mint(userA, 2e18);
        vm.stopPrank();
    }
    function testMint_ShouldFail_WhenRecipientIsBlacklisted() public {
        vm.prank(Guardian);
        token.addBlackList(userA);
        vm.startPrank(Minter);
        vm.expectRevert(
            abi.encodeWithSignature("Blacklisted(address)", userA)
        );
        token.mint(userA, 2e18);
        vm.stopPrank();
    }
    function testMint_ShouldFail_WhenAmountIsZero() public {
        vm.startPrank(Minter);
        vm.expectRevert("Invalid amount");
        token.mint(userA, 0);
        vm.stopPrank();
    }
    function testBurn_ShouldFail_WhenCallerIsNonMinter() public {
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("NotMinter(address)", userA)
        );
        token.burn(userA, 1e18);
        vm.stopPrank();
    }
    function testBurn_ShouldFail_WhenPaused() public {
        vm.prank(Guardian);
        token.pause();
        vm.startPrank(Minter);
        vm.expectRevert("Pausable: paused");
        token.burn(userA, 1e18);
        vm.stopPrank();
    }
    function testBurn_ShouldFail_WhenAmountIsZero() public {
        vm.startPrank(Minter);
        vm.expectRevert("Invalid amount");
        token.burn(userA, 0);
        vm.stopPrank();
    }
    function testPause() public {
        vm.prank(Guardian);
        token.pause();
        assertTrue(token.paused());
    }
    function testUnpause() public {
        testPause();
        vm.prank(Guardian);
        token.unpause();
        assertFalse(token.paused());
    }
    function testPause_ShouldFail_WhenCallerIsNonGuardian() public {
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("NotGuardian(address)", userA)
        );
        token.pause();
        vm.stopPrank();
    }
    function testUnpause_ShouldFail_WhenCallerIsNonGuardian() public {
        testPause();
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("NotGuardian(address)", userA)
        );
        token.unpause();
        vm.stopPrank();
    }
    function testTransfer() public {
        vm.prank(Minter);
        token.mint(userA, 2e18);
        vm.prank(userA);
        assertTrue(token.transfer(userB, 2e18));
        assertEq(0, token.balanceOf(userA));
        assertEq(2e18, token.balanceOf(userB));
    }
    function testTransferFrom() external {
        vm.prank(Minter);
        token.mint(userA, 2e18);
        vm.prank(userA);
        assertTrue(token.approve(userB, 1e18));
        assertEq(token.allowance(userA, userB), 1e18);
        vm.prank(userB);
        assertTrue(token.transferFrom(userA, userB, 0.7e18));
        assertEq(token.allowance(userA, userB), 0.3e18);
        assertEq(token.balanceOf(userA), 1.3e18);
        assertEq(token.balanceOf(userB), 0.7e18);
    }
    function testTransfer_ShouldFail_WhenPaused() public {
        vm.prank(Minter);
        token.mint(userA, 2e18);
        vm.prank(Guardian);
        token.pause();
        vm.startPrank(userA);
        vm.expectRevert("Pausable: paused");
        token.transfer(userB, 2e18);
        vm.stopPrank();
    }
    function testTransfer_ShouldFail_WhenSenderIsBlacklisted() public {
        vm.prank(Minter);
        token.mint(userA, 2e18);
        vm.prank(Guardian);
        token.addBlackList(userA);
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("Blacklisted(address)", userA)
        );
        token.transfer(userB, 2e18);
        vm.stopPrank();
    }
    function testTransfer_ShouldFail_WhenRecipientIsBlacklisted() public {
        vm.prank(Minter);
        token.mint(userA, 2e18);
        vm.prank(Guardian);
        token.addBlackList(userB);
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("Blacklisted(address)", userB)
        );
        token.transfer(userB, 2e18);
        vm.stopPrank();
    }
    function testTransferFrom_ShouldFail_WhenPaused() public {
        vm.prank(Minter);
        token.mint(userA, 2e18);
        vm.prank(userA);
        assertTrue(token.approve(userB, 1e18));
        assertEq(token.allowance(userA, userB), 1e18);
        vm.prank(Guardian);
        token.pause();
        vm.startPrank(userB);
        vm.expectRevert("Pausable: paused");
        token.transferFrom(userA, userB, 0.7e18);
        vm.stopPrank();
    }
    function testTransferFrom_ShouldFail_WhenCallerIsBlacklisted() public {
        vm.prank(Minter);
        token.mint(userA, 2e18);
        vm.prank(userA);
        assertTrue(token.approve(userB, 1e18));
        assertEq(token.allowance(userA, userB), 1e18);
        vm.prank(Guardian);
        token.addBlackList(userC);
        vm.startPrank(userC);
        vm.expectRevert(
            abi.encodeWithSignature("Blacklisted(address)", userC)
        );
        token.transferFrom(userA, userB, 0.7e18);
        vm.stopPrank();
    }
    function testTransferFrom_ShouldFail_WhenSenderIsBlacklisted() public {
        vm.prank(Minter);
        token.mint(userA, 2e18);
        vm.prank(userA);
        assertTrue(token.approve(userB, 1e18));
        assertEq(token.allowance(userA, userB), 1e18);
        vm.prank(Guardian);
        token.addBlackList(userA);
        vm.startPrank(userC);
        vm.expectRevert(
            abi.encodeWithSignature("Blacklisted(address)", userA)
        );
        token.transferFrom(userA, userB, 0.7e18);
        vm.stopPrank();
    }
    function testTransferFrom_ShouldFail_WhenRecipientIsBlacklisted() public {
        vm.prank(Minter);
        token.mint(userA, 2e18);
        vm.prank(userA);
        assertTrue(token.approve(userB, 1e18));
        assertEq(token.allowance(userA, userB), 1e18);
        vm.prank(Guardian);
        token.addBlackList(userB);
        vm.startPrank(userC);
        vm.expectRevert(
            abi.encodeWithSignature("Blacklisted(address)", userB)
        );
        token.transferFrom(userA, userB, 0.7e18);
        vm.stopPrank();
    }
    function testApprove() public {
        vm.prank(userA);
        assertTrue(token.approve(userB, 1e18));
        assertEq(token.allowance(userA, userB), 1e18);
    }
    function testIncreaseAllowance() public {
        testApprove();
        vm.prank(userA);
        assertTrue(token.increaseAllowance(userB, 1e18));
        assertEq(token.allowance(userA, userB), 2e18);
    }
    function testDecreaseAllowance() public {
        testApprove();
        vm.prank(userA);
        assertTrue(token.decreaseAllowance(userB, 1e18));
        assertEq(token.allowance(userA, userB), 0);
    }
    function testApprove_ShouldFail_WhenPaused() public {
        vm.prank(Guardian);
        token.pause();
        vm.startPrank(userA);
        vm.expectRevert("Pausable: paused");
        token.approve(userB, 1e18);
        vm.stopPrank();
    }
    function testApprove_ShouldFail_WhenCallerIsBlacklisted() public {
        vm.prank(Guardian);
        token.addBlackList(userA);
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("Blacklisted(address)", userA)
        );
        token.approve(userB, 1e18);
        vm.stopPrank();
    }
    function testApprove_ShouldFail_WhenSpenderIsBlacklisted() public {
        vm.prank(Guardian);
        token.addBlackList(userB);
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("Blacklisted(address)", userB)
        );
        token.approve(userB, 1e18);
        vm.stopPrank();
    }
    function testIncreaseAllowance_ShouldFail_WhenPaused() public {
        vm.prank(Guardian);
        token.pause();
        vm.startPrank(userA);
        vm.expectRevert("Pausable: paused");
        token.increaseAllowance(userB, 1e18);
        vm.stopPrank();
    }
    function testIncreaseAllowance_ShouldFail_WhenCallerIsBlacklisted() public {
        vm.prank(Guardian);
        token.addBlackList(userA);
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("Blacklisted(address)", userA)
        );
        token.increaseAllowance(userB, 1e18);
        vm.stopPrank();
    }
    function testIncreaseAllowance_ShouldFail_WhenSpenderIsBlacklisted() public {
        vm.prank(Guardian);
        token.addBlackList(userB);
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("Blacklisted(address)", userB)
        );
        token.increaseAllowance(userB, 1e18);
        vm.stopPrank();
    }
    function testDecreaseAllowance_ShouldFail_WhenPaused() public {
        vm.prank(Guardian);
        token.pause();
        vm.startPrank(userA);
        vm.expectRevert("Pausable: paused");
        token.decreaseAllowance(userB, 1e18);
        vm.stopPrank();
    }
    function testDecreaseAllowance_ShouldFail_WhenCallerIsBlacklisted() public {
        vm.prank(Guardian);
        token.addBlackList(userA);
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("Blacklisted(address)", userA)
        );
        token.decreaseAllowance(userB, 1e18);
        vm.stopPrank();
    }
    function testDecreaseAllowance_ShouldFail_WhenSpenderIsBlacklisted() public {
        vm.prank(Guardian);
        token.addBlackList(userB);
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("Blacklisted(address)", userB)
        );
        token.decreaseAllowance(userB, 1e18);
        vm.stopPrank();
    }
    function testAddBlackList() public {
        vm.prank(Guardian);
        token.addBlackList(userA);
        vm.prank(Guardian);
        assertTrue(token.getBlacklist(userA));
    }
    function testRemoveBlackList() public {
        vm.startPrank(Guardian);
        token.addBlackList(userA);
        assertTrue(token.getBlacklist(userA));
        token.removeBlackList(userA);
        assertFalse(token.getBlacklist(userA));
        vm.stopPrank();
    }
    function testAddBlackList_ShouldFail_WhenCallerIsNonGuardian() public {
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("NotGuardian(address)", userA)
        );
        token.addBlackList(userB);
        vm.stopPrank();
    }
    function testAddBlackList_ShouldFail_WhenPutZeroAddrOnList() public {
        vm.startPrank(Guardian);
        vm.expectRevert("Invalid address");
        token.addBlackList(address(0));
        vm.stopPrank();
    }
    function testRemoveBlackList_ShouldFail_WhenCallerIsNonGuardian() public {
        vm.prank(Guardian);
        token.addBlackList(userA);
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("NotGuardian(address)", userA)
        );
        token.removeBlackList(userA);
        vm.stopPrank();
    }
    function testSetMinter() public {
        vm.prank(Governor);
        token.setMinter(userA, Minter);
        assertTrue(token.hasRole(keccak256("MINTER_ROLE"), userA));
        assertFalse(token.hasRole(keccak256("MINTER_ROLE"), Minter));
    }
    function testSetGuardian() public {
        vm.prank(Guardian);
        token.setGuardian(userA, Guardian);
        assertTrue(token.hasRole(keccak256("GUARDIAN_ROLE"), userA));
        assertFalse(token.hasRole(keccak256("GUARDIAN_ROLE"), Guardian));
    }
    function testSetGovernorRole() public {
        vm.prank(Governor);
        token.setGovernor(userA, Governor);
        assertTrue(token.hasRole(keccak256("GOVERNOR_ROLE"), userA));
        assertFalse(token.hasRole(keccak256("GOVERNOR_ROLE"), Governor));
    }
    function testRevokeMinter() public {
        vm.prank(Governor);
        token.revokeMinter(Minter);
        assertFalse(token.hasRole(keccak256("MINTER_ROLE"), Minter));
    }
    function testRevokeGuardian() public {
        vm.prank(Guardian);
        token.revokeGuardian(Guardian);
        assertFalse(token.hasRole(keccak256("GUARDIAN_ROLE"), Guardian));
    }
    function testRevokeGovernor() public {
        vm.prank(Governor);
        token.revokeGovernor(Governor);
        assertFalse(token.hasRole(keccak256("GOVERNOR_ROLE"), Governor));
    }
    function testSetMinter_ShouldFail_WhenCallerIsNonGovernor() public {
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("NotGovernor(address)", userA)
        );
        token.setMinter(userA, Minter);
        vm.stopPrank();
    }
    function testSetMinter_ShouldFail_WhenSetZeroAddrAsMinter() public {
        vm.startPrank(Governor);
        vm.expectRevert("newMinter cannot be the zero address");
        token.setMinter(address(0), Minter);
        vm.stopPrank();
    }
    function testRevokeMinter_ShouldFail_WhenCallerIsNonGovernor() public {
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("NotGovernor(address)", userA)
        );
        token.revokeMinter(Minter);
        vm.stopPrank();
    }
    function testRevokeMinter_ShouldFail_WhenRevokeZeroAddrAsMinter() public {
        vm.startPrank(Governor);
        vm.expectRevert("oldMinter cannot be the zero address");
        token.revokeMinter(address(0));
        vm.stopPrank();
    }
    function testSetGuardian_ShouldFail_WhenCallerIsNonGuardian() public {
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("NotGuardian(address)", userA)
        );
        token.setGuardian(userA, Guardian);
        vm.stopPrank();
    }
    function testSetGuardian_ShouldFail_WhenSetZeroAddrAsGuardian() public {
        vm.startPrank(Guardian);
        vm.expectRevert("newGuardian cannot be the zero address");
        token.setGuardian(address(0), Guardian);
        vm.stopPrank();
    }
    function testRevokeGuardian_ShouldFail_WhenCallerIsNonGuardian() public {
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("NotGuardian(address)", userA)
        );
        token.revokeGuardian(Guardian);
        vm.stopPrank();
    }
    function testRevokeGuardian_ShouldFail_WhenRevokeZeroAddrAsGuardian() public {
        vm.startPrank(Guardian);
        vm.expectRevert("oldGuardian cannot be the zero address");
        token.revokeGuardian(address(0));
        vm.stopPrank();
    }
    function testSetGovernor_ShouldFail_WhenCallerIsNonGovernor() public {
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("NotGovernor(address)", userA)
        );
        token.setGovernor(userA, Governor);
        vm.stopPrank();
    }
    function testSetGovernor_ShouldFail_WhenSetZeroAddrAsMinter() public {
        vm.startPrank(Governor);
        vm.expectRevert("newGovernor cannot be the zero address");
        token.setGovernor(address(0), Governor);
        vm.stopPrank();
    }
    function testRevokeGovernor_ShouldFail_WhenCallerIsNonGovernor() public {
        vm.startPrank(userA);
        vm.expectRevert(
            abi.encodeWithSignature("NotGovernor(address)", userA)
        );
        token.revokeMinter(Governor);
        vm.stopPrank();
    }
    function testRevokeGovernor_ShouldFail_WhenRevokeZeroAddrAsGovernor() public {
        vm.startPrank(Governor);
        vm.expectRevert("oldGovernor cannot be the zero address");
        token.revokeGovernor(address(0));
        vm.stopPrank();
    }
}
contract ERC20TokenFuzz is Test {
    ERC20Token token;
    address immutable Governor = vm.addr(0x1);
    address immutable Guardian = vm.addr(0x2);
    address immutable Minter = vm.addr(0x3);
    function setUp() public {
        vm.startPrank(Governor);
        token = new ERC20Token("TOKEN-91", "T-91", Governor, Guardian, Minter);
        vm.stopPrank();
    }
    function testMint(address _mintTo, uint256 _amount) public {
        vm.assume(_mintTo != address(0));
        vm.assume(_amount > 0);
        vm.prank(Minter);
        token.mint(_mintTo, _amount);
        assertEq(token.balanceOf(_mintTo), _amount);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.totalSupply(), _amount);
    }
    function testBurn(address _burnFrom, uint256 _amount) public {
        vm.assume(_burnFrom != address(0));
        vm.assume(_amount > 0);
        vm.prank(Minter);
        token.mint(_burnFrom, _amount);
        vm.prank(Minter);
        token.burn(_burnFrom, _amount);
        assertEq(token.balanceOf(_burnFrom), 0);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.totalSupply(), 0);
    }
    function testTransfer(address _sender, address _recipient, uint256 _amount) public {
        vm.assume(_sender != address(0));
        vm.assume(_recipient != address(0));
        vm.assume(_amount > 0);
        vm.assume(_sender != _recipient); 
        vm.prank(Minter);
        token.mint(_sender, _amount);
        vm.prank(_sender);
        assertTrue(token.transfer(_recipient, _amount));
        assertEq(token.balanceOf(_sender), 0);
        assertEq(token.balanceOf(_recipient), _amount);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.totalSupply(), _amount);
    }
    function testTransferFrom(address _sender, address _recipient, uint256 _amount) external {
        vm.assume(_sender != address(0));
        vm.assume(_recipient != address(0));
        vm.assume(_amount > 0);
        vm.assume(_sender != _recipient); 
        vm.assume(_amount != type(uint256).max); 
        vm.prank(Minter);
        token.mint(_sender, _amount);
        vm.prank(_sender);
        token.approve(_recipient, _amount);
        vm.prank(_recipient);
        assertTrue(token.transferFrom(_sender, _recipient, _amount));
        assertEq(token.balanceOf(_sender), 0);
        assertEq(token.balanceOf(_recipient), _amount);
        assertEq(token.allowance(_sender, _recipient), 0);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.totalSupply(), _amount);
    }
    function testApprove(address _owner, address _spender, uint256 _amount) public {
        vm.assume(_owner != address(0));
        vm.assume(_spender != address(0));
        vm.prank(_owner);
        assertTrue(token.approve(_spender, _amount));
        assertEq(token.allowance(_owner, _spender), _amount);
    }
    function testIncreaseAllowance(address _owner, address _spender, uint256 _addedValue) public {
        vm.assume(_owner != address(0));
        vm.assume(_spender != address(0));
        vm.prank(_owner);
        assertTrue(token.approve(_spender, 0));
        vm.prank(_owner);
        assertTrue(token.increaseAllowance(_spender, _addedValue));
        assertEq(token.allowance(_owner, _spender), _addedValue);
    }
    function testDecreaseAllowance(address _owner, address _spender, uint256 _subtractedValue) public {
        vm.assume(_owner != address(0));
        vm.assume(_spender != address(0));
        vm.prank(_owner);
        assertTrue(token.approve(_spender, type(uint256).max));
        vm.prank(_owner);
        assertTrue(token.decreaseAllowance(_spender, _subtractedValue));
        assertEq(token.allowance(_owner, _spender), type(uint256).max - _subtractedValue);
    }
    function testAddBlackList(address _who) public {
        vm.assume(_who != address(0));
        vm.prank(Guardian);
        token.addBlackList(_who);
        vm.prank(Guardian);
        assertTrue(token.getBlacklist(_who));
    }
    function testRemoveBlackList(address _who) public {
        vm.assume(_who != address(0));
        vm.prank(Guardian);
        token.addBlackList(_who);
        vm.prank(Guardian);
        token.removeBlackList(_who);
        vm.prank(Guardian);
        assertFalse(token.getBlacklist(_who));
    }
    function testSetMinter(address _who) public {
        vm.assume(_who != address(0));
        vm.assume(_who != Minter); 
        vm.prank(Governor);
        token.setMinter(_who, Minter);
        assertTrue(token.hasRole(keccak256("MINTER_ROLE"), _who));
        assertFalse(token.hasRole(keccak256("MINTER_ROLE"), Minter));
    }
    function testSetGuardian(address _who) public {
        vm.assume(_who != address(0));
        vm.assume(_who != Guardian); 
        vm.prank(Guardian);
        token.setGuardian(_who, Guardian);
        assertTrue(token.hasRole(keccak256("GUARDIAN_ROLE"), _who));
        assertFalse(token.hasRole(keccak256("GUARDIAN_ROLE"), Guardian));
    }
    function testSetGovernorRole(address _who) public {
        vm.assume(_who != address(0));
        vm.assume(_who != Governor); 
        vm.prank(Governor);
        token.setGovernor(_who, Governor);
        assertTrue(token.hasRole(keccak256("GOVERNOR_ROLE"), _who));
        assertFalse(token.hasRole(keccak256("GOVERNOR_ROLE"), Governor));
    }
    function testRevokeMinter(address _who) public {
        vm.assume(_who != address(0));
        vm.prank(Governor);
        token.setMinter(_who, Governor);
        vm.prank(Governor);
        token.revokeMinter(_who);
        assertFalse(token.hasRole(keccak256("MINTER_ROLE"), _who));
    }
    function testRevokeGuardian(address _who) public {
        vm.assume(_who != address(0));
        vm.prank(Guardian);
        token.setGuardian(_who, Guardian);
        vm.prank(_who);
        token.revokeGuardian(_who);
        assertFalse(token.hasRole(keccak256("GUARDIAN_ROLE"), _who));
    }
    function testRevokeGovernor(address _who) public {
        vm.assume(_who != address(0));
        vm.prank(Governor);
        token.setGovernor(_who, Governor);
        vm.prank(_who);
        token.revokeGovernor(_who);
        assertFalse(token.hasRole(keccak256("GOVERNOR_ROLE"), _who));
    }
}