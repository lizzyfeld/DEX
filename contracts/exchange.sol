// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./token.sol";
import "hardhat/console.sol";

contract TokenExchange is Ownable {
    string public exchange_name = "CS 251 Exchange";

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
    // mapping(address => uint) private lp_numerators;

    // constant denominator for our liquidity proportions in lps
    uint private denominator = 10000;

    // liquidity rewards
    uint private swap_fee_numerator = 5; // TODO Part 5: Set liquidity providers' returns.
    uint private swap_fee_denominator = 100;

    // Constant: x * y = k
    uint private k;

    constructor() {}

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens) external payable onlyOwner {
        // This function is already implemented for you; no changes needed.

        console.log("hello");
        console.log("createpoool TESTING************************\n\n\n\n\n\n\n\n");

        // console.log("WHAT THE FUCK &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&\n\n\n\n\n\n");

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
        // Make sure sender is sending positive amt of money.
        require(msg.value > 0, "Must add a positive amount of liquidity.");
        // Make sure sender has enough ETH and enough tokens (use msg.value because you add same amout of tokens as ETH)
        // TODO: check if sender actually has enough ETH to make this work

        // sender wants to send equivalent of msg.value (ETH) in tokens to the contract

        console.log("EQUIVALENT AMT CALCULATIONS", k, eth_reserves);
        console.log('continued', msg.value, token_reserves);
        uint equivalent_token_amt = msg.value * (token_reserves / eth_reserves); // (token_reserves - (k / (eth_reserves + msg.value))); //  
        uint curr_eth_price = token_reserves / eth_reserves;

        require(token.balanceOf(msg.sender) >= equivalent_token_amt, "Not enough tokens");

            if (
                curr_eth_price < max_exchange_rate &&
                curr_eth_price > min_exchange_rate
            ) {
                console.log("balance of contract BEFORE transfer", token.balanceOf(address(this)));
                token.transferFrom(
                    msg.sender,
                    address(this),
                    equivalent_token_amt
                );

                console.log("balance of contract AFTER transfer", token.balanceOf(address(this)));

                uint old_eth_reserves = eth_reserves;
                eth_reserves += msg.value;
                token_reserves += equivalent_token_amt;
                
                // updating k per section 4 advice
                k = eth_reserves * token_reserves;

                // populate lps address -> proportion of ETH/entire eth pool owned by current user
                adjustAddLiquidityProviders(
                    msg.value,
                    msg.sender,
                    old_eth_reserves,
                    true
                );
            }
        }

    function adjustAddLiquidityProviders(
        uint newETHAmount,
        address senderAddress,
        uint oldEthReserves,
        bool addLiquid
    ) private {
        // TODO: if address is not already contained in the map, add address to the array

        if (lps[senderAddress] == 0) {
            lp_providers.push(senderAddress);
        }

        for (uint i = 0; i < lp_providers.length; i++) {
            address currAddress = lp_providers[i];
            uint old_eth_amount = lps[currAddress] * oldEthReserves;
            if (lp_providers[i] == senderAddress) {
                if (addLiquid) {
                    uint curr_lp_num = lps[senderAddress];
                    uint old_lp_bal = curr_lp_num * oldEthReserves / denominator;
                    uint new_lp_bal = old_lp_bal + newETHAmount;
                    uint new_pool_amt = oldEthReserves + newETHAmount; // could just use eth_reserves here
                    uint new_lp_num = new_lp_bal * denominator / new_pool_amt;
                    lps[senderAddress] = new_lp_num;

                } else {
                    //removeLiquidity() was called
                    uint curr_lp_num = lps[senderAddress];
                    uint old_lp_bal = curr_lp_num * oldEthReserves / denominator;
                    uint new_lp_bal = old_lp_bal - newETHAmount;
                    uint new_pool_amt = oldEthReserves - newETHAmount; // could just use eth_reserves here
                    uint new_lp_num = new_lp_bal * denominator / new_pool_amt;
                    lps[senderAddress] = new_lp_num;
                }
            } else {
                lps[currAddress] = old_eth_amount / eth_reserves;
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
        console.log("first subtraction: ", amountETH, eth_reserves);
        console.log("second subtraction: ", token_reserves, k);
        uint equivalent_token_amt = amountETH * token_reserves / eth_reserves; // ((k / (token_reserves - amountETH)) - eth_reserves);
        uint curr_eth_price = token_reserves / eth_reserves;

        console.log("Equivalent token amount: ", equivalent_token_amt);
        
        require(
            eth_reserves > amountETH,
            "Cannot deplete all ETH from liquidity pool"
        );
        require(
            token_reserves > equivalent_token_amt,
            "Cannot deplete all tokens from liquidity pool"
        );
        console.log("trying to take out:", lps[msg.sender], eth_reserves);
        //TODO: check for if liquidity provider trying to take more than they are "entitled to"
        require((lps[msg.sender] * eth_reserves) > amountETH, "LP trying to take more than they are entitled to");

        if (
            curr_eth_price < max_exchange_rate &&
            curr_eth_price > min_exchange_rate
        ) {
            payable(msg.sender).transfer(amountETH); //transfer the ETH amount
            token.transfer(msg.sender, equivalent_token_amt); // transfer token amount
            uint old_eth_amt = eth_reserves;
            eth_reserves = eth_reserves - amountETH;
            token_reserves = token_reserves - equivalent_token_amt;

            // updating k per section 4 advice
            k = eth_reserves * token_reserves;


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
    function removeAllLiquidity(
        uint max_exchange_rate,
        uint min_exchange_rate
    ) external payable {
        console.log("REMOVE ALL TESTING", lps[msg.sender], eth_reserves,  denominator);
        removeLiquidity(
            lps[msg.sender] * eth_reserves / denominator,
            max_exchange_rate,
            min_exchange_rate
        );

        // remove LP from the array
        for (uint256 i = 0; i < lp_providers.length; i++) {
            if (lp_providers[i] == msg.sender) {
                removeLP(i);
            }
        }
    }

    /***  Define additional functions for liquidity fees here as needed ***/

    /* ========================= Swap Functions =========================  */

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(
        uint amountTokens,
        uint max_exchange_rate
    ) external payable {
        require(amountTokens > 0, "Must swap a positive non-zero amount of tokens for ETH");
        require(token.balanceOf(msg.sender) >= amountTokens, "Not enough tokens");
        require(amountTokens < token_reserves, "Cannot deplete pool of tokens");



        console.log("token_reserves:", token_reserves);
        console.log("k", k);
        console.log("eth_reserves", eth_reserves);
        console.log("amountTokens", amountTokens);
        console.log("Equiv eth amount:", (k / token_reserves + amountTokens));
        uint equivalent_ETH_amt = eth_reserves - (k / (token_reserves + amountTokens)); //(amountTokens * eth_reserves) / token_reserves;


        console.log("EQUIVALENT ETH AMOUNT:", equivalent_ETH_amt); // , amountTokens, eth_reserves, token_reserves, equivalent_ETH_amt);
        require(equivalent_ETH_amt < eth_reserves, "cannot deplete pool of ETH reserves");
        console.log("Token value of this contract before receiving token:", token.balanceOf(address(this)));
        console.log("ETH value of this contract before sending ETH:", address(this).balance);

        console.log("\n\n\n eth_reserves, token_reserves", eth_reserves, token_reserves, max_exchange_rate);
        require((eth_reserves / token_reserves) <= max_exchange_rate, "exchange rate higher than max allowed");

        
        console.log("Token value of this contract after receiving token:", token.balanceOf(address(this)));
        console.log("ETH value of this contract after sending ETH:", address(this).balance);
        token_reserves += amountTokens;
        eth_reserves -= equivalent_ETH_amt;


        uint eth_to_take = equivalent_ETH_amt - ((swap_fee_numerator * amountTokens) / swap_fee_denominator);

        // new stuff
        token.transferFrom(msg.sender, address(this), amountTokens);
        payable(msg.sender).transfer(eth_to_take); //transfer the ETH amount
    }

    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens(uint max_exchange_rate) external payable {
        require(msg.value > 0, "Must swap a positive non-zero amount of ETH for tokens");
        require(msg.value < eth_reserves, "Cannot deplete pool of tokens");
        require((token_reserves / eth_reserves) <= max_exchange_rate, "exchange rate higher than max allowed");


        uint equivalent_token_amt = (token_reserves - (k / (eth_reserves + msg.value))); // token_reserves - k / (eth_reserves + msg.value); // (msg.value * token_reserves) / eth_reserves;


        require(equivalent_token_amt < token_reserves, "cannot deplete pool of token reserves");

        console.log("ETH value of this contract after receiving ETH:", address(this).balance);
        console.log("Token value of this contract before sending token:", token.balanceOf(address(this)));

        token.transfer(msg.sender, equivalent_token_amt); // transfer token amount

        console.log("Token value of this contract after sending token:", token.balanceOf(address(this)));

        token_reserves -= equivalent_token_amt;
        eth_reserves += msg.value;

        // How to check if the person has enough ETH for this?
    }
}
