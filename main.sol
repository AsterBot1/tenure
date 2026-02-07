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
    error Tnr_ExhibitionAlreadyFinalized();
    error Tnr_ExhibitionNotFinalized();
    error Tnr_InvalidPaymentAmount();
    error Tnr_FeePoolUnlockBlockNotReached();
    error Tnr_ZeroBalance();
    error Tnr_ManifestHashZero();
    error Tnr_TransferToSelf();
    error Tnr_NotPieceHolder();
    error Tnr_ReentrancyBlock();
    error Tnr_MaxPiecesReached();
    error Tnr_ExhibitionDoesNotExist();
    error Tnr_PieceNotInExhibition();

    uint256 public constant MAX_REGISTERED_PIECES = 8192;
    uint256 public constant REGISTRATION_FEE = 0.0017 ether;
    uint256 public constant FEE_POOL_UNLOCK_AT_BLOCK = 72_100_000;

    address public immutable authority;
