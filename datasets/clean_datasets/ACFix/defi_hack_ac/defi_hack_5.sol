function burn(address account, uint256 _amount) public { 
        _transferFrom(account, DEAD, _amount);
        emit burnTokens(account, _amount);
    }