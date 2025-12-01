pragma solidity 0.8.3;
import "./Pool.sol";
import "./interfaces/iRESERVE.sol"; 
import "./interfaces/iPOOLFACTORY.sol";  
import "./interfaces/iWBNB.sol";
contract Router {
    address public BASE;
    address public WBNB;
    address public DEPLOYER;
    uint private maxTrades;         
    uint private eraLength;         
    uint public normalAverageFee;   
    uint private arrayFeeSize;      
    uint [] private feeArray;       
    uint private lastMonth;         
    mapping(address=> uint) public mapAddress_30DayDividends;
    mapping(address=> uint) public mapAddress_Past30DayPoolDividends;
    modifier onlyDAO() {
        require(msg.sender == _DAO().DAO() || msg.sender == DEPLOYER);
        _;
    }
    constructor (address _base, address _wbnb) {
        BASE = _base;
        WBNB = _wbnb;
        arrayFeeSize = 20;
        eraLength = 30;
        maxTrades = 100;
        lastMonth = 0;
        DEPLOYER = msg.sender;
    }
    receive() external payable {}
    function _DAO() internal view returns(iDAO) {
        return iBASE(BASE).DAO();
    }
    function addLiquidity(uint inputBase, uint inputToken, address token) external payable{
        addLiquidityForMember(inputBase, inputToken, token, msg.sender);
    }
    function addLiquidityForMember(uint inputBase, uint inputToken, address token, address member) public payable{
        address pool = iPOOLFACTORY(_DAO().POOLFACTORY()).getPool(token);  
        _handleTransferIn(BASE, inputBase, pool); 
        _handleTransferIn(token, inputToken, pool); 
        Pool(pool).addForMember(member); 
    }
    function zapLiquidity(uint unitsInput, address fromPool, address toPool) external {
        require(iPOOLFACTORY(_DAO().POOLFACTORY()).isPool(fromPool) == true); 
        require(iPOOLFACTORY(_DAO().POOLFACTORY()).isPool(toPool) == true); 
        address _fromToken = Pool(fromPool).TOKEN(); 
        address _member = msg.sender; 
        require(unitsInput <= iBEP20(fromPool).totalSupply()); 
        iBEP20(fromPool).transferFrom(_member, fromPool, unitsInput); 
        Pool(fromPool).remove(); 
        iBEP20(_fromToken).transfer(fromPool, iBEP20(_fromToken).balanceOf(address(this))); 
        Pool(fromPool).swapTo(BASE, toPool); 
        iBEP20(BASE).transfer(toPool, iBEP20(BASE).balanceOf(address(this))); 
        Pool(toPool).addForMember(_member); 
    }
    function addLiquiditySingle(uint inputToken, bool fromBase, address token) external payable{
        addLiquiditySingleForMember(inputToken, fromBase, token, msg.sender);
    }
    function addLiquiditySingleForMember(uint inputToken, bool fromBase, address token, address member) public payable{
        require(inputToken > 0); 
        address _pool = iPOOLFACTORY(_DAO().POOLFACTORY()).getPool(token); 
        address _token = token;
        if(token == address(0)){_token = WBNB;} 
        if(fromBase){
            _handleTransferIn(BASE, inputToken, _pool); 
            Pool(_pool).addForMember(member); 
        } else {
            _handleTransferIn(token, inputToken, _pool); 
            Pool(_pool).addForMember(member); 
        }
    }
    function removeLiquidity(uint basisPoints, address token) external{
        require((basisPoints > 0 && basisPoints <= 10000)); 
        uint _units = iUTILS(_DAO().UTILS()).calcPart(basisPoints, iBEP20(iPOOLFACTORY(_DAO().POOLFACTORY()).getPool(token)).balanceOf(msg.sender));
        removeLiquidityExact(_units, token);
    }
    function removeLiquidityExact(uint units, address token) public {
        address _pool = iPOOLFACTORY(_DAO().POOLFACTORY()).getPool(token); 
        address _member = msg.sender; 
        iBEP20(_pool).transferFrom(_member, _pool, units); 
        if(token != address(0)){
            Pool(_pool).removeForMember(_member); 
        } else {
            Pool(_pool).remove(); 
            uint outputBase = iBEP20(BASE).balanceOf(address(this)); 
            uint outputToken = iBEP20(WBNB).balanceOf(address(this)); 
            _handleTransferOut(token, outputToken, _member); 
            _handleTransferOut(BASE, outputBase, _member); 
        }
    }
    function removeLiquiditySingle(uint units, bool toBase, address token) external{
        address _pool = iPOOLFACTORY(_DAO().POOLFACTORY()).getPool(token); 
        require(iPOOLFACTORY(_DAO().POOLFACTORY()).isPool(_pool) == true); 
        address _member = msg.sender; 
        iBEP20(_pool).transferFrom(_member, _pool, units); 
        Pool(_pool).remove(); 
        address _token = token; 
        if(token == address(0)){_token = WBNB;} 
        if(toBase){
            iBEP20(_token).transfer(_pool, iBEP20(_token).balanceOf(address(this))); 
            Pool(_pool).swapTo(BASE, _member); 
        } else {
            iBEP20(BASE).transfer(_pool, iBEP20(BASE).balanceOf(address(this))); 
            Pool(_pool).swap(_token); 
            _handleTransferOut(token, iBEP20(_token).balanceOf(address(this)), _member); 
        } 
    }
    function buyTo(uint amount, address token, address member) public {
        address _pool = iPOOLFACTORY(_DAO().POOLFACTORY()).getPool(token); 
        _handleTransferIn(BASE, amount, _pool); 
        uint fee;
        if(token != address(0)){
            (, uint feey) = Pool(_pool).swapTo(token, member); 
            fee = feey;
        } else {
            (uint outputAmount, uint feez) = Pool(_pool).swap(WBNB); 
            _handleTransferOut(token, outputAmount, member); 
            fee = feez;
        }
        getsDividend(_pool, fee); 
    }
    function sellTo(uint amount, address token, address member) public payable returns (uint){
        address _pool = iPOOLFACTORY(_DAO().POOLFACTORY()).getPool(token); 
        _handleTransferIn(token, amount, _pool); 
        (, uint fee) = Pool(_pool).swapTo(BASE, member); 
        getsDividend(_pool, fee); 
        return fee;
    }
    function swap(uint256 inputAmount, address fromToken, address toToken) external payable{
        swapTo(inputAmount, fromToken, toToken, msg.sender);
    }
    function swapTo(uint256 inputAmount, address fromToken, address toToken, address member) public payable{
        require(fromToken != toToken); 
        if(fromToken == BASE){
            buyTo(inputAmount, toToken, member); 
        } else if(toToken == BASE) {
            sellTo(inputAmount, fromToken, member); 
        } else {
            address _poolTo = iPOOLFACTORY(_DAO().POOLFACTORY()).getPool(toToken); 
            uint feey = sellTo(inputAmount, fromToken, _poolTo); 
            address _toToken = toToken;
            if(toToken == address(0)){_toToken = WBNB;} 
            (uint _zz, uint _feez) = Pool(_poolTo).swap(_toToken); 
            uint fee = feey+(_feez); 
            getsDividend(_poolTo, fee); 
            _handleTransferOut(toToken, _zz, member); 
        }
    }
    function getsDividend(address _pool, uint fee) internal {
        if(iPOOLFACTORY(_DAO().POOLFACTORY()).isCuratedPool(_pool) == true){
            addTradeFee(fee); 
            addDividend(_pool, fee); 
        }
    }
    function _handleTransferIn(address _token, uint256 _amount, address _pool) internal returns(uint256 actual){
        if(_amount > 0) {
            if(_token == address(0)){
                require((_amount == msg.value));
                (bool success, ) = payable(WBNB).call{value: _amount}(""); 
                require(success, "!send");
                iBEP20(WBNB).transfer(_pool, _amount); 
                actual = _amount;
            } else {
                uint startBal = iBEP20(_token).balanceOf(_pool); 
                iBEP20(_token).transferFrom(msg.sender, _pool, _amount); 
                actual = iBEP20(_token).balanceOf(_pool)-(startBal); 
            }
        }
    }
    function _handleTransferOut(address _token, uint256 _amount, address _recipient) internal {
        if(_amount > 0) {
            if (_token == address(0)) {
                iWBNB(WBNB).withdraw(_amount); 
                (bool success, ) = payable(_recipient).call{value:_amount}("");  
                require(success, "!send");
            } else {
                iBEP20(_token).transfer(_recipient, _amount); 
            }
        }
    }
    function swapAssetToSynth(uint inputAmount, address fromToken, address toSynth) external payable {
        require(fromToken != toSynth); 
        address _synthLayer1 = iSYNTH(toSynth).LayerONE(); 
        address _pool = iPOOLFACTORY(_DAO().POOLFACTORY()).getPool(_synthLayer1); 
        if(fromToken != BASE){
            sellTo(inputAmount, fromToken, address(this)); 
            iBEP20(BASE).transfer(_pool, iBEP20(BASE).balanceOf(address(this))); 
        } else {
            iBEP20(BASE).transferFrom(msg.sender, _pool, inputAmount); 
        }
        (, uint fee) = Pool(_pool).mintSynth(toSynth, msg.sender); 
        getsDividend(_pool, fee); 
    }
    function swapSynthToAsset(uint inputAmount, address fromSynth, address toToken) external {
        require(fromSynth != toToken); 
        address _synthINLayer1 = iSYNTH(fromSynth).LayerONE(); 
        address _poolIN = iPOOLFACTORY(_DAO().POOLFACTORY()).getPool(_synthINLayer1); 
        address _pool = iPOOLFACTORY(_DAO().POOLFACTORY()).getPool(toToken); 
        iBEP20(fromSynth).transferFrom(msg.sender, _poolIN, inputAmount); 
        uint outputAmount; uint fee;
        if(toToken == BASE){
            Pool(_poolIN).burnSynth(fromSynth, msg.sender); 
        } else {
            (outputAmount,fee) = Pool(_poolIN).burnSynth(fromSynth, address(this)); 
            if(toToken != address(0)){
                (, uint feey) = Pool(_pool).swapTo(toToken, msg.sender); 
                fee = feey + fee;
            } else {
                (uint outputAmountY, uint feez) = Pool(_pool).swap(WBNB); 
                _handleTransferOut(toToken, outputAmountY, msg.sender); 
                fee = feez + fee;
            }
        }
        getsDividend(_pool, fee); 
    }
    function addDividend(address _pool, uint256 _fees) internal {
        if(!(normalAverageFee == 0)){
            uint reserve = iBEP20(BASE).balanceOf(_DAO().RESERVE()); 
            if(!(reserve == 0)){
                uint dailyAllocation = (reserve / eraLength) / maxTrades; 
                uint numerator = _fees * dailyAllocation;
                uint feeDividend = numerator / (_fees + normalAverageFee); 
                revenueDetails(feeDividend, _pool); 
                iRESERVE(_DAO().RESERVE()).grantFunds(feeDividend, _pool); 
                Pool(_pool).sync(); 
            }
        }
    }
    function addTradeFee(uint _fee) internal {
        uint totalTradeFees = 0;
        uint arrayFeeLength = feeArray.length;
        if(arrayFeeLength < arrayFeeSize){
            feeArray.push(_fee); 
        } else {
            addFee(_fee); 
            for(uint i = 0; i < arrayFeeSize; i++){
                totalTradeFees = totalTradeFees + feeArray[i]; 
            }
        }
        normalAverageFee = totalTradeFees / arrayFeeSize; 
    }
    function addFee(uint _fee) internal {
        uint n = feeArray.length; 
        for (uint i = n - 1; i > 0; i--) {
            feeArray[i] = feeArray[i - 1];
        }
        feeArray[0] = _fee;
    }
    function revenueDetails(uint _fees, address _pool) internal {
        if(lastMonth == 0){
            lastMonth = block.timestamp;
        }
        if(block.timestamp <= lastMonth + 2592000){ 
            mapAddress_30DayDividends[_pool] = mapAddress_30DayDividends[_pool] + _fees;
        } else {
            lastMonth = block.timestamp;
            mapAddress_Past30DayPoolDividends[_pool] = mapAddress_30DayDividends[_pool];
            mapAddress_30DayDividends[_pool] = 0;
            mapAddress_30DayDividends[_pool] = mapAddress_30DayDividends[_pool] + _fees;
        }
    }
    function stringToBytes(string memory s) external pure returns (bytes memory){
        return bytes(s);
    }
    function isEqual(bytes memory part1, bytes memory part2) external pure returns(bool equal){
        if(sha256(part1) == sha256(part2)){
            return true;
        }
    }
    function changeArrayFeeSize(uint _size) external onlyDAO {
        arrayFeeSize = _size;
        delete feeArray;
    }
    function changeMaxTrades(uint _maxtrades) external onlyDAO {
        maxTrades = _maxtrades;
    }
    function changeEraLength(uint _eraLength) external onlyDAO {	
        eraLength = _eraLength;	
    }
    function currentPoolRevenue(address pool) external view returns(uint256) {
        return mapAddress_30DayDividends[pool];
    }
    function pastPoolRevenue(address pool) external view returns(uint256) {
        return mapAddress_Past30DayPoolDividends[pool];
    }
}