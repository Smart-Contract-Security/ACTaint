pragma solidity ^0.8.9;
library StateMachines {
    type Machine is uint256;
    Machine internal constant EMPTY_MACHINE = Machine.wrap(0);
    enum State {
        _00, _01, _02, _03, 
        _04, _05, _06, _07, 
        _08, _09, _10, _11, 
        _12, _13, _14, _15
    }
    function statesToEdge(State fromState, State toState) internal pure returns (uint256) {
        return 1 << (uint8(toState) * 16 + uint8(fromState));
    }
    function isTransitionValid(Machine self, State fromState, State toState) internal pure returns (bool) {
        return Machine.unwrap(self) & statesToEdge(fromState, toState) != 0;
    }
    function addEdgeTransition(Machine self, State fromState, State toState) internal pure returns (Machine newMachine) {
        return Machine.wrap(Machine.unwrap(self) | statesToEdge(fromState, toState));
    }
    function removeEdgeTransition(Machine self, State fromState, State toState) internal pure returns (Machine newMachine) {
        return Machine.wrap(Machine.unwrap(self) & ~statesToEdge(fromState, toState));
    }
}
abstract contract StateMachineController {
    using StateMachines for StateMachines.Machine;
    event StateTransition(uint256 indexed machineId, StateMachines.State indexed fromState, StateMachines.State indexed toState);
    error InvalidState(StateMachines.State state);
    error InvalidStateTransition(StateMachines.State fromState, StateMachines.State toState);
    mapping(uint256 => StateMachines.State) private _machines;
    modifier onlyInState(uint256 _machineId, StateMachines.State _state) {
        if (_state != _machines[_machineId]) revert InvalidState(_state);
        _;
    }
    function transitionTable() virtual public view returns(StateMachines.Machine);
    function _transition(uint256 _machineId, StateMachines.State _newState) internal {
        if (!transitionTable().isTransitionValid(_machines[_machineId], _newState)) revert InvalidStateTransition(_machines[_machineId], _newState);
        emit StateTransition(_machineId, _machines[_machineId], _newState);
        _machines[_machineId] = _newState;
    }
    function currentState(uint256 _machineId) public view returns (StateMachines.State) {
        return _machines[_machineId];
    }
}