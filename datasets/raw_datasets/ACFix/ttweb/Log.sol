function Log(
    address _contract,
    address _caller,
    string memory _logName,
    bytes memory _data
) public {
    emit LogEvent(_contract, _caller, _logName, _data);
}