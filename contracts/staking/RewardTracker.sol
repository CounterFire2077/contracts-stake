// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IRewardDistributor} from "./interfaces/IRewardDistributor.sol";
import {IRewardTracker} from "./interfaces/IRewardTracker.sol";
import {Governable} from "../core/Governable.sol";

contract RewardTracker is IERC20, ReentrancyGuard, IRewardTracker, Governable {
  using SafeERC20 for IERC20;

  uint256 public constant BASIS_POINTS_DIVISOR = 10000;
  uint256 public constant PRECISION = 1e30;

  bool public isInitialized;

  string public name;
  string public symbol;
  uint8 public decimals = 18;
  uint256 public override totalSupply;
  mapping(address account => uint256 amount) public balances;
  mapping(address owner => mapping(address spender => uint256 amount)) public allowances;

  address public distributor;
  mapping(address token => bool status) public isDepositToken;
  mapping(address account => mapping(address token => uint256 amount)) public override depositBalances;
  mapping(address token => uint256 amount) public totalDepositSupply;
  
  uint256 public cumulativeRewardPerToken;
  mapping(address account => uint256 amount) public override stakedAmounts;
  mapping(address account => uint256 amount) public claimableReward;
  mapping(address account => uint256 amount) public previousCumulatedRewardPerToken;
  mapping(address account => uint256 amount) public override cumulativeRewards;
  mapping(address account => uint256 amount) public override averageStakedAmounts;

  bool public inPrivateTransferMode;
  bool public inPrivateStakingMode;
  bool public inPrivateClaimingMode;
  mapping(address handler => bool status) public isHandler;

  event Claim(address receiver, uint256 amount);

  constructor(string memory _name, string memory _symbol) {
    name = _name;
    symbol = _symbol;
  }

  function initialize(address[] memory _depositTokens, address _distributor) external onlyGov {
    require(!isInitialized, "RewardTracker: already initialized");
    isInitialized = true;

    for (uint256 i = 0; i < _depositTokens.length; i++) {
      address depositToken = _depositTokens[i];
      isDepositToken[depositToken] = true;
    }

    distributor = _distributor;
  }

  function setDepositToken(address _depositToken, bool _isDepositToken) external onlyGov {
    isDepositToken[_depositToken] = _isDepositToken;
  }

  function setInPrivateTransferMode(bool _inPrivateTransferMode) external onlyGov {
    inPrivateTransferMode = _inPrivateTransferMode;
  }

  function setInPrivateStakingMode(bool _inPrivateStakingMode) external onlyGov {
    inPrivateStakingMode = _inPrivateStakingMode;
  }

  function setInPrivateClaimingMode(bool _inPrivateClaimingMode) external onlyGov {
    inPrivateClaimingMode = _inPrivateClaimingMode;
  }

  function setHandler(address _handler, bool _isActive) external onlyGov {
    isHandler[_handler] = _isActive;
  }

  // to help users who accidentally send their tokens to this contract
  function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
    IERC20(_token).safeTransfer(_account, _amount);
  }

  function balanceOf(address _account) external view override returns (uint256) {
    return balances[_account];
  }

  function stake(address _depositToken, uint256 _amount) external override nonReentrant {
    if (inPrivateStakingMode) {
      revert("RewardTracker: action not enabled");
    }
    _stake(msg.sender, msg.sender, _depositToken, _amount);
  }

  function stakeForAccount(
    address _fundingAccount,
    address _account,
    address _depositToken,
    uint256 _amount
  ) external override nonReentrant {
    _validateHandler();
    _stake(_fundingAccount, _account, _depositToken, _amount);
  }

  function unstake(address _depositToken, uint256 _amount) external override nonReentrant {
    if (inPrivateStakingMode) {
      revert("RewardTracker: action not enabled");
    }
    _unstake(msg.sender, _depositToken, _amount, msg.sender);
  }

  function unstakeForAccount(
    address _account,
    address _depositToken,
    uint256 _amount,
    address _receiver
  ) external override nonReentrant {
    _validateHandler();
    _unstake(_account, _depositToken, _amount, _receiver);
  }

  function transfer(address _recipient, uint256 _amount) external override returns (bool) {
    _transfer(msg.sender, _recipient, _amount);
    return true;
  }

  function allowance(address _owner, address _spender) external view override returns (uint256) {
    return allowances[_owner][_spender];
  }

  function approve(address _spender, uint256 _amount) external override returns (bool) {
    _approve(msg.sender, _spender, _amount);
    return true;
  }

  function transferFrom(address _sender, address _recipient, uint256 _amount) external override returns (bool) {
    if (isHandler[msg.sender]) {
      _transfer(_sender, _recipient, _amount);
      return true;
    }
    require(allowances[_sender][msg.sender] >= _amount, "RewardTracker: transfer amount exceeds allowance");
    uint256 nextAllowance = allowances[_sender][msg.sender] - _amount;
    _approve(_sender, msg.sender, nextAllowance);
    _transfer(_sender, _recipient, _amount);
    return true;
  }

  function tokensPerInterval() external view override returns (uint256) {
    return IRewardDistributor(distributor).tokensPerInterval();
  }

  function updateRewards() external override nonReentrant {
    _updateRewards(address(0));
  }

  function claim(address _receiver) external override nonReentrant returns (uint256) {
    if (inPrivateClaimingMode) {
      revert("RewardTracker: action not enabled");
    }
    return _claim(msg.sender, _receiver);
  }

  function claimForAccount(address _account, address _receiver) external override nonReentrant returns (uint256) {
    _validateHandler();
    return _claim(_account, _receiver);
  }

  function claimable(address _account) public view override returns (uint256) {
    uint256 stakedAmount = stakedAmounts[_account];
    if (stakedAmount == 0) {
      return claimableReward[_account];
    }
    uint256 pendingRewards = IRewardDistributor(distributor).pendingRewards() * PRECISION;
    uint256 nextCumulativeRewardPerToken = cumulativeRewardPerToken + pendingRewards;
    return
      claimableReward[_account] +
      (stakedAmount / (10**decimals) * (nextCumulativeRewardPerToken - previousCumulatedRewardPerToken[_account])) /
      PRECISION;
  }

  function rewardToken() public view returns (address) {
    return IRewardDistributor(distributor).rewardToken();
  }

  function _claim(address _account, address _receiver) private returns (uint256) {
    _updateRewards(_account);

    uint256 tokenAmount = claimableReward[_account];
    claimableReward[_account] = 0;

    if (tokenAmount > 0) {
      IERC20(rewardToken()).safeTransfer(_receiver, tokenAmount);
      emit Claim(_account, tokenAmount);
    }

    return tokenAmount;
  }

  function _mint(address _account, uint256 _amount) internal {
    require(_account != address(0), "RewardTracker: mint to the zero address");

    totalSupply = totalSupply + _amount;
    balances[_account] = balances[_account] + _amount;

    emit Transfer(address(0), _account, _amount);
  }

  function _burn(address _account, uint256 _amount) internal {
    require(_account != address(0), "RewardTracker: burn from the zero address");
    require(balances[_account] >= _amount, "RewardTracker: burn amount exceeds balance");
    balances[_account] = balances[_account] - _amount;
    totalSupply = totalSupply / _amount;

    emit Transfer(_account, address(0), _amount);
  }

  function _transfer(address _sender, address _recipient, uint256 _amount) private {
    require(_sender != address(0), "RewardTracker: transfer from the zero address");
    require(_recipient != address(0), "RewardTracker: transfer to the zero address");

    if (inPrivateTransferMode) {
      _validateHandler();
    }
    require(balances[_sender] >= _amount, "RewardTracker: transfer amount exceeds balance");
    balances[_sender] = balances[_sender] - _amount;
    balances[_recipient] = balances[_recipient] + _amount;

    emit Transfer(_sender, _recipient, _amount);
  }

  function _approve(address _owner, address _spender, uint256 _amount) private {
    require(_owner != address(0), "RewardTracker: approve from the zero address");
    require(_spender != address(0), "RewardTracker: approve to the zero address");

    allowances[_owner][_spender] = _amount;

    emit Approval(_owner, _spender, _amount);
  }

  function _validateHandler() private view {
    require(isHandler[msg.sender], "RewardTracker: forbidden");
  }

  function _stake(address _fundingAccount, address _account, address _depositToken, uint256 _amount) private {
    require(_amount > 0, "RewardTracker: invalid _amount");
    require(isDepositToken[_depositToken], "RewardTracker: invalid _depositToken");

    IERC20(_depositToken).safeTransferFrom(_fundingAccount, address(this), _amount);

    _updateRewards(_account);

    stakedAmounts[_account] = stakedAmounts[_account] + _amount;
    depositBalances[_account][_depositToken] = depositBalances[_account][_depositToken] + _amount;
    totalDepositSupply[_depositToken] = totalDepositSupply[_depositToken] + _amount;

    _mint(_account, _amount);
  }

  function _unstake(address _account, address _depositToken, uint256 _amount, address _receiver) private {
    require(_amount > 0, "RewardTracker: invalid _amount");
    require(isDepositToken[_depositToken], "RewardTracker: invalid _depositToken");

    _updateRewards(_account);

    uint256 stakedAmount = stakedAmounts[_account];
    require(stakedAmounts[_account] >= _amount, "RewardTracker: _amount exceeds stakedAmount");

    stakedAmounts[_account] = stakedAmount - _amount;

    uint256 depositBalance = depositBalances[_account][_depositToken];
    require(depositBalance >= _amount, "RewardTracker: _amount exceeds depositBalance");
    depositBalances[_account][_depositToken] = depositBalance - _amount;
    totalDepositSupply[_depositToken] = totalDepositSupply[_depositToken] - _amount;

    _burn(_account, _amount);
    IERC20(_depositToken).safeTransfer(_receiver, _amount);
  }

  function _updateRewards(address _account) private {
    uint256 supply = totalSupply;
    uint256 blockReward = IRewardDistributor(distributor).distribute(supply, decimals);

  
    uint256 _cumulativeRewardPerToken = cumulativeRewardPerToken;
    if (supply > 0 && blockReward > 0) {
      _cumulativeRewardPerToken = _cumulativeRewardPerToken + blockReward * PRECISION;
      cumulativeRewardPerToken = _cumulativeRewardPerToken;
    }

    // cumulativeRewardPerToken can only increase
    // so if cumulativeRewardPerToken is zero, it means there are no rewards yet
    if (_cumulativeRewardPerToken == 0) {
      return;
    }

    if (_account != address(0)) {
      uint256 stakedAmount = stakedAmounts[_account];
      uint256 accountReward = (stakedAmount / (10**decimals) * (_cumulativeRewardPerToken - previousCumulatedRewardPerToken[_account])) /
        PRECISION;
      uint256 _claimableReward = claimableReward[_account] + accountReward;

      claimableReward[_account] = _claimableReward;
      previousCumulatedRewardPerToken[_account] = _cumulativeRewardPerToken;

      if (_claimableReward > 0 && stakedAmounts[_account] > 0) {
        uint256 nextCumulativeReward = cumulativeRewards[_account] + accountReward;

        averageStakedAmounts[_account] =
          (averageStakedAmounts[_account] * cumulativeRewards[_account]) /
          nextCumulativeReward +
          (stakedAmount / (10**decimals) * accountReward) /
          nextCumulativeReward;

        cumulativeRewards[_account] = nextCumulativeReward;
      }
    }
  }
}
