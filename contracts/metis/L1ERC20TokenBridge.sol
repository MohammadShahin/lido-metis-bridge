// SPDX-FileCopyrightText: 2022 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IL1ERC20Bridge} from "./interfaces/IL1ERC20Bridge.sol";
import {IL2ERC20Bridge} from "./interfaces/IL2ERC20Bridge.sol";
import {iMVM_DiscountOracle} from "./interfaces/iMVM_DiscountOracle.sol";

import {BridgingManager} from "../BridgingManager.sol";
import {BridgeableTokens} from "../BridgeableTokens.sol";
import {CrossDomainEnabled} from "./CrossDomainEnabled.sol";

import {Lib_AddressManager} from "./resolver/Lib_AddressManager.sol";

import {Lib_Uint} from "./utils/Lib_Uint.sol";

/// @author psirex
/// @notice The L1 ERC20 token bridge locks bridged tokens on the L1 side, sends deposit messages
///     on the L2 side, and finalizes token withdrawals from L2. Additionally, adds the methods for
///     bridging management: enabling and disabling withdrawals/deposits
contract L1ERC20TokenBridge is
    IL1ERC20Bridge,
    BridgingManager,
    BridgeableTokens,
    CrossDomainEnabled
{
    using SafeERC20 for IERC20;

    /// @inheritdoc IL1ERC20Bridge
    address public immutable l2TokenBridge;
    address public addressmgr;

    uint256 public constant DEFAULT_CHAINID = 1088;

    /// @param messenger_ L1 messenger address being used for cross-chain communications
    /// @param l2TokenBridge_ Address of the corresponding L2 bridge
    /// @param l1Token_ Address of the bridged token in the L1 chain
    /// @param l2Token_ Address of the token minted on the L2 chain when token bridged
    constructor(
        address messenger_,
        address l2TokenBridge_,
        address l1Token_,
        address l2Token_,
        address addressmgr_
    ) CrossDomainEnabled(messenger_) BridgeableTokens(l1Token_, l2Token_) {
        l2TokenBridge = l2TokenBridge_;
        addressmgr = addressmgr_;
    }

    /// @inheritdoc IL1ERC20Bridge
    function depositERC20(
        address l1Token_,
        address l2Token_,
        uint256 amount_,
        uint32 l2Gas_,
        bytes calldata data_
    )
        external
        whenDepositsEnabled
        onlySupportedL1Token(l1Token_)
        onlySupportedL2Token(l2Token_)
    {
        if (Address.isContract(msg.sender)) {
            revert ErrorSenderNotEOA();
        }
        _initiateERC20DepositByChainId(
            DEFAULT_CHAINID,
            msg.sender,
            msg.sender,
            amount_,
            l2Gas_,
            data_
        );
    }

    /// @inheritdoc IL1ERC20Bridge
    function depositERC20To(
        address l1Token_,
        address l2Token_,
        address to_,
        uint256 amount_,
        uint32 l2Gas_,
        bytes calldata data_
    )
        external
        whenDepositsEnabled
        onlyNonZeroAccount(to_)
        onlySupportedL1Token(l1Token_)
        onlySupportedL2Token(l2Token_)
    {
        _initiateERC20DepositByChainId(
            DEFAULT_CHAINID,
            msg.sender,
            to_,
            amount_,
            l2Gas_,
            data_
        );
    }

    /// @inheritdoc IL1ERC20Bridge
    function depositERC20ByChainId(
        uint256 chainid_,
        address l1Token_,
        address l2Token_,
        uint amount_,
        uint32 l2Gas_,
        bytes calldata data_
    )
        external
        payable
        whenDepositsEnabled
        onlySupportedL1Token(l1Token_)
        onlySupportedL2Token(l2Token_)
    {
        if (Address.isContract(msg.sender)) {
            revert ErrorSenderNotEOA();
        }
        _initiateERC20DepositByChainId(
            chainid_,
            msg.sender,
            msg.sender,
            amount_,
            l2Gas_,
            data_
        );
    }

    /// @inheritdoc IL1ERC20Bridge
    function depositERC20ToByChainId(
        uint256 chainid_,
        address l1Token_,
        address l2Token_,
        address to_,
        uint amount_,
        uint32 l2Gas_,
        bytes calldata data_
    )
        external
        payable
        whenDepositsEnabled
        onlyNonZeroAccount(to_)
        onlySupportedL1Token(l1Token_)
        onlySupportedL2Token(l2Token_)
    {
        _initiateERC20DepositByChainId(
            chainid_,
            msg.sender,
            to_,
            amount_,
            l2Gas_,
            data_
        );
    }

    /// @inheritdoc IL1ERC20Bridge
    function finalizeERC20Withdrawal(
        address l1Token_,
        address l2Token_,
        address from_,
        address to_,
        uint256 amount_,
        bytes calldata data_
    )
        external
        whenWithdrawalsEnabled
        onlySupportedL1Token(l1Token_)
        onlySupportedL2Token(l2Token_)
        onlyFromCrossDomainAccount(l2TokenBridge)
    {
        _finalizeERC20WithdrawalByChainId(
            DEFAULT_CHAINID,
            l1Token_,
            l2Token_,
            from_,
            to_,
            amount_,
            data_
        );
    }

    /// @inheritdoc IL1ERC20Bridge
    function finalizeERC20WithdrawalByChainId(
        uint256 chainid_,
        address l1Token_,
        address l2Token_,
        address from_,
        address to_,
        uint amount_,
        bytes calldata data_
    )
        external
        whenWithdrawalsEnabled
        onlySupportedL1Token(l1Token_)
        onlySupportedL2Token(l2Token_)
        onlyFromCrossDomainAccount(l2TokenBridge)
    {
        _finalizeERC20WithdrawalByChainId(
            chainid_,
            l1Token_,
            l2Token_,
            from_,
            to_,
            amount_,
            data_
        );
    }

    function finalizeMetisWithdrawalByChainId(
        uint256,
        address,
        address,
        uint,
        bytes calldata
    ) external {
        revert ErrorNotImplemented();
    }

    /**
     * @dev Performs the logic for deposits by informing the L2 Deposited Token
     * contract of the deposit and calling a handler to lock the L1 funds. (e.g. transferFrom)
     *
     * @param chainId_ L2 chain id
     * @param from_ Account to pull the deposit from on L1
     * @param to_ Account to give the deposit to on L2
     * @param amount_ Amount of the ERC20 to deposit.
     * @param l2Gas_ Gas limit required to complete the deposit on L2,
     *        it should equal to or large than oracle.getMinL2Gas(),
     *        user should send at least l2Gas_ * oracle.getDiscount().
     *        Bridging tokens and coins require paying fees, and there is the defined minimal L2 Gas limit,
     *        which may make the defined by user Gas value increase.
     * @param data_ Optional data to forward to L2. This data is provided
     *        solely as a convenience for external contracts. Aside from enforcing a maximum
     *        length, these contracts provide no guarantees about its content.
     */
    function _initiateERC20DepositByChainId(
        uint256 chainId_,
        address from_,
        address to_,
        uint256 amount_,
        uint32 l2Gas_,
        bytes calldata data_
    ) internal {
        iMVM_DiscountOracle oracle = iMVM_DiscountOracle(
            Lib_AddressManager(addressmgr).getAddress("MVM_DiscountOracle")
        );

        // stack too deep. so no more local variables
        if (l2Gas_ < uint32(oracle.getMinL2Gas())) {
            l2Gas_ = uint32(oracle.getMinL2Gas());
        }

        require(
            l2Gas_ * oracle.getDiscount() <= msg.value,
            string(
                abi.encodePacked(
                    "insufficient fee supplied. send at least ",
                    Lib_Uint.uint2str(l2Gas_ * oracle.getDiscount())
                )
            )
        );

        // When a deposit is initiated on L1, the L1 Bridge transfers the funds to itself for future
        // withdrawals. safeTransferFrom also checks if the contract has code, so this will fail if
        // from_ is an EOA or address(0).
        IERC20(l1Token).safeTransferFrom(from_, address(this), amount_);

        bytes memory message = abi.encodeWithSelector(
            IL2ERC20Bridge.finalizeDeposit.selector,
            l1Token,
            l2Token,
            from_,
            to_,
            amount_,
            data_
        );

        // Send calldata into L2
        sendCrossDomainMessageViaChainId(
            chainId_,
            l2TokenBridge,
            l2Gas_,
            message,
            msg.value //send all values as fees to cover l2 tx cost
        );

        emit ERC20ChainID(chainId_);
        emit ERC20DepositInitiated(
            l1Token,
            l2Token,
            from_,
            to_,
            amount_,
            data_
        );
    }

    function _finalizeERC20WithdrawalByChainId(
        uint256 chainid_,
        address l1Token_,
        address l2Token_,
        address from_,
        address to_,
        uint256 amount_,
        bytes calldata data_
    ) internal {
        // When a withdrawal is finalized on L1, the L1 Bridge transfers the funds to the withdrawer
        IERC20(l1Token_).safeTransfer(to_, amount_);

        emit ERC20ChainID(chainid_);
        emit ERC20WithdrawalFinalized(
            l1Token_,
            l2Token_,
            from_,
            to_,
            amount_,
            data_
        );
    }

    error ErrorSenderNotEOA();
    error ErrorNotImplemented();
}
