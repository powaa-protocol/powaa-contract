# POWAA PROTOCOL
<p align="center">
  <img style="width: 60%" src="https://github.com/powaa-protocol/powaa-contract/blob/doc/readme/assets/usecase.png?raw=true" alt="meme_01" border="0" />
</p>

Our protocol built specifically to help retails traders make the most out of the upcomming Ethereum Merge towards PoS. We together fight the gas war to get most of the ETHW out from the dying alt tokens.



## Overview

---

<p align="center">
  <img style="width: 60%" src="https://github.com/powaa-protocol/powaa-contract/blob/doc/readme/assets/usecase.png?raw=true" alt="usecase" border="0" />
</p>

You can participate in our protocol as 

### 1. Depositor

- Alice, one of the depositor, can deposit their tokens (e.g. USDC, DAI) to the deposit vaults, which they will earn POWAA token in return while waiting for The Merge to come.
- After The Merge, Alice can withdraw their deposited tokens from our token vault without any fee on PoS chain. Also they can withdraw ETHW from the token vault on the PoW chain as well. Free Money!
  
<p align="center">
  <img style="width: 60%" src="https://github.com/powaa-protocol/powaa-contract/blob/doc/readme/assets/usecase.png?raw=true" alt="meme_02" border="0" />
</p>

### 2. Liquidity Provider

- Bob, one of the liquidity provider, can provide liquidity to the POWAA-ETH liquidity pool in Uniswap v2 and stake the LP token to earn even more POWAA token. To provide liquidity, Bob can either earn POWAA from participate in our deposit vaults or buy some from Uniswap.
- After The Merge, Bob can withdraw ETHW on PoW chain as well as ETH on the PoS chain. However, on the PoW chain, Bob also get an extra ETHW from a portion of protocol's operation fee.

<p align="center">
  <img style="width: 60%" src="https://github.com/powaa-protocol/powaa-contract/blob/doc/readme/assets/usecase.png?raw=true" alt="meme_03" border="0" />
</p>

## Contracts

---
### POWAA
- A simple ERC-20 token which will be used as the protocol's utility token.

### TokenVault

- A simple token vault which users can deposit their token into. It also has a migrate function which will be triggered by controller contract.

### Controller

- The controller contract acts as the migration facade which will trigger all vault migration process.

### Migrators

- The migration strategy contract for each vaults
  - Token Vaults: The migration strategy, focusing on swapping tokens into ETH on Uniswap v3. The strategy works **ONLY** on the PoW chain.
  - LP Vaults: The migration strategy, focusing on breaking down the LP token and swapping into ETH on Uniswap v2. The strategy works **BOTH** on the PoW and PoS chain in order to protect our liquidity provider's ETH.

### Fee Models
- The withdrawal fee model. The withdrawal fee should increase as The Merge is getting closer but should become zero after The Merge.