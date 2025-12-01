modifier isSigned(
        string memory _txHash,
        uint256 _amount,
        bytes32[] memory _r,
        bytes32[] memory _s,
        uint8[] memory _v
    ) {
        require(checkSignParams(_r, _s, _v), "bad-sign-params");
        bytes32 _hash = keccak256(abi.encodePacked(bsc, msg.sender, _txHash, _amount));
        address[] memory _signers = new address[](_r.length); 
        for (uint8 i = 0; i < _r.length; i++) {
            _signers[i] = ecrecover(_hash, _v[i], _r[i], _s[i]);
        }
        require(isSigners(_signers), "bad-signers");
        _;
    }
    function isSigners(address[] memory _signers) public view returns (bool){
        for (uint8 i = 0; i < _signers.length; i++) {  
            if (!_containsSigner(_signers[i])) {
                return false;
            }
        }
        return true;  
    }
function mint(
        uint256 _amount,
        string memory _txHash,
        address _receiver,
        bytes32[] memory _r,
        bytes32[] memory _s,
        uint8[] memory _v
    ) isSigned(_txHash, _amount, _r, _s, _v) external returns (bool){ 
        require(!txHashes[_txHash], "tx-hash-used");
        txHashes[_txHash] = true;
        _mint(_receiver, _amount);
        return true;
    }