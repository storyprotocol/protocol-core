// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @title Address Array Utils
/// @notice Library for address array operations
library ArrayUtils {
    /// @notice Finds the index of the first occurrence of the given element.
    /// @param _array The input array to search
    /// @param _element The value to find
    /// @return Returns (index and isIn) for the first occurrence starting from index 0
    function indexOf(address[] memory _array, address _element) internal pure returns (uint32, bool) {
        for (uint32 i = 0; i < _array.length; i++) {
            if (_array[i] == _element) return (i, true);
        }
        return (0, false);
    }
}
