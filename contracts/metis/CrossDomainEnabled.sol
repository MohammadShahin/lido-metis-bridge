// SPDX-FileCopyrightText: 2022 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.10;

import {ICrossDomainMessenger} from "./interfaces/ICrossDomainMessenger.sol";

/// @dev Helper contract for contracts performing cross-domain communications
contract CrossDomainEnabled {
    /// @notice Messenger contract used to send and receive messages from the other domain
    ICrossDomainMessenger public immutable messenger;

    /// @param messenger_ Address of the CrossDomainMessenger on the current layer
    constructor(address messenger_) {
        messenger = ICrossDomainMessenger(messenger_);
    }

    /// @dev Sends a message to an account on another domain
    /// @param crossDomainTarget_ Intended recipient on the destination domain
    /// @param message_ Data to send to the target (usually calldata to a function with
    ///     `onlyFromCrossDomainAccount()`)
    /// @param gasLimit_ gasLimit for the receipt of the message on the target domain.
    function sendCrossDomainMessage(
        address crossDomainTarget_,
        uint32 gasLimit_,
        bytes memory message_,
        uint256 fee
    ) internal {
        messenger.sendMessage{value:fee}(crossDomainTarget_, message_, gasLimit_);
    }

    /**
     * @notice Sends a message to an account on another domain
     * @param chainId_ L2 chain id.
     * @param crossDomainTarget_ The intended recipient on the destination domain
     * @param gasLimit_ The gasLimit for the receipt of the message on the target domain.
     * @param message_ The data to send to the target (usually calldata to a function with `onlyFromCrossDomainAccount()`)
     */
    function sendCrossDomainMessageViaChainId(
        uint256 chainId_,
        address crossDomainTarget_,
        uint32 gasLimit_,
        bytes memory message_,
        uint256 fee
    ) internal {
        messenger.sendMessageViaChainId{value:fee}(chainId_, crossDomainTarget_, message_, gasLimit_);
    }

    /// @dev Enforces that the modified function is only callable by a specific cross-domain account
    /// @param sourceDomainAccount_ The only account on the originating domain which is
    ///     authenticated to call this function
    modifier onlyFromCrossDomainAccount(address sourceDomainAccount_) {
        if (msg.sender != address(messenger)) {
            revert ErrorUnauthorizedMessenger();
        }
        if (messenger.xDomainMessageSender() != sourceDomainAccount_) {
            revert ErrorWrongCrossDomainSender();
        }
        _;
    }

    error ErrorUnauthorizedMessenger();
    error ErrorWrongCrossDomainSender();
}
