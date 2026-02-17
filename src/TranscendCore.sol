// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IHeaderVerifier.sol";

contract TranscendCore {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    error ErrExpired();
    error ErrInvalidSignature();
    error ErrNonceUsed();
    error ErrProofInvalid();
    error ErrIntentMismatch();
    error ErrWrongRecipient();
    error ErrWrongAsset();
    error ErrMinOutputNotMet();
    error ErrFeeExceeded();
    error ErrWrongChain();
    error ErrPaused();
    error ErrInvalidETHAmount();
    error ErrTransferFailed();
    error ErrUnauthorized();
    error ErrInvalidAddress();

    struct Intent {
        uint256 version;
        address user;
        uint256 originChainId;
        uint256 destinationChainId;
        address inputAsset;
        address outputAsset;
        uint256 inputAmount;
        uint256 minOutputAmount;
        address recipient;
        uint256 maxFee;
        uint256 expiry;
        uint256 nonce;
        bytes32 routeHash;
    }

    mapping(address => mapping(uint256 => bool)) public nonceUsed;
    mapping(uint256 => address) public headerVerifiers;

    bool public paused;
    uint256 public flatBaseFee;
    uint256 public bpsFee;
    address public immutable GOVERNANCE;
    address public immutable TREASURY;
    bytes32 public immutable DOMAIN_SEPARATOR;

    bytes32 public constant INTENT_TYPEHASH = keccak256(
        "Intent(uint256 version,address user,uint256 originChainId,uint256 destinationChainId,address inputAsset,address outputAsset,uint256 inputAmount,uint256 minOutputAmount,address recipient,uint256 maxFee,uint256 expiry,uint256 nonce,bytes32 routeHash)"
    );

    constructor(uint256 _initialFee, uint256 _initialBps, address _treasury) {
        if (_treasury == address(0)) revert ErrInvalidAddress();
        
        GOVERNANCE = msg.sender;
        TREASURY = _treasury;
        flatBaseFee = _initialFee;
        bpsFee = _initialBps;

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("Transcend"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    function settle(
        Intent calldata intent,
        bytes calldata userSignature,
        bytes calldata proof
    ) external payable {
        if (paused) revert ErrPaused();
        if (block.timestamp > intent.expiry) revert ErrExpired();
        if (intent.originChainId != block.chainid) revert ErrWrongChain();

        address user = intent.user;
        uint256 nonce = intent.nonce;
        if (nonceUsed[user][nonce]) revert ErrNonceUsed();

        uint256 dynamicFee = (intent.inputAmount * bpsFee) / 10000;
        uint256 finalFee = dynamicFee > flatBaseFee ? dynamicFee : flatBaseFee;
        
        if (finalFee > intent.maxFee) revert ErrFeeExceeded();

        address inputAsset = intent.inputAsset;
        if (inputAsset == address(0)) {
            if (msg.value != intent.inputAmount) revert ErrInvalidETHAmount();
        } else {
            if (msg.value != 0) revert ErrInvalidETHAmount();
        }

        bytes32 structHash = _verifySignature(intent, userSignature);
        _verifyProof(intent, proof, structHash);

        nonceUsed[user][nonce] = true;

        uint256 solverReward;
        unchecked {
            solverReward = intent.inputAmount - finalFee;
        }

        if (inputAsset == address(0)) {
            (bool s1, ) = payable(msg.sender).call{value: solverReward}("");
            (bool s2, ) = payable(TREASURY).call{value: finalFee}("");
            if (!s1 || !s2) revert ErrTransferFailed();
        } else {
            IERC20(inputAsset).safeTransferFrom(user, msg.sender, solverReward);
            IERC20(inputAsset).safeTransferFrom(user, TREASURY, finalFee);
        }
    }

    function _verifySignature(Intent calldata intent, bytes calldata userSignature) internal view returns (bytes32 structHash) {
        structHash = keccak256(abi.encode(INTENT_TYPEHASH, intent.version, intent.user, intent.originChainId, intent.destinationChainId, intent.inputAsset, intent.outputAsset, intent.inputAmount, intent.minOutputAmount, intent.recipient, intent.maxFee, intent.expiry, intent.nonce, intent.routeHash));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        if (digest.recover(userSignature) != intent.user) revert ErrInvalidSignature();
    }

    function _verifyProof(Intent calldata intent, bytes calldata proof, bytes32 structHash) internal view {
        uint256 dstChainId = intent.destinationChainId;
        address verifier = headerVerifiers[dstChainId];
        if (verifier == address(0)) revert ErrProofInvalid();
        (bool success, bytes memory publicInputs) = IHeaderVerifier(verifier).verifyProof(dstChainId, proof);
        if (!success) revert ErrProofInvalid();

        (bytes32 pHash, address pRecipient, address pAsset, uint256 pAmount) = abi.decode(publicInputs, (bytes32, address, address, uint256));
        if (pHash != structHash || pRecipient != intent.recipient || pAsset != intent.outputAsset || pAmount < intent.minOutputAmount) revert ErrIntentMismatch();
    }

    function setProtocolFees(uint256 _newFlat, uint256 _newBps) external {
        if (msg.sender != GOVERNANCE) revert ErrUnauthorized();
        flatBaseFee = _newFlat;
        bpsFee = _newBps;
    }

    function registerHeaderVerifier(uint256 chainId, address verifier) external {
        if (msg.sender != GOVERNANCE) revert ErrUnauthorized();
        headerVerifiers[chainId] = verifier;
    }

    function pause(bool status) external {
        if (msg.sender != GOVERNANCE) revert ErrUnauthorized();
        paused = status;
    }
}