pragma solidity >=0.8.0 <0.9.0;
import "forge-std/Test.sol";
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address to, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address from, address to, uint amount) external returns (bool);
}
interface IERC4626 is IERC20 {
    event Deposit(address indexed caller, address indexed owner, uint assets, uint shares);
    event Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint assets, uint shares);
    function asset() external view returns (address assetTokenAddress);
    function totalAssets() external view returns (uint totalManagedAssets);
    function convertToShares(uint assets) external view returns (uint shares);
    function convertToAssets(uint shares) external view returns (uint assets);
    function maxDeposit(address receiver) external view returns (uint maxAssets);
    function previewDeposit(uint assets) external view returns (uint shares);
    function deposit(uint assets, address receiver) external returns (uint shares);
    function maxMint(address receiver) external view returns (uint maxShares);
    function previewMint(uint shares) external view returns (uint assets);
    function mint(uint shares, address receiver) external returns (uint assets);
    function maxWithdraw(address owner) external view returns (uint maxAssets);
    function previewWithdraw(uint assets) external view returns (uint shares);
    function withdraw(uint assets, address receiver, address owner) external returns (uint shares);
    function maxRedeem(address owner) external view returns (uint maxShares);
    function previewRedeem(uint shares) external view returns (uint assets);
    function redeem(uint shares, address receiver, address owner) external returns (uint assets);
}
abstract contract ERC4626Prop is Test {
    uint internal _delta_;
    address internal _underlying_;
    address internal _vault_;
    bool internal _vaultMayBeEmpty;
    bool internal _unlimitedAmount;
    function prop_asset(address caller) public {
        vm.prank(caller); IERC4626(_vault_).asset();
    }
    function prop_totalAssets(address caller) public {
        vm.prank(caller); IERC4626(_vault_).totalAssets();
    }
    function prop_convertToShares(address caller1, address caller2, uint assets) public {
        vm.prank(caller1); uint res1 = vault_convertToShares(assets); 
        vm.prank(caller2); uint res2 = vault_convertToShares(assets); 
        assertEq(res1, res2);
    }
    function prop_convertToAssets(address caller1, address caller2, uint shares) public {
        vm.prank(caller1); uint res1 = vault_convertToAssets(shares); 
        vm.prank(caller2); uint res2 = vault_convertToAssets(shares); 
        assertEq(res1, res2);
    }
    function prop_maxDeposit(address caller, address receiver) public {
        vm.prank(caller); IERC4626(_vault_).maxDeposit(receiver);
    }
    function prop_previewDeposit(address caller, address receiver, address other, uint assets) public {
        vm.prank(other); uint sharesPreview = vault_previewDeposit(assets); 
        vm.prank(caller); uint sharesActual = vault_deposit(assets, receiver);
        assertApproxGeAbs(sharesActual, sharesPreview, _delta_);
    }
    function prop_deposit(address caller, address receiver, uint assets) public {
        uint oldCallerAsset = IERC20(_underlying_).balanceOf(caller);
        uint oldReceiverShare = IERC20(_vault_).balanceOf(receiver);
        uint oldAllowance = IERC20(_underlying_).allowance(caller, _vault_);
        vm.prank(caller); uint shares = vault_deposit(assets, receiver);
        uint newCallerAsset = IERC20(_underlying_).balanceOf(caller);
        uint newReceiverShare = IERC20(_vault_).balanceOf(receiver);
        uint newAllowance = IERC20(_underlying_).allowance(caller, _vault_);
        assertApproxEqAbs(newCallerAsset, oldCallerAsset - assets, _delta_, "asset"); 
        assertApproxEqAbs(newReceiverShare, oldReceiverShare + shares, _delta_, "share");
        if (oldAllowance != type(uint).max) assertApproxEqAbs(newAllowance, oldAllowance - assets, _delta_, "allowance");
    }
    function prop_maxMint(address caller, address receiver) public {
        vm.prank(caller); IERC4626(_vault_).maxMint(receiver);
    }
    function prop_previewMint(address caller, address receiver, address other, uint shares) public {
        vm.prank(other); uint assetsPreview = vault_previewMint(shares);
        vm.prank(caller); uint assetsActual = vault_mint(shares, receiver);
        assertApproxLeAbs(assetsActual, assetsPreview, _delta_);
    }
    function prop_mint(address caller, address receiver, uint shares) public {
        uint oldCallerAsset = IERC20(_underlying_).balanceOf(caller);
        uint oldReceiverShare = IERC20(_vault_).balanceOf(receiver);
        uint oldAllowance = IERC20(_underlying_).allowance(caller, _vault_);
        vm.prank(caller); uint assets = vault_mint(shares, receiver);
        uint newCallerAsset = IERC20(_underlying_).balanceOf(caller);
        uint newReceiverShare = IERC20(_vault_).balanceOf(receiver);
        uint newAllowance = IERC20(_underlying_).allowance(caller, _vault_);
        assertApproxEqAbs(newCallerAsset, oldCallerAsset - assets, _delta_, "asset"); 
        assertApproxEqAbs(newReceiverShare, oldReceiverShare + shares, _delta_, "share");
        if (oldAllowance != type(uint).max) assertApproxEqAbs(newAllowance, oldAllowance - assets, _delta_, "allowance");
    }
    function prop_maxWithdraw(address caller, address owner) public {
        vm.prank(caller); IERC4626(_vault_).maxWithdraw(owner);
    }
    function prop_previewWithdraw(address caller, address receiver, address owner, address other, uint assets) public {
        vm.prank(other); uint preview = vault_previewWithdraw(assets);
        vm.prank(caller); uint actual = vault_withdraw(assets, receiver, owner);
        assertApproxLeAbs(actual, preview, _delta_);
    }
    function prop_withdraw(address caller, address receiver, address owner, uint assets) public {
        uint oldReceiverAsset = IERC20(_underlying_).balanceOf(receiver);
        uint oldOwnerShare = IERC20(_vault_).balanceOf(owner);
        uint oldAllowance = IERC20(_vault_).allowance(owner, caller);
        vm.prank(caller); uint shares = vault_withdraw(assets, receiver, owner);
        uint newReceiverAsset = IERC20(_underlying_).balanceOf(receiver);
        uint newOwnerShare = IERC20(_vault_).balanceOf(owner);
        uint newAllowance = IERC20(_vault_).allowance(owner, caller);
        assertApproxEqAbs(newOwnerShare, oldOwnerShare - shares, _delta_, "share");
        assertApproxEqAbs(newReceiverAsset, oldReceiverAsset + assets, _delta_, "asset"); 
        if (caller != owner && oldAllowance != type(uint).max) assertApproxEqAbs(newAllowance, oldAllowance - shares, _delta_, "allowance");
        assertTrue(caller == owner || oldAllowance != 0 || (shares == 0 && assets == 0), "access control");
    }
    function prop_maxRedeem(address caller, address owner) public {
        vm.prank(caller); IERC4626(_vault_).maxRedeem(owner);
    }
    function prop_previewRedeem(address caller, address receiver, address owner, address other, uint shares) public {
        vm.prank(other); uint preview = vault_previewRedeem(shares);
        vm.prank(caller); uint actual = vault_redeem(shares, receiver, owner);
        assertApproxGeAbs(actual, preview, _delta_);
    }
    function prop_redeem(address caller, address receiver, address owner, uint shares) public {
        uint oldReceiverAsset = IERC20(_underlying_).balanceOf(receiver);
        uint oldOwnerShare = IERC20(_vault_).balanceOf(owner);
        uint oldAllowance = IERC20(_vault_).allowance(owner, caller);
        vm.prank(caller); uint assets = vault_redeem(shares, receiver, owner);
        uint newReceiverAsset = IERC20(_underlying_).balanceOf(receiver);
        uint newOwnerShare = IERC20(_vault_).balanceOf(owner);
        uint newAllowance = IERC20(_vault_).allowance(owner, caller);
        assertApproxEqAbs(newOwnerShare, oldOwnerShare - shares, _delta_, "share");
        assertApproxEqAbs(newReceiverAsset, oldReceiverAsset + assets, _delta_, "asset"); 
        if (caller != owner && oldAllowance != type(uint).max) assertApproxEqAbs(newAllowance, oldAllowance - shares, _delta_, "allowance");
        assertTrue(caller == owner || oldAllowance != 0 || (shares == 0 && assets == 0), "access control");
    }
    function prop_RT_deposit_redeem(address caller, uint assets) public {
        if (!_vaultMayBeEmpty) vm.assume(IERC20(_vault_).totalSupply() > 0);
        vm.prank(caller); uint shares = vault_deposit(assets, caller);
        vm.prank(caller); uint assets2 = vault_redeem(shares, caller, caller);
        assertApproxLeAbs(assets2, assets, _delta_);
    }
    function prop_RT_deposit_withdraw(address caller, uint assets) public {
        if (!_vaultMayBeEmpty) vm.assume(IERC20(_vault_).totalSupply() > 0);
        vm.prank(caller); uint shares1 = vault_deposit(assets, caller);
        vm.prank(caller); uint shares2 = vault_withdraw(assets, caller, caller);
        assertApproxGeAbs(shares2, shares1, _delta_);
    }
    function prop_RT_redeem_deposit(address caller, uint shares) public {
        vm.prank(caller); uint assets = vault_redeem(shares, caller, caller);
        if (!_vaultMayBeEmpty) vm.assume(IERC20(_vault_).totalSupply() > 0);
        vm.prank(caller); uint shares2 = vault_deposit(assets, caller);
        assertApproxLeAbs(shares2, shares, _delta_);
    }
    function prop_RT_redeem_mint(address caller, uint shares) public {
        vm.prank(caller); uint assets1 = vault_redeem(shares, caller, caller);
        if (!_vaultMayBeEmpty) vm.assume(IERC20(_vault_).totalSupply() > 0);
        vm.prank(caller); uint assets2 = vault_mint(shares, caller);
        assertApproxGeAbs(assets2, assets1, _delta_);
    }
    function prop_RT_mint_withdraw(address caller, uint shares) public {
        if (!_vaultMayBeEmpty) vm.assume(IERC20(_vault_).totalSupply() > 0);
        vm.prank(caller); uint assets = vault_mint(shares, caller);
        vm.prank(caller); uint shares2 = vault_withdraw(assets, caller, caller);
        assertApproxGeAbs(shares2, shares, _delta_);
    }
    function prop_RT_mint_redeem(address caller, uint shares) public {
        if (!_vaultMayBeEmpty) vm.assume(IERC20(_vault_).totalSupply() > 0);
        vm.prank(caller); uint assets1 = vault_mint(shares, caller);
        vm.prank(caller); uint assets2 = vault_redeem(shares, caller, caller);
        assertApproxLeAbs(assets2, assets1, _delta_);
    }
    function prop_RT_withdraw_mint(address caller, uint assets) public {
        vm.prank(caller); uint shares = vault_withdraw(assets, caller, caller);
        if (!_vaultMayBeEmpty) vm.assume(IERC20(_vault_).totalSupply() > 0);
        vm.prank(caller); uint assets2 = vault_mint(shares, caller);
        assertApproxGeAbs(assets2, assets, _delta_);
    }
    function prop_RT_withdraw_deposit(address caller, uint assets) public {
        vm.prank(caller); uint shares1 = vault_withdraw(assets, caller, caller);
        if (!_vaultMayBeEmpty) vm.assume(IERC20(_vault_).totalSupply() > 0);
        vm.prank(caller); uint shares2 = vault_deposit(assets, caller);
        assertApproxLeAbs(shares2, shares1, _delta_);
    }
    function vault_convertToShares(uint assets) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(IERC4626.convertToShares.selector, assets));
    }
    function vault_convertToAssets(uint shares) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(IERC4626.convertToAssets.selector, shares));
    }
    function vault_maxDeposit(address receiver) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(IERC4626.maxDeposit.selector, receiver));
    }
    function vault_maxMint(address receiver) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(IERC4626.maxMint.selector, receiver));
    }
    function vault_maxWithdraw(address owner) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(IERC4626.maxWithdraw.selector, owner));
    }
    function vault_maxRedeem(address owner) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(IERC4626.maxRedeem.selector, owner));
    }
    function vault_previewDeposit(uint assets) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(IERC4626.previewDeposit.selector, assets));
    }
    function vault_previewMint(uint shares) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(IERC4626.previewMint.selector, shares));
    }
    function vault_previewWithdraw(uint assets) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(IERC4626.previewWithdraw.selector, assets));
    }
    function vault_previewRedeem(uint shares) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(IERC4626.previewRedeem.selector, shares));
    }
    function vault_deposit(uint assets, address receiver) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(IERC4626.deposit.selector, assets, receiver));
    }
    function vault_mint(uint shares, address receiver) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(IERC4626.mint.selector, shares, receiver));
    }
    function vault_withdraw(uint assets, address receiver, address owner) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(IERC4626.withdraw.selector, assets, receiver, owner));
    }
    function vault_redeem(uint shares, address receiver, address owner) internal returns (uint) {
        return _call_vault(abi.encodeWithSelector(IERC4626.redeem.selector, shares, receiver, owner));
    }
    function _call_vault(bytes memory data) internal returns (uint) {
        (bool success, bytes memory retdata) = _vault_.call(data);
        if (success) return abi.decode(retdata, (uint));
        vm.assume(false); 
        return 0; 
    }
    function assertApproxGeAbs(uint a, uint b, uint maxDelta) internal {
        if (!(a >= b)) {
            uint dt = b - a;
            if (dt > maxDelta) {
                emit log                ("Error: a >=~ b not satisfied [uint]");
                emit log_named_uint     ("   Value a", a);
                emit log_named_uint     ("   Value b", b);
                emit log_named_uint     (" Max Delta", maxDelta);
                emit log_named_uint     ("     Delta", dt);
                fail();
            }
        }
    }
    function assertApproxLeAbs(uint a, uint b, uint maxDelta) internal {
        if (!(a <= b)) {
            uint dt = a - b;
            if (dt > maxDelta) {
                emit log                ("Error: a <=~ b not satisfied [uint]");
                emit log_named_uint     ("   Value a", a);
                emit log_named_uint     ("   Value b", b);
                emit log_named_uint     (" Max Delta", maxDelta);
                emit log_named_uint     ("     Delta", dt);
                fail();
            }
        }
    }
}