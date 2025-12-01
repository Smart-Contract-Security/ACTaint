function emergencyExit(address varg0) public payable {  //vulnerable point
    require(msg.data.length - 4 >= 32);
    require(msg.sender == _owner, 'Ownable: caller is not the owner');
    require((address(_hasInitialized >> 8)).code.size);
    v0, v1 = address(_hasInitialized >> 8).balanceOf(address(this)).gas(msg.gas);
    require(v0); // checks call status, propagates error data on error
    require(RETURNDATASIZE() >= 32);
    MEM[MEM[64]] = 68;
    if (this.balance >= 0) {
        if ((address(_hasInitialized >> 8)).code.size) {
            v2 = v3 = MEM[64];
            v4 = v5 = MEM[MEM[64]];
            v6 = v7 = 32 + MEM[64];
            while (v4 >= 32) {
                MEM[v2] = MEM[v6];
                v4 = v4 + ~31;
                v2 += 32;
                v6 += 32;
            }
            MEM[v2] = MEM[v6] & ~(256 ** (32 - v4) - 1) | MEM[v2] & 256 ** (32 - v4) - 1;
            v8, v9, v10, v11 = address(_hasInitialized >> 8).transfer(varg0, v1).gas(msg.gas);
            if (RETURNDATASIZE() == 0) {
                v12 = v13 = 96;
            } else {
                v12 = v14 = new bytes[](RETURNDATASIZE());
                RETURNDATACOPY(v14.data, 0, RETURNDATASIZE());
            }
            if (!v8) {
                require(!MEM[v12], v11, MEM[v12]);
                v15 = new array[](v16.length);
                v17 = v18 = 0;
                while (v17 < v16.length) {
                    MEM[v17 + v15.data] = MEM[v17 + v16.data];
                    v17 += 32;
                }
                v19 = v20 = v16.length + v15.data;
                if (0) {
                    MEM[v20 - 0] = ~0x0 & MEM[v20 - 0];
                }
                revert(v15, v21, 'SafeERC20: low-level call failed');
            } else {
                if (MEM[v12]) {
                    require(MEM[v12] >= 32);
                    require(MEM[32 + v12], 'SafeERC20: ERC20 operation did not succeed');
                }
                exit;
            }
        } else {
            MEM[MEM[64] + 4] = 32;
            revert('Address: call to non-contract');
        }
    } else {
        MEM[4 + MEM[64]] = 32;
        revert('Address: insufficient balance for call');
    }
}