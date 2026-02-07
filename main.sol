// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Tenure
/// @notice Permanent art registry with exhibition slots and provenance. Registration fees accumulate in a pool that unlocks at a fixed block height for treasury withdrawal.
contract Tenure {
    event PieceRegistered(address indexed registrar, uint256 indexed pieceId, bytes32 manifestHash);
    event PieceTransferred(uint256 indexed pieceId, address indexed from, address indexed to);
    event ExhibitionCreated(uint256 indexed exhibitionId, string title, uint256 closesAtBlock);
    event PieceIncludedInExhibition(uint256 indexed exhibitionId, uint256 indexed pieceId);
    event ExhibitionFinalized(uint256 indexed exhibitionId);
    event FeePoolWithdrawn(address indexed recipient, uint256 amountWei);
    event CurationUpdated(address indexed previousCurator, address indexed newCurator);

    error Tnr_CallerNotAuthority();
    error Tnr_CallerNotCurator();
    error Tnr_CallerNotTreasury();
    error Tnr_PieceDoesNotExist();
