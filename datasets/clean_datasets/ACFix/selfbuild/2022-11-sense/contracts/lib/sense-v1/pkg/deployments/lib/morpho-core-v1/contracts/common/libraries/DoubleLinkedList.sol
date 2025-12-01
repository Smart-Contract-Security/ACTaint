pragma solidity ^0.8.0;
library DoubleLinkedList {
    struct Account {
        address prev;
        address next;
        uint256 value;
    }
    struct List {
        mapping(address => Account) accounts;
        address head;
        address tail;
    }
    error AccountAlreadyInserted();
    error AccountDoesNotExist();
    error AddressIsZero();
    error ValueIsZero();
    function getValueOf(List storage _list, address _id) internal view returns (uint256) {
        return _list.accounts[_id].value;
    }
    function getHead(List storage _list) internal view returns (address) {
        return _list.head;
    }
    function getTail(List storage _list) internal view returns (address) {
        return _list.tail;
    }
    function getNext(List storage _list, address _id) internal view returns (address) {
        return _list.accounts[_id].next;
    }
    function getPrev(List storage _list, address _id) internal view returns (address) {
        return _list.accounts[_id].prev;
    }
    function remove(List storage _list, address _id) internal {
        if (_list.accounts[_id].value == 0) revert AccountDoesNotExist();
        Account memory account = _list.accounts[_id];
        if (account.prev != address(0)) _list.accounts[account.prev].next = account.next;
        else _list.head = account.next;
        if (account.next != address(0)) _list.accounts[account.next].prev = account.prev;
        else _list.tail = account.prev;
        delete _list.accounts[_id];
    }
    function insertSorted(
        List storage _list,
        address _id,
        uint256 _value,
        uint256 _maxIterations
    ) internal {
        if (_value == 0) revert ValueIsZero();
        if (_id == address(0)) revert AddressIsZero();
        if (_list.accounts[_id].value != 0) revert AccountAlreadyInserted();
        uint256 numberOfIterations;
        address next = _list.head; 
        while (
            numberOfIterations < _maxIterations &&
            next != _list.tail &&
            _list.accounts[next].value >= _value
        ) {
            next = _list.accounts[next].next;
            unchecked {
                ++numberOfIterations;
            }
        }
        if (next != address(0) && _list.accounts[next].value < _value) {
            if (next == _list.head) {
                _list.accounts[_id] = Account(address(0), next, _value);
                _list.head = _id;
                _list.accounts[next].prev = _id;
            }
            else {
                _list.accounts[_id] = Account(_list.accounts[next].prev, next, _value);
                _list.accounts[_list.accounts[next].prev].next = _id;
                _list.accounts[next].prev = _id;
            }
        }
        else {
            if (_list.head == address(0)) {
                _list.accounts[_id] = Account(address(0), address(0), _value);
                _list.head = _id;
                _list.tail = _id;
            }
            else {
                _list.accounts[_id] = Account(_list.tail, address(0), _value);
                _list.accounts[_list.tail].next = _id;
                _list.tail = _id;
            }
        }
    }
}