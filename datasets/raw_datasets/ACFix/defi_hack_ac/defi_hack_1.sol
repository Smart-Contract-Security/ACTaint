function setToken(address _addr) public {
    //vulnerable point**
        configuration.stakingToken = ERC20(_addr);
        configuration.rewardsToken = ERC20(_addr);
    }
