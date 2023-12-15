# lido-metis-bridge

The repository details the implementation of the bridging of the ERC20 compatible tokens between Ethereum and Metis chains in order to be 
used by Lido.

We highly rely on the bridging methodology provided by Lido to integrate optimism [here](https://github.com/lidofinance/lido-l2/tree/main/contracts/optimism). 
Our aim is to build the same functionality for Metis taking into account the differences between the bridges.

We use the same approach such that instead of using Metis StandardBridge, we develop a bridge for Lido using `IL1ERC20Bridge` and `IL2ERC20Bridge` interfaces.

## Metis Lido Bridge flow:

This part presents an overview of the solution suggested by Lido. The description below is taken as is from the [link](https://github.com/lidofinance/lido-l2/tree/main/contracts/optimism).

![](https://i.imgur.com/yAF9gbl.png)

* BridgingManager - contains administrative methods to retrieve and control the state of the bridging process.
* BridgeableTokens - contains the logic for validation of tokens used in the bridging process.
* CrossDomainEnabled - helper contract for contracts performing cross-domain communications
* L1ERC20TokenBridge - Ethereum's counterpart of the bridge to bridge registered ERC20 compatible tokens between Ethereum and Metis chains.
* L2ERC20TokenBridge - Metis' counterpart of the bridge to bridge registered ERC20 compatible tokens between Ethereum and Metis chains
* ERC20Bridged - an implementation of the ERC20 token with administrative methods to mint and burn tokens.
* OssifiableProxy - the ERC1967 proxy with extra admin functionality.

## Differences between Optimism and Metis bridges
Since the Metis hard fork, there have been significant alterations to the bridge associated with Optimism. However, the last commit on the bridges in Metis was on Dec 2022. The current bridge structure in Metis resembles to an earlier version used by Optimism. For detailed insights into Optimism's bridge implementation, now implemented by Metis, refer to this tutorial: [Optimism Standard Bridge Annotated Code](https://ethereum.org/en/developers/tutorials/optimism-std-bridge-annotated-code/).

The main change is that the bridges on Metis contain additional functions (and events) for handling the deposits and withdrawal with one more parameter and that is the chain id. This enables the Ethereum-Metis bridge to be compatibale with not only Metis but any EVM chain with a valid chain ID.

### Technical details

Metis has added payable in the initiate withdrawal method, which can collect metis in L2 to pay the gas fee of the message relayer in L1. The gas fee is set by `OVM_GasPriceOracle.minErc20BridgeCost` and can be adjusted.

#### IL1ERC20Bridge
**Addtional features:**:

1. New event ERC20ChainID: `event ERC20ChainID(uint256 _chainid);`

2. New function `depositERC20ByChainId`: 
    ```
    function depositERC20ByChainId (
        uint256 _chainid,
        address _l1Token,
        address _l2Token,
        uint _amount,
        uint32 _l2Gas,
        bytes calldata _data
    )
        external payable;
    ```

3. New function `depositERC20ToByChainId`:
    ```
    function depositERC20ToByChainId (
        uint256 _chainid,
        address _l1Token,
        address _l2Token,
        address _to,
        uint _amount,
        uint32 _l2Gas,
        bytes calldata _data
    )
        external payable;
    ```

4. New function `finalizeERC20WithdrawalByChainId`:
    ```
    function finalizeERC20WithdrawalByChainId (
        uint256 _chainid,
        address _l1Token,
        address _l2Token,
        address _from,
        address _to,
        uint _amount,
        bytes calldata _data
    )
        external;
    ```

5. New function `finalizeMetisWithdrawalByChainId`:
    ```
    function finalizeMetisWithdrawalByChainId (
        uint256 _chainid,
        address _from,
        address _to,
        uint _amount,
        bytes calldata _data
    )
        external;
    ```

#### L1ERC20TokenBridge

The function `_initiateERC20DepositByChainId` requires having a minimum gas retrieved from the oracle. It also supports discounts. The
function acts differently if the L1 token is Metis or not (this is to handle Metis being ERC20 on both Ethereum and Metis).


#### IL2ERC20Bridge

**Existing functions changes:**

1. The function `withdraw` is payable in Metis but it's nonpayable in Optimism. 
2. The function is `withdrawTo` is payable in Metis but it's nonpayable in Optimism. 

#### L1ERC20TokenBridge

The function `_initiateWithdrawal` requires minimum L1 gas. The function acts differently if the L2 token is Metis. 

#### ICrossDomainMessenger

**Addtional features:**:
1. New function `sendMessageViaChainId`:
```
    function sendMessageViaChainId(
        uint256 _chainId,
        address _target,
        bytes calldata _message,
        uint32 _gasLimit
    ) external payable;
```

**Existing functions changes:**
1. The function `sendMessage` is payable in Metis but it's nonpayable in Optimism.

## Optimism-Metis integration
In this part we present how we address the changes between the two networks. Simply put, for the additional functions, we grab the implementation provided by Metis in the [MVM repository](https://github.com/MetisProtocol/mvm/tree/develop/packages/contracts/contracts).
For existing functions changes, the signature of functions stay the same, we transfrom nonpayable funcitons to payable.

We can as well drop the implementation of the additional functions that incorporate the chain id as a parameter. For Lido usecase, the 
bridging will happen between Ethereum and Metis. However, we decided to implement them as part of future integration. 

**Metis token functionality dropped:**
- In Metis' `L1StandardBridge` contract, we have the function `_initiateERC20DepositByChainId`. The function encodes the message differntly based on whether the L1 token is Metis or not. We removed this part in the Lido bridge, as the bridge is not supposed to handle Metis tokens. This saves gas as well. 

- The funciton `finalizeMetisWithdrawalByChainId` in `L1ERC20TokenBridge` was not implemented. Calling this function will revert with `ErrorNotImplemented`. 

- The functions `withdrawMetis`, `withdrawMetisTo` in `L2ERC20TokenBridge` were not implemented. Calling these functions will revert with `ErrorNotImplemented`. 

- The function `finalizeDeposit` in `L2ERC20TokenBridge`, we don't verify the deposited token on L1 matches the L2 deposited token representation. This is done in `L2StandardBridge` in Metis.

