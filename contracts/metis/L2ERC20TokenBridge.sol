// SPDX-FileCopyrightText: 2022 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.10;

import {IL1ERC20Bridge} from "./interfaces/IL1ERC20Bridge.sol";
import {IL2ERC20Bridge} from "./interfaces/IL2ERC20Bridge.sol";
import {IERC20Bridged} from "../token/interfaces/IERC20Bridged.sol";

import {BridgingManager} from "../BridgingManager.sol";
import {BridgeableTokens} from "../BridgeableTokens.sol";
import {CrossDomainEnabled} from "./CrossDomainEnabled.sol";

import {OVM_GasPriceOracle} from "./predeploys/OVM_GasPriceOracle.sol";
import {Lib_PredeployAddresses} from "./libraries/Lib_PredeployAddresses.sol";
import {Lib_Uint} from "./utils/Lib_Uint.sol";

/// @author psirex
/// @notice The L2 token bridge works with the L1 token bridge to enable ERC20 token bridging
///     between L1 and L2. It acts as a minter for new tokens when it hears about
///     deposits into the L1 token bridge. It also acts as a burner of the tokens
///     intended for withdrawal, informing the L1 bridge to release L1 funds. Additionally, adds
///     the methods for bridging management: enabling and disabling withdrawals/deposits
contract L2ERC20TokenBridge is
    IL2ERC20Bridge,
    BridgingManager,
    BridgeableTokens,
    CrossDomainEnabled
{
    /// @inheritdoc IL2ERC20Bridge
    address public immutable l1TokenBridge;

    /// @param messenger_ L2 messenger address being used for cross-chain communications
    /// @param l1TokenBridge_  Address of the corresponding L1 bridge
    /// @param l1Token_ Address of the bridged token in the L1 chain
    /// @param l2Token_ Address of the token minted on the L2 chain when token bridged
    constructor(
        address messenger_,
        address l1TokenBridge_,
        address l1Token_,
        address l2Token_
    ) CrossDomainEnabled(messenger_) BridgeableTokens(l1Token_, l2Token_) {
        l1TokenBridge = l1TokenBridge_;
    }

    function getChainID() internal view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /// @inheritdoc IL2ERC20Bridge
    function withdraw(
        address l2Token_,
        uint256 amount_,
        uint32 l1Gas_,
        bytes calldata data_
    ) external payable whenWithdrawalsEnabled onlySupportedL2Token(l2Token_) {
        _initiateWithdrawal(msg.sender, msg.sender, amount_, l1Gas_, data_);
    }

    function withdrawMetis(
        uint256,
        uint32,
        bytes calldata
    ) external payable virtual {
        revert ErrorNotImplemented();
    }

    /// @inheritdoc IL2ERC20Bridge
    function withdrawTo(
        address l2Token_,
        address to_,
        uint256 amount_,
        uint32 l1Gas_,
        bytes calldata data_
    ) external payable whenWithdrawalsEnabled onlySupportedL2Token(l2Token_) {
        _initiateWithdrawal(msg.sender, to_, amount_, l1Gas_, data_);
    }

    function withdrawMetisTo(
        address,
        uint256,
        uint32,
        bytes calldata
    ) external payable virtual {
        revert ErrorNotImplemented();
    }

    /// @inheritdoc IL2ERC20Bridge
    function finalizeDeposit(
        address l1Token_,
        address l2Token_,
        address from_,
        address to_,
        uint256 amount_,
        bytes calldata data_
    )
        external
        whenDepositsEnabled
        onlySupportedL1Token(l1Token_)
        onlySupportedL2Token(l2Token_)
        onlyFromCrossDomainAccount(l1TokenBridge)
    {
        // Check the target token is compliant and
        // verify the deposited token on L1 matches the L2 deposited token representation here
        // if (
        //     ERC165Checker.supportsInterface(_l2Token, 0x1d1d8b63) &&
        //     _l1Token == IL2StandardERC20(_l2Token).l1Token()
        // ) {
        //     // When a deposit is finalized, we credit the account on L2 with the same amount of
        //     // tokens.
        //     IERC20Bridged(l2Token_).bridgeMint(to_, amount_);
        //     emit DepositFinalized(l1Token_, l2Token_, from_, to_, amount_, data_);
        // } else {
        //     emit DepositFailed(l1Token_, l2Token_, from_, to_, amount_, data_);
        // }

        IERC20Bridged(l2Token_).bridgeMint(to_, amount_);
        emit DepositFinalized(l1Token_, l2Token_, from_, to_, amount_, data_);
    }

    /**
     * @dev Performs the logic for deposits by storing the token and informing the L2 token Gateway
     * of the deposit.
     * @param from_ Account to pull the deposit from on L2.
     * @param to_ Account to give the withdrawal to on L1.
     * @param amount_ Amount of the token to withdraw.
     * param l1Gas_ Unused, but included for potential forward compatibility considerations.
     * @param data_ Optional data to forward to L1. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function _initiateWithdrawal(
        address from_,
        address to_,
        uint256 amount_,
        uint32 l1Gas_,
        bytes calldata data_
    ) internal {
        uint256 minL1Gas = OVM_GasPriceOracle(
            Lib_PredeployAddresses.OVM_GASPRICE_ORACLE
        ).minErc20BridgeCost();

        // require minimum gas unless, the metis manager is the sender
        require(
            msg.value >= minL1Gas ||
                from_ == Lib_PredeployAddresses.SEQUENCER_FEE_WALLET,
            string(
                abi.encodePacked(
                    "insufficient withdrawal fee supplied. need at least ",
                    Lib_Uint.uint2str(minL1Gas)
                )
            )
        );

        // When a withdrawal is initiated, we burn the withdrawer's funds to prevent subsequent L2
        // usage
        IERC20Bridged(l2Token).bridgeBurn(from_, amount_);

        // Construct calldata for l1TokenBridge.finalizeERC20Withdrawal(to_, amount_)
        bytes memory message = abi.encodeWithSelector(
            IL1ERC20Bridge.finalizeERC20WithdrawalByChainId.selector,
            getChainID(),
            l1Token,
            l2Token,
            from_,
            to_,
            amount_,
            data_
        );

        // Send message up to L1 bridge
        sendCrossDomainMessage(
            l1TokenBridge,
            l1Gas_,
            message,
            msg.value // send all value as fees to cover relayer cost
        );

        emit WithdrawalInitiated(
            l1Token,
            l2Token,
            msg.sender,
            to_,
            amount_,
            data_
        );
    }

    error ErrorNotImplemented();
}
