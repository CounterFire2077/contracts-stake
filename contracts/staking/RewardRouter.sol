// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IRewardTracker} from "./interfaces/IRewardTracker.sol";
import {IVester} from "./interfaces/IVester.sol";
import {Governable} from "../core/Governable.sol";

contract RewardRouter is ReentrancyGuard, Governable {
  using SafeERC20 for IERC20;

  address public cec;
  address public esCec;

  address public stakedCecTracker;
  address public cecVester;

  event StakeCec(address account, address token, uint256 amount);
  event UnstakeCec(address account, address token, uint256 amount);

  constructor(address _cec, address _esCec, address _stakedCecTracker, address _cecVester) {
    cec = _cec;
    esCec = _esCec;
    stakedCecTracker = _stakedCecTracker;
    cecVester = _cecVester;
  }

  // to help users who accidentally send their tokens to this contract
  function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
    IERC20(_token).safeTransfer(_account, _amount);
  }

  function batchStakeCecForAccount(
    address[] memory _accounts,
    uint256[] memory _amounts
  ) external nonReentrant onlyGov {
    address _cec = cec;
    for (uint256 i = 0; i < _accounts.length; i++) {
      _stakeCec(msg.sender, _accounts[i], _cec, _amounts[i]);
    }
  }

  function stakeCecForAccount(address _account, uint256 _amount) external nonReentrant onlyGov {
    _stakeCec(msg.sender, _account, cec, _amount);
  }

  function stakeCec(uint256 _amount) external nonReentrant {
    _stakeCec(msg.sender, msg.sender, cec, _amount);
  }

  function stakeEsCec(uint256 _amount) external nonReentrant {
    _stakeCec(msg.sender, msg.sender, esCec, _amount);
  }

  function unstakeCec(uint256 _amount) external nonReentrant {
    _unstakeCec(msg.sender, cec, _amount);
  }

  function unstakeEsCec(uint256 _amount) external nonReentrant {
    _unstakeCec(msg.sender, esCec, _amount);
  }

  function claim() external nonReentrant {
    address account = msg.sender;

    IRewardTracker(stakedCecTracker).claimForAccount(account, account);
  }

  function claimEsCec() external nonReentrant {
    address account = msg.sender;
    IRewardTracker(stakedCecTracker).claimForAccount(account, account);
  }

  function handleRewards(
    bool _shouldClaimCec,
    bool _shouldStakeCec,
    bool _shouldClaimEsCec,
    bool _shouldStakeEsCec
  ) external nonReentrant {
    address account = msg.sender;

    uint256 cecAmount = 0;
    if (_shouldClaimCec) {
      cecAmount = IVester(cecVester).claimForAccount(account, account);
    }

    if (_shouldStakeCec && cecAmount > 0) {
      _stakeCec(account, account, cec, cecAmount);
    }

    uint256 esCecAmount = 0;
    if (_shouldClaimEsCec) {
      esCecAmount = IRewardTracker(stakedCecTracker).claimForAccount(account, account);
    }

    if (_shouldStakeEsCec && esCecAmount > 0) {
      _stakeCec(account, account, esCec, esCecAmount);
    }
  }

  function _stakeCec(address _fundingAccount, address _account, address _token, uint256 _amount) private {
    require(_amount > 0, "invalid _amount");

    IRewardTracker(stakedCecTracker).stakeForAccount(_fundingAccount, _account, _token, _amount);

    emit StakeCec(_account, _token, _amount);
  }

  function _unstakeCec(address _account, address _token, uint256 _amount) private {
    require(_amount > 0, "invalid _amount");
    // uint256 balance = IRewardTracker(stakedCecTracker).stakedAmounts(_account);
    IRewardTracker(stakedCecTracker).unstakeForAccount(_account, _token, _amount, _account);

    emit UnstakeCec(_account, _token, _amount);
  }
}
