
## Contracts for Staking

### tokens/erc20/EsToken.sol

Escrowed CEC(esCEC) token contract. This contract is a ERC20 token contract with additional functionality, with `inPrivateTransferMode = true` the token can only be transferred by the address with `isHandler = true`. This is used to prevent the token from being transferred while the token is in escrow. 

Escrowed CEC(esCEC) tokens can be converted into CEC tokens through vesting.

There are two ways to earn esCEC tokens:

1. staking CEC tokens; 
2. staking esCEC tokens;


### staking/RewardRouter.sol

Main contract for staking. This contract is used to stake CEC tokens and esCEC tokens. The contract will distribute rewards to the stakers based on the amount of tokens staked and the duration of the stake.

Each staked Escrowed CEC token will earn the same amount of Escrowed CEC as a regular CEC token.

After staking, the staker will receive esCEC tokens every second, the staker can claim the rewards at any time.

The staker can unstake the tokens at any time. The staker will receive the staked tokens and the rewards.

### staking/RewardTracker.sol

Actuary contract for staking. This contract is used to calculate the rewards for the stakers. The contract will calculate the rewards based on the amount of tokens staked and the duration of the stake.

### staking/RewardDistributor.sol

Distributor contract for staking. This contract is used to distribute the rewards to the stakers. The contract will distribute the rewards based on the amount of tokens staked and the duration of the stake.

### staking/Vester.sol

With this contract, the stakers can convert their esCEC tokens into CEC tokens. 

esCEC tokens that have been unstaked and deposited for vesting will not earn rewards. Staked tokens that are reserved for vesting will continue to earn rewards.

After initiating vesting, ths esCEC tokens will be converted into CEC every second and will fully vest over `365 days` (based on the `vestingDuration` variable). esCEC tokens that have been converted into CEC are claimable at anytime.

With `needCheckStake` set to `true`, the contract will check if the staker has enough staked CEC tokens before initiating vesting. 

Depositing into the vesting vault while existing vesting is ongoing is supported.

Tokens that are reserved for vesting cannot be unstaked or sold. To unreserve the tokens, use the "withdraw" method. Partial withdrawals are not supported, so withdrawing will withdraw and unreserve all tokens as well as pause vesting. Upon withdrawal, esCEC tokens that had been vested into CEC will remain as CEC tokens.