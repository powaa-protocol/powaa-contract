# POWAA PROTOCOL
<p align="center">
  <img style="width: 60%" src="https://github.com/powaa-protocol/powaa-contract/blob/doc/readme/assets/meme_01.png?raw=true" alt="meme_01" border="0" />
</p>

Our protocol built specifically to help retails traders make the most out of the upcoming Ethereum Merge towards PoS. Users can deposit their assets into the Powaa deposit vaults and once the Merge is complete, Powaa Protocol will swap all the obsolete assets on PoW Ethereum for ETHW and re-distribute them back to the depositors.



## Overview

---

<p align="center">
  <img style="width: 90%" src="https://github.com/powaa-protocol/powaa-contract/blob/doc/readme/assets/usecase.png?raw=true" alt="usecase" border="0" />
</p>

You can participate in our protocol as 

### 1. Depositor

- Alice, one of the depositor, can deposit their tokens (in the form of single asset e.g. USDC, DAI or LP token from DEXes like Curve or SushiSwap) to the deposit vaults, which they will earn POWAA token in return while waiting for The Merge to come.
- After The Merge, Alice can withdraw their deposited tokens from our token vault without any fee on PoS chain. Also they can withdraw ETHW from the token vault on the PoW chain as well. Free Money!
  
<p align="center">
  <img style="width: 40%" src="https://github.com/powaa-protocol/powaa-contract/blob/doc/readme/assets/meme_02.png?raw=true" alt="meme_02" border="0" />
</p>

### 2. Liquidity Provider

- Bob, one of the liquidity providers, can provide liquidity to the POWAA-ETH liquidity pool in Uniswap v2 and stake the LP token to earn even more POWAA token. To provide liquidity, Bob can either acquire POWAA from depositing eligible assets into the vaults or buy some directly from Uniswap liquidity pool.
- After The Merge, Bob can withdraw ETHW on PoW chain as well as ETH on the PoS chain. Note that on PoS, right after the merge, Powaa Protocol will remove liquidity on behalf of the liquidity providers to prevent liquidity providers from being dumped on. As on the PoW chain, Bob will also get two portions on ETHW. The first portion comes from a portion of all of the acquired ETHW distributed back to the liquidity providers by Powaa protocol. The other portion comes from the remaining ETHW rewards in the POWAA-ETH liquidity pool on PoW chain.

<p align="center">
  <img style="width: 60%" src="https://github.com/powaa-protocol/powaa-contract/blob/doc/readme/assets/meme_03.png?raw=true" alt="meme_03" border="0" />
</p>

## Contracts

---
### POWAA
- A simple ERC-20 token which will be used as the protocol's utility token.

### TokenVault

- A simple token vault which users can deposit their assets into. The vault also has a migrate function, which will be triggered by controller contract.

### Controller

- The controller contract acts as the migration facade, which will trigger all vault migration process.

### Migrators

- The migration strategy contract for each vaults
  - Token Vaults: The migration strategy, focusing on swapping tokens into ETH on Uniswap v3. The strategy works **ONLY** on the PoW chain.
  - LP Vaults: The migration strategy, focusing on breaking down the LP token and swapping into ETH on Uniswap v2. The strategy works **BOTH** on the PoW and PoS chain in order to protect our liquidity provider's ETH.

### Fee Models
- The withdrawal fee model: The withdrawal fee should increase as we appreoach the Merge. Once the Merge is complete and all the rewards have been distributed, the withdrawal fees will no longer be charged and users can freely withdraw their assets without any penalty.