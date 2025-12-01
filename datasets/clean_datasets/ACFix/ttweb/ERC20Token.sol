pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
contract ERC20Token is ERC20, Pausable, AccessControl {
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    mapping (address => bool) internal isBlackListed;
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed burner, uint256 amount);
    event AddedBlackList(address indexed _user);
    event RemovedBlackList(address indexed _user);
    error NotGovernor(address caller);
    error NotGuardian(address caller);
    error NotMinter(address caller);
    error Blacklisted(address caller);
    modifier onlyGovernor() {
        if (!hasRole(GOVERNOR_ROLE, msg.sender))
            revert NotGovernor(msg.sender);
        _;
    }
    modifier onlyGuardian() {
        if (!hasRole(GUARDIAN_ROLE, msg.sender))
            revert NotGuardian(msg.sender);
        _;
    }
    modifier onlyMinter() {
        if (!hasRole(MINTER_ROLE, msg.sender))
            revert NotMinter(msg.sender);
        _;
    }
    modifier notBlacklisted(address _addr) {
        if (isBlackListed[_addr])
            revert Blacklisted(_addr);
        _;
    }
    constructor(
        string memory name_,
        string memory symbol_,
        address governor_,
        address guardian_,
        address minter_
    ) ERC20(name_, symbol_) {
        _setRoleAdmin(GOVERNOR_ROLE, GOVERNOR_ROLE);
        _setRoleAdmin(GUARDIAN_ROLE, GUARDIAN_ROLE);
        _setRoleAdmin(MINTER_ROLE, GOVERNOR_ROLE);
        _grantRole(GOVERNOR_ROLE, governor_);
        _grantRole(GUARDIAN_ROLE, guardian_);
        _grantRole(MINTER_ROLE, minter_);
    }
    function setGovernor(address newGovernor, address oldGovernor) external onlyGovernor {
        require(newGovernor != address(0), "newGovernor cannot be the zero address");
        _revokeRole(GOVERNOR_ROLE, oldGovernor);
        _grantRole(GOVERNOR_ROLE, newGovernor);
    }
    function revokeGovernor(address oldGovernor) external onlyGovernor {
        require(oldGovernor != address(0), "oldGovernor cannot be the zero address");
        _revokeRole(GOVERNOR_ROLE, oldGovernor);
    }
    function setGuardian(address newGuardian, address oldGuardian) external onlyGuardian {
        require(newGuardian != address(0), "newGuardian cannot be the zero address");
        _revokeRole(GUARDIAN_ROLE, oldGuardian);
        _grantRole(GUARDIAN_ROLE, newGuardian);
    }
    function revokeGuardian(address oldGuardian) external onlyGuardian {
        require(oldGuardian != address(0), "oldGuardian cannot be the zero address");
        _revokeRole(GUARDIAN_ROLE, oldGuardian);
    }
    function setMinter(address newMinter, address oldMinter) external onlyGovernor {
        require(newMinter != address(0), "newMinter cannot be the zero address");
        _revokeRole(MINTER_ROLE, oldMinter);
        _grantRole(MINTER_ROLE, newMinter);
    }
    function revokeMinter(address oldMinter) external onlyGovernor {
        require(oldMinter != address(0), "oldMinter cannot be the zero address");
        _revokeRole(MINTER_ROLE, oldMinter);
    }
    function pause() external onlyGuardian {
        _pause();
    }
    function unpause() external onlyGuardian {
        _unpause();
    }
    function mint(address account, uint256 amount) external onlyMinter whenNotPaused notBlacklisted(account) {
        require(amount != 0, "Invalid amount");
        _mint(account, amount);
        emit Mint(account, amount);
    }
    function burn(address burner, uint256 amount) external onlyMinter whenNotPaused notBlacklisted(burner) {
        require(amount != 0, "Invalid amount");
        _burn(burner, amount);
        emit Burn(burner, amount);
    }
        function transfer(address recipient, uint256 amount) public whenNotPaused notBlacklisted(msg.sender) notBlacklisted(recipient) override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public whenNotPaused notBlacklisted(msg.sender) notBlacklisted(from) notBlacklisted(to) override returns (bool) {
        _spendAllowance(from, _msgSender(), amount);
        _transfer(from, to, amount);
        return true;
    }
    function approve(address spender, uint256 amount) public whenNotPaused notBlacklisted(msg.sender) notBlacklisted(spender) override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) public whenNotPaused notBlacklisted(msg.sender) notBlacklisted(spender) override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public whenNotPaused notBlacklisted(msg.sender) notBlacklisted(spender) override returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }
    function addBlackList(address evilUser) public onlyGuardian {
        require(evilUser != address(0), "Invalid address");
        isBlackListed[evilUser] = true;
        emit AddedBlackList(evilUser);
    }
    function removeBlackList(address clearedUser) public onlyGuardian {
        isBlackListed[clearedUser] = false;
        emit RemovedBlackList(clearedUser);
    }
    function getBlacklist(address addr) public onlyGuardian view returns(bool) {
        return isBlackListed[addr];
    }
}