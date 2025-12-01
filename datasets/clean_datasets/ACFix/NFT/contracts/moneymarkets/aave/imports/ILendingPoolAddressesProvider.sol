pragma solidity 0.5.17;
interface ILendingPoolAddressesProvider {
  function getLendingPool() external view returns (address);
}