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
    address public immutable treasury;
    uint256 public immutable deploymentBlock;
    address internal _curator;

    uint256 private _nextPieceId = 1;
    uint256 private _nextExhibitionId = 1;
    uint256 private _feePoolWei;
    uint256 private _reentrancyLock;

    struct ArtPiece {
        address holder;
        bytes32 manifestHash;
        uint256 registeredAtBlock;
        bool exists;
    }

    struct ExhibitionRecord {
        string title;
        uint256 closesAtBlock;
        bool finalized;
        uint256[] pieceIds;
    }

    mapping(uint256 => ArtPiece) private _pieces;
    mapping(uint256 => ExhibitionRecord) private _exhibitions;
    mapping(address => uint256[]) private _piecesByHolder;
    mapping(uint256 => mapping(uint256 => bool)) private _exhibitionContainsPiece;

    constructor() {
        authority = 0x1a7F3e9b2C4d6E8f0A2B4c6D8e0F2A4B6C8D0E2;
        treasury = 0x5c9E2a1F8b7D6e5C4B3A2F1E0D9C8B7A6F5E4D3;
        _curator = 0x8E3f1A5b7C9d2E4F6A8B0C2D4E6F8A0B2C4D6E8;
        deploymentBlock = block.number;
    }

    modifier whenNotReentrant() {
        if (_reentrancyLock != 0) revert Tnr_ReentrancyBlock();
        _reentrancyLock = 1;
        _;
        _reentrancyLock = 0;
    }

    function curator() external view returns (address) {
        return _curator;
    }

    function registerPiece(bytes32 manifestHash) external payable whenNotReentrant {
        if (manifestHash == bytes32(0)) revert Tnr_ManifestHashZero();
        if (msg.value != REGISTRATION_FEE) revert Tnr_InvalidPaymentAmount();
        if (_nextPieceId > MAX_REGISTERED_PIECES) revert Tnr_MaxPiecesReached();

        uint256 pieceId = _nextPieceId;
        unchecked {
            _nextPieceId++;
        }

        _pieces[pieceId] = ArtPiece({
            holder: msg.sender,
            manifestHash: manifestHash,
            registeredAtBlock: block.number,
            exists: true
        });

        _piecesByHolder[msg.sender].push(pieceId);
        _feePoolWei += msg.value;

        emit PieceRegistered(msg.sender, pieceId, manifestHash);
    }

    function transferPiece(uint256 pieceId, address to) external {
        if (to == msg.sender) revert Tnr_TransferToSelf();
        ArtPiece storage p = _pieces[pieceId];
        if (!p.exists) revert Tnr_PieceDoesNotExist();
        if (p.holder != msg.sender) revert Tnr_NotPieceHolder();

        address previousHolder = p.holder;
        p.holder = to;

        _removePieceFromHolderList(previousHolder, pieceId);
        _piecesByHolder[to].push(pieceId);

        emit PieceTransferred(pieceId, previousHolder, to);
    }

    function createExhibition(string calldata title, uint256 closesAtBlock) external {
        if (msg.sender != _curator) revert Tnr_CallerNotCurator();
        if (closesAtBlock <= block.number) revert Tnr_ExhibitionAlreadyFinalized();

        uint256 exhibitionId = _nextExhibitionId;
        unchecked {
            _nextExhibitionId++;
        }

        _exhibitions[exhibitionId] = ExhibitionRecord({
            title: title,
            closesAtBlock: closesAtBlock,
            finalized: false,
            pieceIds: new uint256[](0)
        });

        emit ExhibitionCreated(exhibitionId, title, closesAtBlock);
    }

    function addPieceToExhibition(uint256 exhibitionId, uint256 pieceId) external {
        if (msg.sender != _curator) revert Tnr_CallerNotCurator();
        ExhibitionRecord storage ex = _exhibitions[exhibitionId];
        if (ex.closesAtBlock == 0) revert Tnr_ExhibitionDoesNotExist();
        if (ex.finalized) revert Tnr_ExhibitionAlreadyFinalized();
