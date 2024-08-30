// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IRewardRouter {
  function feeGlpTracker() external view returns (address);
  function stakedGlpTracker() external view returns (address);
}
