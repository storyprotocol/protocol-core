// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @title DataUniqueness
/// @notice Library to store data without repetition, assigning an id to it if new or reusing existing one
/// if already stored
library DataUniqueness {
    /// Stores data without repetition, assigning an id to it if new or reusing existing one if already stored
    /// @param data raw bytes, abi.encode() a value to be hashed
    /// @param _hashToIds storage ref to the mapping of hash -> data id
    /// @param existingIds amount of distinct data stored.
    /// @return id new sequential id if new data, reused id if not new
    /// @return isNew True if a new id was generated, signaling the value was stored in _hashToIds.
    ///               False if id is reused and data was not stored
    function addIdOrGetExisting(
        bytes memory data,
        mapping(bytes32 => uint256) storage _hashToIds,
        uint256 existingIds
    ) internal returns (uint256 id, bool isNew) {
        // We could just use the hash as id to save some gas, but the UX/DX of having huge random
        // numbers for ID is bad enough to justify the cost, plus we have a counter if we need to.
        bytes32 hash = keccak256(data);
        id = _hashToIds[hash];
        if (id != 0) {
            return (id, false);
        }
        id = existingIds + 1;
        _hashToIds[hash] = id;
        return (id, true);
    }
}
