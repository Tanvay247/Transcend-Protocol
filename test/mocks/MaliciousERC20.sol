// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title MaliciousERC20
 * @notice Adversarial ERC20 mock used to test SafeERC20 and settlement robustness.
 */
contract MaliciousERC20 {
    string public name = "MaliciousToken";
    string public symbol = "MAL";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Adversarial mode flags
    bool public returnFalseMode;
    bool public silentFailMode;
    bool public noReturnMode;
    bool public revertMode;

    /**
     * @notice Mints tokens to a specified address.
     */
    function mint(address to, uint256 amount) external {
        require(to != address(0), "ERC20: mint to zero address");
        balanceOf[to] += amount;
    }

    /**
     * @notice Unified setter for adversarial testing modes.
     */
    function setModes(
        bool _returnFalse,
        bool _silentFail,
        bool _noReturn,
        bool _revertMode
    ) external {
        returnFalseMode = _returnFalse;
        silentFailMode = _silentFail;
        noReturnMode = _noReturn;
        revertMode = _revertMode;
    }

    /**
     * @notice Standard ERC20 approval.
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    /**
     * @notice TransferFrom with adversarial overrides.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        // 1. Revert Mode: Immediate failure to test bubbling
        if (revertMode) {
            revert("Malicious revert");
        }

        // 2. No Return Mode: Simulates USDT-like behavior (no bool returned)
        if (noReturnMode) {
            _performTransfer(from, to, amount);
            // Assembly forces the function to return NO data
            assembly { return(0, 0) }
        }

        // 3. Return False Mode: returns false instead of reverting
        if (returnFalseMode) return false;

        // 4. Silent Fail Mode: returns true but does nothing
        if (silentFailMode) return true;

        // Standard Transfer Logic
        _performTransfer(from, to, amount);
        return true;
    }

    /**
     * @dev Internal transfer logic to reduce code duplication.
     */
    function _performTransfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "Insufficient balance");
        
        if (from != msg.sender && allowance[from][msg.sender] != type(uint256).max) {
            require(allowance[from][msg.sender] >= amount, "Not approved");
            unchecked {
                allowance[from][msg.sender] -= amount;
            }
        }
        
        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }
    }
}