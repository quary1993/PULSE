#Pulse Implementation

The Client solicited a token contract/s governing the mechanism of a token named PULSE. The token functionalities will be handled by two smart contracts:
1. Pulse Token Contract
2. Pulse Manager Contract
Pulse Token contract will extend the ERC20 standard functions and will also have additional functionalities.
Pulse Manager Contract will handle extra functionalities of the token, such as scheduled minting, public sale, transfer functionalities and reserve handling,etc...

#Owner vesting

The total supply of PULSE will be 1.000.000.000.
The smart Pulse Manager contract will allow minting the tokens by the owner in the following way:
a). 50% - At any time needed.
b). 10% - will be minted for public sale. Public sale is conducted directly in the contract c). 5% after 6 months (meant for team members)
d). 10% after 12 months (5% meant for team members, 5% meant for investors)
e). 10% after 18 months (5% meant for team members, 5% meant for investors)
f). 15% after 24 months (6.5% meant for team members, 8.5% meant for investors)

#Public Sale

The public sale will be conducted the “Pulse Manager” contract. The owner can initiate the public sale (unpause/pause it). The public sale will automatically pause when 10% of the maximum supply will be distributed through it. The owner will be able to change the price of the token sale at any time before or during the public sale. Anyone will be able to participate in the public sale.
The public sale participants will have their bought PULSE subject to a vesting mechanism. They will pay the bnb and receive pulse from the Pulse Manager Contract.
The Pulse contract will have a variable that prevents any other transfer, except the public sale minting, until the owner calls a function and allows for the transfers to commence. This is not a reversible operation, and once commenced, the owner will not be able to stop the transfers again.

#Transfer function

The Pulse contract will not be a standard ERC20 token (although it will be subject to almost the same ABI), as the basic functionalities will have to be modified to allow for reflection (a
 system through which tokens can be distributed to all token holders, which implies inherently different transfer function and balanceOf function).
During each transfer, a commission of 10% will be imposed by the token contract. The contract suite will implement the following functionalities for distributing the 10%:

# 1. Revive basket (5%)
The owner will be able to define an arbitrary number of tokens, each with a corresponding weight. Each time a transfer is done, the 5% commission that is meant for the Revive basket will be used to buy these tokens from Pancake Swap according to their corresponding weight. After the contract suite buys the revive basket tokens, it will hold the resulting LP.
A function will be implemented, and callable by the owner, which will redeem a specific LP, sell the obtained tokens for BNB, then use the BNB to acquire PULSE from Pancake Swap and distribute the resulting PULSE to all the PULSE holders proportional to their holdings.

# 2. Revive launchdome (2%)
There will be a revive launchdome wallet, changeable by the owner, which will receive 2% of the transferred token

# 3. Pancake Swap Liquidity (2%)
2% of the transferred amount will be used to add liquidity to the BNB <> PULSE pair in pancake swap. In this process, the contract suite will buy the proper amount of BNB (~equiv. with 1% of the transaction amount) and place them as liquidity in the Pancake Swap Pair, together with the remaining amount of the allocated 2%. The resulting LP will be held by the contract suite.
We will add a function which redeems the liquidity, sells the BNB for Pulse and burns the resulting pulse.

# 4. Distribution (1%)
1% will be distributed between all the token holders.

# Token distribution and reflection

When distributing amounts of PULSE to all the holders, the Pulse contract will use a mechanism called reflection. For reflection to be implemented, the transfer and the balanceOf functions will be different from the usual erc20 transfer and balanceOf functions. Additionally, the contracts will have different parameters and mechanism which will allow reflection to take place.

The contracts will also have a separate function through which any address can provide and distribute its tokens to every PULSE holder. <deliver>
