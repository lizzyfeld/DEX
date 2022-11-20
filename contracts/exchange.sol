// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./token.sol";
import "hardhat/console.sol";

contract TokenExchange is Ownable {
    string public exchange_name = "";

    address tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3; // TODO: paste token contract address here 0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0
    Token public token = Token(tokenAddr);

    // Liquidity pool for the exchange
    uint private token_reserves = 0;
    uint private eth_reserves = 0;

    // map address of liquidity providers to their proportions
    mapping(address => uint) private lps;

    // Needed for looping through the keys of the lps mapping
    address[] private lp_providers;
    // map address of liquidity providers to their numerators
    mapping(address => uint) private lp_numerators;

    // constant denominator for our liquidity proportions in lps
    uint private denominator = 10000;

    // liquidity rewards
    uint private swap_fee_numerator = 0; // TODO Part 5: Set liquidity providers' returns.
    uint private swap_fee_denominator = 0;

    // Constant: x * y = k
    uint private k;

    constructor() {}

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens) external payable onlyOwner {
        // This function is already implemented for you; no changes needed.

        // require pool does not yet exist:
        require(token_reserves == 0, "Token reserves was not 0");
        require(eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require(msg.value > 0, "Need eth to create pool.");
        uint tokenSupply = token.balanceOf(msg.sender);
        require(
            amountTokens <= tokenSupply,
            "Not have enough tokens to create the pool"
        );
        require(amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token.balanceOf(address(this));
        eth_reserves = msg.value;
        k = token_reserves * eth_reserves;
    }

    // Function removeLP: removes a liquidity provider from the list.
    // This function also removes the gap left over from simply running "delete".
    function removeLP(uint index) private {
        require(
            index < lp_providers.length,
            "specified index is larger than the number of lps"
        );
        lp_providers[index] = lp_providers[lp_providers.length - 1];
        lp_providers.pop();
    }

    // Function getSwapFee: Returns the current swap fee ratio to the client.
    function getSwapFee() public view returns (uint, uint) {
        return (swap_fee_numerator, swap_fee_denominator);
    }

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================

    /* ========================= Liquidity Provider Functions =========================  */

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value).
    // You can change the inputs, or the scope of your function, as needed.
    function addLiquidity(uint max_exchange_rate, uint min_exchange_rate)
        external
        payable
    {
        // sender wants to send equivalent of msg.value (ETH) in tokens to the contract
        uint equivalent_token_amt = msg.value * (token_reserves / eth_reserves);
        uint curr_eth_price = token_reserves / eth_reserves;

        if (token.balanceOf(msg.sender) >= equivalent_token_amt) {
            if (
                curr_eth_price < max_exchange_rate &&
                curr_eth_price > min_exchange_rate
            ) {
                token.transferFrom(
                    msg.sender,
                    address(this),
                    equivalent_token_amt
                );

                uint old_eth_reserves = eth_reserves;
                eth_reserves += msg.value;
                token_reserves += equivalent_token_amt;

                // populate lps address -> proportion of ETH/entire eth pool owned by current user
                adjustAddLiquidityProviders(
                    msg.value,
                    msg.sender,
                    old_eth_reserves,
                    true
                );
            }
        }
    }

    function adjustAddLiquidityProviders(
        uint newETHAmount,
        address senderAddress,
        uint oldEthReserves,
        bool addLiquid
    ) private {
        // TODO: if address is not already contained in the map, add address to the array
        if (lps[senderAddress] < 0) {
            lp_providers.push(senderAddress);
        }
        for (uint i = 0; i < lp_providers.length; i++) {
            address currAddress = lp_providers[i];
            uint old_amount = lps[currAddress];
            if (lp_providers[i] == senderAddress) {
                if (addLiquid) {
                    lps[senderAddress] =
                        (newETHAmount * denominator) /
                        eth_reserves;
                } else {
                    //removeLiquidity() was called
                }
            } else {
                lps[currAddress] =
                    ((old_amount - newETHAmount) / denominator) *
                    oldEthReserves;
            }
        }
    }

    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(
        uint amountETH,
        uint max_exchange_rate,
        uint min_exchange_rate
    ) public payable {
        // add require statement for: (1) if liquidity provider tries to take out more liquidity than they're entitled to
        //                            (2) if liquidity provider tried to deplete ETH or token reserves to 0
        uint equivalent_token_amt = amountETH * (token_reserves / eth_reserves);
        uint curr_eth_price = token_reserves / eth_reserves;
        require(
            (eth_reserves - amountETH) > 0,
            "Cannot deplete the liquidity pool to 0"
        );
        require(
            (token_reserves - equivalent_token_amt) > 0,
            "Cannot deplete the liquidity pool to 0"
        );
        // TODO: check for if liquidity provider trying to take more than they are "entitled to"
        // require(
        //     (lps[msg.sender] * amountETH) -  amountETH > 0
        // );

        // HERE, do we need to check for tokens too??
        if (
            curr_eth_price < max_exchange_rate &&
            curr_eth_price > min_exchange_rate
        ) {
            payable(msg.sender).transfer(amountETH); //transfer the money
            uint old_eth_amt = eth_reserves;
            eth_reserves = eth_reserves + amountETH;
            token_reserves = token_reserves + equivalent_token_amt;
            adjustAddLiquidityProviders(
                amountETH,
                msg.sender,
                old_eth_amt,
                false
            );
        }
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity(uint max_exchange_rate, uint min_exchange_rate)
        external
        payable
    {
        //removeLiquidity(amount?, max_exchange_rate, min);
        // removeLP(int?)
    }

    /***  Define additional functions for liquidity fees here as needed ***/

    /* ========================= Swap Functions =========================  */

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(uint amountTokens, uint max_exchange_rate)
        external
        payable
    {
        /******* TODO: Implement this function *******/
    }

    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens(uint max_exchange_rate) external payable {
        /******* TODO: Implement this function *******/
    }
}
