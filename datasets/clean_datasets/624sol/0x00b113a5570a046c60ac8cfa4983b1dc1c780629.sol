pragma solidity >=0.5.4 <0.6.0;
interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes calldata _extraData) external; }
library SafeMath {
	function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
		if (a == 0) {
			return 0;
		}
		c = a * b;
		assert(c / a == b);
		return c;
	}
	function div(uint256 a, uint256 b) internal pure returns (uint256) {
		return a / b;
	}
	function sub(uint256 a, uint256 b) internal pure returns (uint256) {
		assert(b <= a);
		return a - b;
	}
	function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
		c = a + b;
		assert(c >= a);
		return c;
	}
}
interface INameTAOPosition {
	function senderIsAdvocate(address _sender, address _id) external view returns (bool);
	function senderIsListener(address _sender, address _id) external view returns (bool);
	function senderIsSpeaker(address _sender, address _id) external view returns (bool);
	function senderIsPosition(address _sender, address _id) external view returns (bool);
	function getAdvocate(address _id) external view returns (address);
	function nameIsAdvocate(address _nameId, address _id) external view returns (bool);
	function nameIsPosition(address _nameId, address _id) external view returns (bool);
	function initialize(address _id, address _advocateId, address _listenerId, address _speakerId) external returns (bool);
	function determinePosition(address _sender, address _id) external view returns (uint256);
}
interface INameTAOLookup {
	function isExist(string calldata _name) external view returns (bool);
	function initialize(string calldata _name, address _nameTAOId, uint256 _typeId, string calldata _parentName, address _parentId, uint256 _parentTypeId) external returns (bool);
	function getById(address _id) external view returns (string memory, address, uint256, string memory, address, uint256);
	function getIdByName(string calldata _name) external view returns (address);
}
contract TheAO {
	address public theAO;
	address public nameTAOPositionAddress;
	mapping (address => bool) public whitelist;
	constructor() public {
		theAO = msg.sender;
	}
	modifier inWhitelist() {
		require (whitelist[msg.sender] == true);
		_;
	}
	function transferOwnership(address _theAO) public {
		require (msg.sender == theAO);
		require (_theAO != address(0));
		theAO = _theAO;
	}
	function setWhitelist(address _account, bool _whitelist) public {
		require (msg.sender == theAO);
		require (_account != address(0));
		whitelist[_account] = _whitelist;
	}
}
contract TokenERC20 {
	string public name;
	string public symbol;
	uint8 public decimals = 18;
	uint256 public totalSupply;
	mapping (address => uint256) public balanceOf;
	mapping (address => mapping (address => uint256)) public allowance;
	event Transfer(address indexed from, address indexed to, uint256 value);
	event Approval(address indexed _owner, address indexed _spender, uint256 _value);
	event Burn(address indexed from, uint256 value);
	constructor (uint256 initialSupply, string memory tokenName, string memory tokenSymbol) public {
		totalSupply = initialSupply * 10 ** uint256(decimals);  
		balanceOf[msg.sender] = totalSupply;                
		name = tokenName;                                   
		symbol = tokenSymbol;                               
	}
	function _transfer(address _from, address _to, uint _value) internal {
		require(_to != address(0));
		require(balanceOf[_from] >= _value);
		require(balanceOf[_to] + _value > balanceOf[_to]);
		uint previousBalances = balanceOf[_from] + balanceOf[_to];
		balanceOf[_from] -= _value;
		balanceOf[_to] += _value;
		emit Transfer(_from, _to, _value);
		assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
	}
	function transfer(address _to, uint256 _value) public returns (bool success) {
		_transfer(msg.sender, _to, _value);
		return true;
	}
	function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
		require(_value <= allowance[_from][msg.sender]);     
		allowance[_from][msg.sender] -= _value;
		_transfer(_from, _to, _value);
		return true;
	}
	function approve(address _spender, uint256 _value) public returns (bool success) {
		allowance[msg.sender][_spender] = _value;
		emit Approval(msg.sender, _spender, _value);
		return true;
	}
	function approveAndCall(address _spender, uint256 _value, bytes memory _extraData) public returns (bool success) {
		tokenRecipient spender = tokenRecipient(_spender);
		if (approve(_spender, _value)) {
			spender.receiveApproval(msg.sender, _value, address(this), _extraData);
			return true;
		}
	}
	function burn(uint256 _value) public returns (bool success) {
		require(balanceOf[msg.sender] >= _value);   
		balanceOf[msg.sender] -= _value;            
		totalSupply -= _value;                      
		emit Burn(msg.sender, _value);
		return true;
	}
	function burnFrom(address _from, uint256 _value) public returns (bool success) {
		require(balanceOf[_from] >= _value);                
		require(_value <= allowance[_from][msg.sender]);    
		balanceOf[_from] -= _value;                         
		allowance[_from][msg.sender] -= _value;             
		totalSupply -= _value;                              
		emit Burn(_from, _value);
		return true;
	}
}
contract TAO {
	using SafeMath for uint256;
	address public vaultAddress;
	string public name;				
	address public originId;		
	string public datHash;
	string public database;
	string public keyValue;
	bytes32 public contentId;
	uint8 public typeId;
	constructor (string memory _name,
		address _originId,
		string memory _datHash,
		string memory _database,
		string memory _keyValue,
		bytes32 _contentId,
		address _vaultAddress
	) public {
		name = _name;
		originId = _originId;
		datHash = _datHash;
		database = _database;
		keyValue = _keyValue;
		contentId = _contentId;
		typeId = 0;
		vaultAddress = _vaultAddress;
	}
	modifier onlyVault {
		require (msg.sender == vaultAddress);
		_;
	}
	function () external payable {
	}
	function transferEth(address payable _recipient, uint256 _amount) public onlyVault returns (bool) {
		_recipient.transfer(_amount);
		return true;
	}
	function transferERC20(address _erc20TokenAddress, address _recipient, uint256 _amount) public onlyVault returns (bool) {
		TokenERC20 _erc20 = TokenERC20(_erc20TokenAddress);
		_erc20.transfer(_recipient, _amount);
		return true;
	}
}
contract Name is TAO {
	constructor (string memory _name, address _originId, string memory _datHash, string memory _database, string memory _keyValue, bytes32 _contentId, address _vaultAddress)
		TAO (_name, _originId, _datHash, _database, _keyValue, _contentId, _vaultAddress) public {
		typeId = 1;
	}
}
library AOLibrary {
	using SafeMath for uint256;
	uint256 constant private _MULTIPLIER_DIVISOR = 10 ** 6; 
	uint256 constant private _PERCENTAGE_DIVISOR = 10 ** 6; 
	function isTAO(address _taoId) public view returns (bool) {
		return (_taoId != address(0) && bytes(TAO(address(uint160(_taoId))).name()).length > 0 && TAO(address(uint160(_taoId))).originId() != address(0) && TAO(address(uint160(_taoId))).typeId() == 0);
	}
	function isName(address _nameId) public view returns (bool) {
		return (_nameId != address(0) && bytes(TAO(address(uint160(_nameId))).name()).length > 0 && Name(address(uint160(_nameId))).originId() != address(0) && Name(address(uint160(_nameId))).typeId() == 1);
	}
	function isValidERC20TokenAddress(address _tokenAddress) public view returns (bool) {
		if (_tokenAddress == address(0)) {
			return false;
		}
		TokenERC20 _erc20 = TokenERC20(_tokenAddress);
		return (_erc20.totalSupply() >= 0 && bytes(_erc20.name()).length > 0 && bytes(_erc20.symbol()).length > 0);
	}
	function isTheAO(address _sender, address _theAO, address _nameTAOPositionAddress) public view returns (bool) {
		return (_sender == _theAO ||
			(
				(isTAO(_theAO) || isName(_theAO)) &&
				_nameTAOPositionAddress != address(0) &&
				INameTAOPosition(_nameTAOPositionAddress).senderIsAdvocate(_sender, _theAO)
			)
		);
	}
	function PERCENTAGE_DIVISOR() public pure returns (uint256) {
		return _PERCENTAGE_DIVISOR;
	}
	function MULTIPLIER_DIVISOR() public pure returns (uint256) {
		return _MULTIPLIER_DIVISOR;
	}
	function deployTAO(string memory _name,
		address _originId,
		string memory _datHash,
		string memory _database,
		string memory _keyValue,
		bytes32 _contentId,
		address _nameTAOVaultAddress
		) public returns (TAO _tao) {
		_tao = new TAO(_name, _originId, _datHash, _database, _keyValue, _contentId, _nameTAOVaultAddress);
	}
	function deployName(string memory _name,
		address _originId,
		string memory _datHash,
		string memory _database,
		string memory _keyValue,
		bytes32 _contentId,
		address _nameTAOVaultAddress
		) public returns (Name _myName) {
		_myName = new Name(_name, _originId, _datHash, _database, _keyValue, _contentId, _nameTAOVaultAddress);
	}
	function calculateWeightedMultiplier(uint256 _currentWeightedMultiplier, uint256 _currentPrimordialBalance, uint256 _additionalWeightedMultiplier, uint256 _additionalPrimordialAmount) public pure returns (uint256) {
		if (_currentWeightedMultiplier > 0) {
			uint256 _totalWeightedIons = (_currentWeightedMultiplier.mul(_currentPrimordialBalance)).add(_additionalWeightedMultiplier.mul(_additionalPrimordialAmount));
			uint256 _totalIons = _currentPrimordialBalance.add(_additionalPrimordialAmount);
			return _totalWeightedIons.div(_totalIons);
		} else {
			return _additionalWeightedMultiplier;
		}
	}
	function calculatePrimordialMultiplier(uint256 _purchaseAmount, uint256 _totalPrimordialMintable, uint256 _totalPrimordialMinted, uint256 _startingMultiplier, uint256 _endingMultiplier) public pure returns (uint256) {
		if (_purchaseAmount > 0 && _purchaseAmount <= _totalPrimordialMintable.sub(_totalPrimordialMinted)) {
			uint256 temp = _totalPrimordialMinted.add(_purchaseAmount.div(2));
			uint256 multiplier = (_MULTIPLIER_DIVISOR.sub(_MULTIPLIER_DIVISOR.mul(temp).div(_totalPrimordialMintable))).mul(_startingMultiplier.sub(_endingMultiplier));
			return multiplier.div(_MULTIPLIER_DIVISOR);
		} else {
			return 0;
		}
	}
	function calculateNetworkBonusPercentage(uint256 _purchaseAmount, uint256 _totalPrimordialMintable, uint256 _totalPrimordialMinted, uint256 _startingMultiplier, uint256 _endingMultiplier) public pure returns (uint256) {
		if (_purchaseAmount > 0 && _purchaseAmount <= _totalPrimordialMintable.sub(_totalPrimordialMinted)) {
			uint256 temp = _totalPrimordialMinted.add(_purchaseAmount.div(2));
			uint256 bonusPercentage = (_PERCENTAGE_DIVISOR.sub(_PERCENTAGE_DIVISOR.mul(temp).div(_totalPrimordialMintable))).mul(_startingMultiplier.sub(_endingMultiplier)).div(_PERCENTAGE_DIVISOR);
			return bonusPercentage;
		} else {
			return 0;
		}
	}
	function calculateNetworkBonusAmount(uint256 _purchaseAmount, uint256 _totalPrimordialMintable, uint256 _totalPrimordialMinted, uint256 _startingMultiplier, uint256 _endingMultiplier) public pure returns (uint256) {
		uint256 bonusPercentage = calculateNetworkBonusPercentage(_purchaseAmount, _totalPrimordialMintable, _totalPrimordialMinted, _startingMultiplier, _endingMultiplier);
		uint256 networkBonus = bonusPercentage.mul(_purchaseAmount).div(_PERCENTAGE_DIVISOR);
		return networkBonus;
	}
	function calculateMaximumBurnAmount(uint256 _primordialBalance, uint256 _currentWeightedMultiplier, uint256 _maximumMultiplier) public pure returns (uint256) {
		return (_maximumMultiplier.mul(_primordialBalance).sub(_primordialBalance.mul(_currentWeightedMultiplier))).div(_maximumMultiplier);
	}
	function calculateMultiplierAfterBurn(uint256 _primordialBalance, uint256 _currentWeightedMultiplier, uint256 _amountToBurn) public pure returns (uint256) {
		return _primordialBalance.mul(_currentWeightedMultiplier).div(_primordialBalance.sub(_amountToBurn));
	}
	function calculateMultiplierAfterConversion(uint256 _primordialBalance, uint256 _currentWeightedMultiplier, uint256 _amountToConvert) public pure returns (uint256) {
		return _primordialBalance.mul(_currentWeightedMultiplier).div(_primordialBalance.add(_amountToConvert));
	}
	function numDigits(uint256 number) public pure returns (uint8) {
		uint8 digits = 0;
		while(number != 0) {
			number = number.div(10);
			digits++;
		}
		return digits;
	}
}
contract NameTAOLookup is TheAO, INameTAOLookup {
	address public nameFactoryAddress;
	address public taoFactoryAddress;
	struct NameTAOInfo {
		string name;
		address nameTAOId;
		uint256 typeId; 
		string parentName;
		address parentId; 
		uint256 parentTypeId; 
	}
	uint256 public totalNames;
	uint256 public totalTAOs;
	mapping (address => NameTAOInfo) internal nameTAOInfos;
	mapping (bytes32 => address) internal nameToNameTAOIdLookup;
	constructor(address _nameFactoryAddress, address _taoFactoryAddress, address _nameTAOPositionAddress) public {
		setNameFactoryAddress(_nameFactoryAddress);
		setTAOFactoryAddress(_taoFactoryAddress);
		setNameTAOPositionAddress(_nameTAOPositionAddress);
	}
	modifier onlyTheAO {
		require (AOLibrary.isTheAO(msg.sender, theAO, nameTAOPositionAddress));
		_;
	}
	modifier onlyFactory {
		require (msg.sender == nameFactoryAddress || msg.sender == taoFactoryAddress);
		_;
	}
	function transferOwnership(address _theAO) public onlyTheAO {
		require (_theAO != address(0));
		theAO = _theAO;
	}
	function setWhitelist(address _account, bool _whitelist) public onlyTheAO {
		require (_account != address(0));
		whitelist[_account] = _whitelist;
	}
	function setNameFactoryAddress(address _nameFactoryAddress) public onlyTheAO {
		require (_nameFactoryAddress != address(0));
		nameFactoryAddress = _nameFactoryAddress;
	}
	function setTAOFactoryAddress(address _taoFactoryAddress) public onlyTheAO {
		require (_taoFactoryAddress != address(0));
		taoFactoryAddress = _taoFactoryAddress;
	}
	function setNameTAOPositionAddress(address _nameTAOPositionAddress) public onlyTheAO {
		require (_nameTAOPositionAddress != address(0));
		nameTAOPositionAddress = _nameTAOPositionAddress;
	}
	function isExist(string calldata _name) external view returns (bool) {
		bytes32 _nameKey = keccak256(abi.encodePacked(_name));
		return (nameToNameTAOIdLookup[_nameKey] != address(0));
	}
	function initialize(string calldata _name, address _nameTAOId, uint256 _typeId, string calldata _parentName, address _parentId, uint256 _parentTypeId) external onlyFactory returns (bool) {
		require (bytes(_name).length > 0);
		require (_nameTAOId != address(0));
		require (_typeId == 0 || _typeId == 1);
		require (bytes(_parentName).length > 0);
		require (_parentId != address(0));
		require (_parentTypeId >= 0 && _parentTypeId <= 2);
		require (!this.isExist(_name));
		if (_parentTypeId != 2) {
			require (this.isExist(_parentName));
		}
		bytes32 _nameKey = keccak256(abi.encodePacked(_name));
		nameToNameTAOIdLookup[_nameKey] = _nameTAOId;
		NameTAOInfo storage _nameTAOInfo = nameTAOInfos[_nameTAOId];
		_nameTAOInfo.name = _name;
		_nameTAOInfo.nameTAOId = _nameTAOId;
		_nameTAOInfo.typeId = _typeId;
		_nameTAOInfo.parentName = _parentName;
		_nameTAOInfo.parentId = _parentId;
		_nameTAOInfo.parentTypeId = _parentTypeId;
		if (_typeId == 0) {
			totalTAOs++;
		} else {
			totalNames++;
		}
		return true;
	}
	function getByName(string memory _name) public view returns (string memory, address, uint256, string memory, address, uint256) {
		require (this.isExist(_name));
		bytes32 _nameKey = keccak256(abi.encodePacked(_name));
		NameTAOInfo memory _nameTAOInfo = nameTAOInfos[nameToNameTAOIdLookup[_nameKey]];
		return (
			_nameTAOInfo.name,
			_nameTAOInfo.nameTAOId,
			_nameTAOInfo.typeId,
			_nameTAOInfo.parentName,
			_nameTAOInfo.parentId,
			_nameTAOInfo.parentTypeId
		);
	}
	function getById(address _id) external view returns (string memory, address, uint256, string memory, address, uint256) {
		require (nameTAOInfos[_id].nameTAOId != address(0));
		NameTAOInfo memory _nameTAOInfo = nameTAOInfos[_id];
		return (
			_nameTAOInfo.name,
			_nameTAOInfo.nameTAOId,
			_nameTAOInfo.typeId,
			_nameTAOInfo.parentName,
			_nameTAOInfo.parentId,
			_nameTAOInfo.parentTypeId
		);
	}
	function getIdByName(string calldata _name) external view returns (address) {
		bytes32 _nameKey = keccak256(abi.encodePacked(_name));
		return nameToNameTAOIdLookup[_nameKey];
	}
}