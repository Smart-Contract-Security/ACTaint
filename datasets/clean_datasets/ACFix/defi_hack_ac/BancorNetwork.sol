pragma solidity 0.4.26;
contract IERC20Token {
    function name() public view returns (string) {this;}
    function symbol() public view returns (string) {this;}
    function decimals() public view returns (uint8) {this;}
    function totalSupply() public view returns (uint256) {this;}
    function balanceOf(address _owner) public view returns (uint256) {_owner; this;}
    function allowance(address _owner, address _spender) public view returns (uint256) {_owner; _spender; this;}
    function transfer(address _to, uint256 _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
    function approve(address _spender, uint256 _value) public returns (bool success);
}
pragma solidity 0.4.26;
contract IBancorNetwork {
    function convert2(
        IERC20Token[] _path,
        uint256 _amount,
        uint256 _minReturn,
        address _affiliateAccount,
        uint256 _affiliateFee
    ) public payable returns (uint256);
    function claimAndConvert2(
        IERC20Token[] _path,
        uint256 _amount,
        uint256 _minReturn,
        address _affiliateAccount,
        uint256 _affiliateFee
    ) public returns (uint256);
    function convertFor2(
        IERC20Token[] _path,
        uint256 _amount,
        uint256 _minReturn,
        address _for,
        address _affiliateAccount,
        uint256 _affiliateFee
    ) public payable returns (uint256);
    function claimAndConvertFor2(
        IERC20Token[] _path,
        uint256 _amount,
        uint256 _minReturn,
        address _for,
        address _affiliateAccount,
        uint256 _affiliateFee
    ) public returns (uint256);
    function convert(
        IERC20Token[] _path,
        uint256 _amount,
        uint256 _minReturn
    ) public payable returns (uint256);
    function claimAndConvert(
        IERC20Token[] _path,
        uint256 _amount,
        uint256 _minReturn
    ) public returns (uint256);
    function convertFor(
        IERC20Token[] _path,
        uint256 _amount,
        uint256 _minReturn,
        address _for
    ) public payable returns (uint256);
    function claimAndConvertFor(
        IERC20Token[] _path,
        uint256 _amount,
        uint256 _minReturn,
        address _for
    ) public returns (uint256);
}
pragma solidity 0.4.26;
contract IConversionPathFinder {
    function findPath(address _sourceToken, address _targetToken) public view returns (address[] memory);
}
pragma solidity 0.4.26;
contract IOwned {
    function owner() public view returns (address) {this;}
    function transferOwnership(address _newOwner) public;
    function acceptOwnership() public;
}
pragma solidity 0.4.26;
contract ITokenHolder is IOwned {
    function withdrawTokens(IERC20Token _token, address _to, uint256 _amount) public;
}
pragma solidity 0.4.26;
contract IConverterAnchor is IOwned, ITokenHolder {
}
pragma solidity 0.4.26;
contract IWhitelist {
    function isWhitelisted(address _address) public view returns (bool);
}
pragma solidity 0.4.26;
contract IConverter is IOwned {
    function converterType() public pure returns (uint16);
    function anchor() public view returns (IConverterAnchor) {this;}
    function isActive() public view returns (bool);
    function rateAndFee(IERC20Token _sourceToken, IERC20Token _targetToken, uint256 _amount) public view returns (uint256, uint256);
    function convert(IERC20Token _sourceToken,
                     IERC20Token _targetToken,
                     uint256 _amount,
                     address _trader,
                     address _beneficiary) public payable returns (uint256);
    function conversionWhitelist() public view returns (IWhitelist) {this;}
    function conversionFee() public view returns (uint32) {this;}
    function maxConversionFee() public view returns (uint32) {this;}
    function reserveBalance(IERC20Token _reserveToken) public view returns (uint256);
    function() external payable;
    function transferAnchorOwnership(address _newOwner) public;
    function acceptAnchorOwnership() public;
    function setConversionFee(uint32 _conversionFee) public;
    function setConversionWhitelist(IWhitelist _whitelist) public;
    function withdrawTokens(IERC20Token _token, address _to, uint256 _amount) public;
    function withdrawETH(address _to) public;
    function addReserve(IERC20Token _token, uint32 _ratio) public;
    function token() public view returns (IConverterAnchor);
    function transferTokenOwnership(address _newOwner) public;
    function acceptTokenOwnership() public;
    function connectors(address _address) public view returns (uint256, uint32, bool, bool, bool);
    function getConnectorBalance(IERC20Token _connectorToken) public view returns (uint256);
    function connectorTokens(uint256 _index) public view returns (IERC20Token);
    function connectorTokenCount() public view returns (uint16);
}
pragma solidity 0.4.26;
contract IBancorFormula {
    function purchaseRate(uint256 _supply,
                          uint256 _reserveBalance,
                          uint32 _reserveWeight,
                          uint256 _amount)
                          public view returns (uint256);
    function saleRate(uint256 _supply,
                      uint256 _reserveBalance,
                      uint32 _reserveWeight,
                      uint256 _amount)
                      public view returns (uint256);
    function crossReserveRate(uint256 _sourceReserveBalance,
                              uint32 _sourceReserveWeight,
                              uint256 _targetReserveBalance,
                              uint32 _targetReserveWeight,
                              uint256 _amount)
                              public view returns (uint256);
    function fundCost(uint256 _supply,
                      uint256 _reserveBalance,
                      uint32 _reserveRatio,
                      uint256 _amount)
                      public view returns (uint256);
    function liquidateRate(uint256 _supply,
                           uint256 _reserveBalance,
                           uint32 _reserveRatio,
                           uint256 _amount)
                           public view returns (uint256);
}
pragma solidity 0.4.26;
contract Owned is IOwned {
    address public owner;
    address public newOwner;
    event OwnerUpdate(address indexed _prevOwner, address indexed _newOwner);
    constructor() public {
        owner = msg.sender;
    }
    modifier ownerOnly {
        _ownerOnly();
        _;
    }
    function _ownerOnly() internal view {
        require(msg.sender == owner, "ERR_ACCESS_DENIED");
    }
    function transferOwnership(address _newOwner) public ownerOnly {
        require(_newOwner != owner, "ERR_SAME_OWNER");
        newOwner = _newOwner;
    }
    function acceptOwnership() public {
        require(msg.sender == newOwner, "ERR_ACCESS_DENIED");
        emit OwnerUpdate(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}
pragma solidity 0.4.26;
contract Utils {
    modifier greaterThanZero(uint256 _value) {
        _greaterThanZero(_value);
        _;
    }
    function _greaterThanZero(uint256 _value) internal pure {
        require(_value > 0, "ERR_ZERO_VALUE");
    }
    modifier validAddress(address _address) {
        _validAddress(_address);
        _;
    }
    function _validAddress(address _address) internal pure {
        require(_address != address(0), "ERR_INVALID_ADDRESS");
    }
    modifier notThis(address _address) {
        _notThis(_address);
        _;
    }
    function _notThis(address _address) internal view {
        require(_address != address(this), "ERR_ADDRESS_IS_SELF");
    }
}
pragma solidity 0.4.26;
contract IContractRegistry {
    function addressOf(bytes32 _contractName) public view returns (address);
    function getAddress(bytes32 _contractName) public view returns (address);
}
pragma solidity 0.4.26;
contract ContractRegistryClient is Owned, Utils {
    bytes32 internal constant CONTRACT_REGISTRY = "ContractRegistry";
    bytes32 internal constant BANCOR_NETWORK = "BancorNetwork";
    bytes32 internal constant BANCOR_FORMULA = "BancorFormula";
    bytes32 internal constant CONVERTER_FACTORY = "ConverterFactory";
    bytes32 internal constant CONVERSION_PATH_FINDER = "ConversionPathFinder";
    bytes32 internal constant CONVERTER_UPGRADER = "BancorConverterUpgrader";
    bytes32 internal constant CONVERTER_REGISTRY = "BancorConverterRegistry";
    bytes32 internal constant CONVERTER_REGISTRY_DATA = "BancorConverterRegistryData";
    bytes32 internal constant BNT_TOKEN = "BNTToken";
    bytes32 internal constant BANCOR_X = "BancorX";
    bytes32 internal constant BANCOR_X_UPGRADER = "BancorXUpgrader";
    IContractRegistry public registry;      
    IContractRegistry public prevRegistry;  
    bool public onlyOwnerCanUpdateRegistry; 
    modifier only(bytes32 _contractName) {
        _only(_contractName);
        _;
    }
    function _only(bytes32 _contractName) internal view {
        require(msg.sender == addressOf(_contractName), "ERR_ACCESS_DENIED");
    }
    constructor(IContractRegistry _registry) internal validAddress(_registry) {
        registry = IContractRegistry(_registry);
        prevRegistry = IContractRegistry(_registry);
    }
    function updateRegistry() public {
        require(msg.sender == owner || !onlyOwnerCanUpdateRegistry, "ERR_ACCESS_DENIED");
        IContractRegistry newRegistry = IContractRegistry(addressOf(CONTRACT_REGISTRY));
        require(newRegistry != address(registry) && newRegistry != address(0), "ERR_INVALID_REGISTRY");
        require(newRegistry.addressOf(CONTRACT_REGISTRY) != address(0), "ERR_INVALID_REGISTRY");
        prevRegistry = registry;
        registry = newRegistry;
    }
    function restoreRegistry() public ownerOnly {
        registry = prevRegistry;
    }
    function restrictRegistryUpdate(bool _onlyOwnerCanUpdateRegistry) public ownerOnly {
        onlyOwnerCanUpdateRegistry = _onlyOwnerCanUpdateRegistry;
    }
    function addressOf(bytes32 _contractName) internal view returns (address) {
        return registry.addressOf(_contractName);
    }
}
pragma solidity 0.4.26;
contract ReentrancyGuard {
    bool private locked = false;
    constructor() internal {}
    modifier protected() {
        _protected();
        locked = true;
        _;
        locked = false;
    }
    function _protected() internal view {
        require(!locked, "ERR_REENTRANCY");
    }
}
pragma solidity 0.4.26;
contract TokenHandler {
    bytes4 private constant APPROVE_FUNC_SELECTOR = bytes4(keccak256("approve(address,uint256)"));
    bytes4 private constant TRANSFER_FUNC_SELECTOR = bytes4(keccak256("transfer(address,uint256)"));
    bytes4 private constant TRANSFER_FROM_FUNC_SELECTOR = bytes4(keccak256("transferFrom(address,address,uint256)"));
    function safeApprove(IERC20Token _token, address _spender, uint256 _value) public {
       execute(_token, abi.encodeWithSelector(APPROVE_FUNC_SELECTOR, _spender, _value));
    }
    function safeTransfer(IERC20Token _token, address _to, uint256 _value) public {
       execute(_token, abi.encodeWithSelector(TRANSFER_FUNC_SELECTOR, _to, _value));
    }
    function safeTransferFrom(IERC20Token _token, address _from, address _to, uint256 _value) public {
       execute(_token, abi.encodeWithSelector(TRANSFER_FROM_FUNC_SELECTOR, _from, _to, _value));
    }
    function execute(IERC20Token _token, bytes memory _data) private {
        uint256[1] memory ret = [uint256(1)];
        assembly {
            let success := call(
                gas,            
                _token,         
                0,              
                add(_data, 32), 
                mload(_data),   
                ret,            
                32              
            )
            if iszero(success) {
                revert(0, 0)
            }
        }
        require(ret[0] != 0, "ERR_TRANSFER_FAILED");
    }
}
pragma solidity 0.4.26;
contract TokenHolder is ITokenHolder, TokenHandler, Owned, Utils {
    function withdrawTokens(IERC20Token _token, address _to, uint256 _amount)
        public
        ownerOnly
        validAddress(_token)
        validAddress(_to)
        notThis(_to)
    {
        safeTransfer(_token, _to, _amount);
    }
}
pragma solidity 0.4.26;
library SafeMath {
    function add(uint256 _x, uint256 _y) internal pure returns (uint256) {
        uint256 z = _x + _y;
        require(z >= _x, "ERR_OVERFLOW");
        return z;
    }
    function sub(uint256 _x, uint256 _y) internal pure returns (uint256) {
        require(_x >= _y, "ERR_UNDERFLOW");
        return _x - _y;
    }
    function mul(uint256 _x, uint256 _y) internal pure returns (uint256) {
        if (_x == 0)
            return 0;
        uint256 z = _x * _y;
        require(z / _x == _y, "ERR_OVERFLOW");
        return z;
    }
    function div(uint256 _x, uint256 _y) internal pure returns (uint256) {
        require(_y > 0, "ERR_DIVIDE_BY_ZERO");
        uint256 c = _x / _y;
        return c;
    }
}
pragma solidity 0.4.26;
contract IEtherToken is IERC20Token {
    function deposit() public payable;
    function withdraw(uint256 _amount) public;
    function depositTo(address _to) public payable;
    function withdrawTo(address _to, uint256 _amount) public;
}
pragma solidity 0.4.26;
contract ISmartToken is IConverterAnchor, IERC20Token {
    function disableTransfers(bool _disable) public;
    function issue(address _to, uint256 _amount) public;
    function destroy(address _from, uint256 _amount) public;
}
pragma solidity 0.4.26;
contract IBancorX {
    function token() public view returns (IERC20Token) {this;}
    function xTransfer(bytes32 _toBlockchain, bytes32 _to, uint256 _amount, uint256 _id) public;
    function getXTransferAmount(uint256 _xTransferId, address _for) public view returns (uint256);
}
pragma solidity 0.4.26;
contract ILegacyConverter {
    function change(IERC20Token _sourceToken, IERC20Token _targetToken, uint256 _amount, uint256 _minReturn) public returns (uint256);
}
contract BancorNetwork is IBancorNetwork, TokenHolder, ContractRegistryClient, ReentrancyGuard {
    using SafeMath for uint256;
    uint256 private constant CONVERSION_FEE_RESOLUTION = 1000000;
    uint256 private constant AFFILIATE_FEE_RESOLUTION = 1000000;
    address private constant ETH_RESERVE_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    struct ConversionStep {
        IConverter converter;
        IConverterAnchor anchor;
        IERC20Token sourceToken;
        IERC20Token targetToken;
        address beneficiary;
        bool isV28OrHigherConverter;
        bool processAffiliateFee;
    }
    uint256 public maxAffiliateFee = 30000;     
    mapping (address => bool) public etherTokens;       
    event Conversion(
        address indexed _smartToken,
        address indexed _fromToken,
        address indexed _toToken,
        uint256 _fromAmount,
        uint256 _toAmount,
        address _trader
    );
    constructor(IContractRegistry _registry) ContractRegistryClient(_registry) public {
        etherTokens[ETH_RESERVE_ADDRESS] = true;
    }
    function setMaxAffiliateFee(uint256 _maxAffiliateFee)
        public
        ownerOnly
    {
        require(_maxAffiliateFee <= AFFILIATE_FEE_RESOLUTION, "ERR_INVALID_AFFILIATE_FEE");
        maxAffiliateFee = _maxAffiliateFee;
    }
    function registerEtherToken(IEtherToken _token, bool _register)
        public
        ownerOnly
        validAddress(_token)
        notThis(_token)
    {
        etherTokens[_token] = _register;
    }
    function conversionPath(IERC20Token _sourceToken, IERC20Token _targetToken) public view returns (address[]) {
        IConversionPathFinder pathFinder = IConversionPathFinder(addressOf(CONVERSION_PATH_FINDER));
        return pathFinder.findPath(_sourceToken, _targetToken);
    }
    function rateByPath(IERC20Token[] _path, uint256 _amount) public view returns (uint256) {
        uint256 amount;
        uint256 fee;
        uint256 supply;
        uint256 balance;
        uint32 weight;
        IConverter converter;
        IBancorFormula formula = IBancorFormula(addressOf(BANCOR_FORMULA));
        amount = _amount;
        require(_path.length > 2 && _path.length % 2 == 1, "ERR_INVALID_PATH");
        for (uint256 i = 2; i < _path.length; i += 2) {
            IERC20Token sourceToken = _path[i - 2];
            IERC20Token anchor = _path[i - 1];
            IERC20Token targetToken = _path[i];
            if (etherTokens[sourceToken])
                sourceToken = IERC20Token(ETH_RESERVE_ADDRESS);
            if (etherTokens[targetToken])
                targetToken = IERC20Token(ETH_RESERVE_ADDRESS);
            if (targetToken == anchor) { 
                if (i < 3 || anchor != _path[i - 3]) {
                    supply = ISmartToken(anchor).totalSupply();
                    converter = IConverter(IConverterAnchor(anchor).owner());
                }
                balance = converter.getConnectorBalance(sourceToken);
                (, weight, , , ) = converter.connectors(sourceToken);
                amount = formula.purchaseRate(supply, balance, weight, amount);
                fee = amount.mul(converter.conversionFee()).div(CONVERSION_FEE_RESOLUTION);
                amount -= fee;
                supply = supply.add(amount);
            }
            else if (sourceToken == anchor) { 
                if (i < 3 || anchor != _path[i - 3]) {
                    supply = ISmartToken(anchor).totalSupply();
                    converter = IConverter(IConverterAnchor(anchor).owner());
                }
                balance = converter.getConnectorBalance(targetToken);
                (, weight, , , ) = converter.connectors(targetToken);
                amount = formula.saleRate(supply, balance, weight, amount);
                fee = amount.mul(converter.conversionFee()).div(CONVERSION_FEE_RESOLUTION);
                amount -= fee;
                supply = supply.sub(amount);
            }
            else { 
                if (i < 3 || anchor != _path[i - 3]) {
                    converter = IConverter(IConverterAnchor(anchor).owner());
                }
                (amount, fee) = getReturn(converter, sourceToken, targetToken, amount);
            }
        }
        return amount;
    }
    function convertByPath(IERC20Token[] _path, uint256 _amount, uint256 _minReturn, address _beneficiary, address _affiliateAccount, uint256 _affiliateFee)
        public
        payable
        protected
        greaterThanZero(_minReturn)
        returns (uint256)
    {
        require(_path.length > 2 && _path.length % 2 == 1, "ERR_INVALID_PATH");
        handleSourceToken(_path[0], IConverterAnchor(_path[1]), _amount);
        bool affiliateFeeEnabled = false;
        if (address(_affiliateAccount) == 0) {
            require(_affiliateFee == 0, "ERR_INVALID_AFFILIATE_FEE");
        }
        else {
            require(0 < _affiliateFee && _affiliateFee <= maxAffiliateFee, "ERR_INVALID_AFFILIATE_FEE");
            affiliateFeeEnabled = true;
        }
        address beneficiary = msg.sender;
        if (_beneficiary != address(0))
            beneficiary = _beneficiary;
        ConversionStep[] memory data = createConversionData(_path, beneficiary, affiliateFeeEnabled);
        uint256 amount = doConversion(data, _amount, _minReturn, _affiliateAccount, _affiliateFee);
        handleTargetToken(data, amount, beneficiary);
        return amount;
    }
    function xConvert(
        IERC20Token[] _path,
        uint256 _amount,
        uint256 _minReturn,
        bytes32 _targetBlockchain,
        bytes32 _targetAccount,
        uint256 _conversionId
    )
        public
        payable
        returns (uint256)
    {
        return xConvert2(_path, _amount, _minReturn, _targetBlockchain, _targetAccount, _conversionId, address(0), 0);
    }
    function xConvert2(
        IERC20Token[] _path,
        uint256 _amount,
        uint256 _minReturn,
        bytes32 _targetBlockchain,
        bytes32 _targetAccount,
        uint256 _conversionId,
        address _affiliateAccount,
        uint256 _affiliateFee
    )
        public
        payable
        greaterThanZero(_minReturn)
        returns (uint256)
    {
        IERC20Token targetToken = _path[_path.length - 1];
        IBancorX bancorX = IBancorX(addressOf(BANCOR_X));
        require(targetToken == addressOf(BNT_TOKEN), "ERR_INVALID_TARGET_TOKEN");
        uint256 amount = convertByPath(_path, _amount, _minReturn, this, _affiliateAccount, _affiliateFee);
        ensureAllowance(targetToken, bancorX, amount);
        bancorX.xTransfer(_targetBlockchain, _targetAccount, amount, _conversionId);
        return amount;
    }
    function completeXConversion(IERC20Token[] _path, IBancorX _bancorX, uint256 _conversionId, uint256 _minReturn, address _beneficiary)
        public returns (uint256)
    {
        require(_path[0] == _bancorX.token(), "ERR_INVALID_SOURCE_TOKEN");
        uint256 amount = _bancorX.getXTransferAmount(_conversionId, msg.sender);
        return convertByPath(_path, amount, _minReturn, _beneficiary, address(0), 0);
    }
    function doConversion(
        ConversionStep[] _data,
        uint256 _amount,
        uint256 _minReturn,
        address _affiliateAccount,
        uint256 _affiliateFee
    ) private returns (uint256) {
        uint256 toAmount;
        uint256 fromAmount = _amount;
        for (uint256 i = 0; i < _data.length; i++) {
            ConversionStep memory stepData = _data[i];
            if (stepData.isV28OrHigherConverter) {
                if (i != 0 && _data[i - 1].beneficiary == address(this) && !etherTokens[stepData.sourceToken])
                    safeTransfer(stepData.sourceToken, stepData.converter, fromAmount);
            }
            else if (stepData.sourceToken != ISmartToken(stepData.anchor)) {
                ensureAllowance(stepData.sourceToken, stepData.converter, fromAmount);
            }
            if (!stepData.isV28OrHigherConverter)
                toAmount = ILegacyConverter(stepData.converter).change(stepData.sourceToken, stepData.targetToken, fromAmount, 1);
            else if (etherTokens[stepData.sourceToken])
                toAmount = stepData.converter.convert.value(msg.value)(stepData.sourceToken, stepData.targetToken, fromAmount, msg.sender, stepData.beneficiary);
            else
                toAmount = stepData.converter.convert(stepData.sourceToken, stepData.targetToken, fromAmount, msg.sender, stepData.beneficiary);
            if (stepData.processAffiliateFee) {
                uint256 affiliateAmount = toAmount.mul(_affiliateFee).div(AFFILIATE_FEE_RESOLUTION);
                require(stepData.targetToken.transfer(_affiliateAccount, affiliateAmount), "ERR_FEE_TRANSFER_FAILED");
                toAmount -= affiliateAmount;
            }
            emit Conversion(stepData.anchor, stepData.sourceToken, stepData.targetToken, fromAmount, toAmount, msg.sender);
            fromAmount = toAmount;
        }
        require(toAmount >= _minReturn, "ERR_RETURN_TOO_LOW");
        return toAmount;
    }
    function handleSourceToken(IERC20Token _sourceToken, IConverterAnchor _anchor, uint256 _amount) private {
        IConverter firstConverter = IConverter(_anchor.owner());
        bool isNewerConverter = isV28OrHigherConverter(firstConverter);
        if (msg.value > 0) {
            require(msg.value == _amount, "ERR_ETH_AMOUNT_MISMATCH");
            if (!isNewerConverter)
                IEtherToken(getConverterEtherTokenAddress(firstConverter)).deposit.value(msg.value)();
        }
        else if (etherTokens[_sourceToken]) {
            safeTransferFrom(_sourceToken, msg.sender, this, _amount);
            if (isNewerConverter)
                IEtherToken(_sourceToken).withdraw(_amount);
        }
        else {
            if (isNewerConverter)
                safeTransferFrom(_sourceToken, msg.sender, firstConverter, _amount);
            else
                safeTransferFrom(_sourceToken, msg.sender, this, _amount);
        }
    }
    function handleTargetToken(ConversionStep[] _data, uint256 _amount, address _beneficiary) private {
        ConversionStep memory stepData = _data[_data.length - 1];
        if (stepData.beneficiary != address(this))
            return;
        IERC20Token targetToken = stepData.targetToken;
        if (etherTokens[targetToken]) {
            assert(!stepData.isV28OrHigherConverter);
            IEtherToken(targetToken).withdrawTo(_beneficiary, _amount);
        }
        else {
            safeTransfer(targetToken, _beneficiary, _amount);
        }
    }
    function createConversionData(IERC20Token[] _conversionPath, address _beneficiary, bool _affiliateFeeEnabled) private view returns (ConversionStep[]) {
        ConversionStep[] memory data = new ConversionStep[](_conversionPath.length / 2);
        bool affiliateFeeProcessed = false;
        address bntToken = addressOf(BNT_TOKEN);
        uint256 i;
        for (i = 0; i < _conversionPath.length - 1; i += 2) {
            IConverterAnchor anchor = IConverterAnchor(_conversionPath[i + 1]);
            IConverter converter = IConverter(anchor.owner());
            IERC20Token targetToken = _conversionPath[i + 2];
            bool processAffiliateFee = _affiliateFeeEnabled && !affiliateFeeProcessed && targetToken == bntToken;
            if (processAffiliateFee)
                affiliateFeeProcessed = true;
            data[i / 2] = ConversionStep({
                anchor: anchor,
                converter: converter,
                sourceToken: _conversionPath[i],
                targetToken: targetToken,
                beneficiary: address(0),
                isV28OrHigherConverter: isV28OrHigherConverter(converter),
                processAffiliateFee: processAffiliateFee
            });
        }
        ConversionStep memory stepData = data[0];
        if (etherTokens[stepData.sourceToken]) {
            if (stepData.isV28OrHigherConverter)
                stepData.sourceToken = IERC20Token(ETH_RESERVE_ADDRESS);
            else
                stepData.sourceToken = IERC20Token(getConverterEtherTokenAddress(stepData.converter));
        }
        stepData = data[data.length - 1];
        if (etherTokens[stepData.targetToken]) {
            if (stepData.isV28OrHigherConverter)
                stepData.targetToken = IERC20Token(ETH_RESERVE_ADDRESS);
            else
                stepData.targetToken = IERC20Token(getConverterEtherTokenAddress(stepData.converter));
        }
        for (i = 0; i < data.length; i++) {
            stepData = data[i];
            if (stepData.isV28OrHigherConverter) {
                if (stepData.processAffiliateFee)
                    stepData.beneficiary = this;
                else if (i == data.length - 1)
                    stepData.beneficiary = _beneficiary;
                else if (data[i + 1].isV28OrHigherConverter)
                    stepData.beneficiary = data[i + 1].converter;
                else
                    stepData.beneficiary = this;
            }
            else {
                stepData.beneficiary = this;
            }
        }
        return data;
    }
    function ensureAllowance(IERC20Token _token, address _spender, uint256 _value) private {
        uint256 allowance = _token.allowance(this, _spender);
        if (allowance < _value) {
            if (allowance > 0)
                safeApprove(_token, _spender, 0);
            safeApprove(_token, _spender, _value);
        }
    }
    function getConverterEtherTokenAddress(IConverter _converter) private view returns (address) {
        uint256 reserveCount = _converter.connectorTokenCount();
        for (uint256 i = 0; i < reserveCount; i++) {
            address reserveTokenAddress = _converter.connectorTokens(i);
            if (etherTokens[reserveTokenAddress])
                return reserveTokenAddress;
        }
        return ETH_RESERVE_ADDRESS;
    }
    bytes4 private constant GET_RETURN_FUNC_SELECTOR = bytes4(keccak256("getReturn(address,address,uint256)"));
    function getReturn(address _dest, address _sourceToken, address _targetToken, uint256 _amount) internal view returns (uint256, uint256) {
        uint256[2] memory ret;
        bytes memory data = abi.encodeWithSelector(GET_RETURN_FUNC_SELECTOR, _sourceToken, _targetToken, _amount);
        assembly {
            let success := staticcall(
                gas,           
                _dest,         
                add(data, 32), 
                mload(data),   
                ret,           
                64             
            )
            if iszero(success) {
                revert(0, 0)
            }
        }
        return (ret[0], ret[1]);
    }
    bytes4 private constant IS_V28_OR_HIGHER_FUNC_SELECTOR = bytes4(keccak256("isV28OrHigher()"));
    function isV28OrHigherConverter(IConverter _converter) internal view returns (bool) {
        bool success;
        uint256[1] memory ret;
        bytes memory data = abi.encodeWithSelector(IS_V28_OR_HIGHER_FUNC_SELECTOR);
        assembly {
            success := staticcall(
                gas,           
                _converter,    
                add(data, 32), 
                mload(data),   
                ret,           
                32             
            )
        }
        return success;
    }
    function getReturnByPath(IERC20Token[] _path, uint256 _amount) public view returns (uint256, uint256) {
        return (rateByPath(_path, _amount), 0);
    }
    function convert(IERC20Token[] _path, uint256 _amount, uint256 _minReturn) public payable returns (uint256) {
        return convertByPath(_path, _amount, _minReturn, address(0), address(0), 0);
    }
    function convert2(
        IERC20Token[] _path,
        uint256 _amount,
        uint256 _minReturn,
        address _affiliateAccount,
        uint256 _affiliateFee
    )
        public
        payable
        returns (uint256)
    {
        return convertByPath(_path, _amount, _minReturn, address(0), _affiliateAccount, _affiliateFee);
    }
    function convertFor(IERC20Token[] _path, uint256 _amount, uint256 _minReturn, address _beneficiary) public payable returns (uint256) {
        return convertByPath(_path, _amount, _minReturn, _beneficiary, address(0), 0);
    }
    function convertFor2(
        IERC20Token[] _path,
        uint256 _amount,
        uint256 _minReturn,
        address _beneficiary,
        address _affiliateAccount,
        uint256 _affiliateFee
    )
        public
        payable
        greaterThanZero(_minReturn)
        returns (uint256)
    {
        return convertByPath(_path, _amount, _minReturn, _beneficiary, _affiliateAccount, _affiliateFee);
    }
    function claimAndConvert(IERC20Token[] _path, uint256 _amount, uint256 _minReturn) public returns (uint256) {
        return convertByPath(_path, _amount, _minReturn, address(0), address(0), 0);
    }
    function claimAndConvert2(
        IERC20Token[] _path,
        uint256 _amount,
        uint256 _minReturn,
        address _affiliateAccount,
        uint256 _affiliateFee
    )
        public
        returns (uint256)
    {
        return convertByPath(_path, _amount, _minReturn, address(0), _affiliateAccount, _affiliateFee);
    }
    function claimAndConvertFor(IERC20Token[] _path, uint256 _amount, uint256 _minReturn, address _beneficiary) public returns (uint256) {
        return convertByPath(_path, _amount, _minReturn, _beneficiary, address(0), 0);
    }
    function claimAndConvertFor2(
        IERC20Token[] _path,
        uint256 _amount,
        uint256 _minReturn,
        address _beneficiary,
        address _affiliateAccount,
        uint256 _affiliateFee
    )
        public
        returns (uint256)
    {
        return convertByPath(_path, _amount, _minReturn, _beneficiary, _affiliateAccount, _affiliateFee);
    }
}