// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title AGVOracle
 * @notice On-chain contract for storing evidence (Daily Snapshot) and the sole minting anchor (Monthly Settlement).
 * @dev Implements the IAGVOracle interface from the plan, minimizing on-chain complexity and gas.
 */
contract AGVOracle is AccessControl, Pausable, EIP712 {
    using ECDSA for bytes32;
    using SafeCast for uint256;

    // --- Roles (Mapped to RACI/Plan) ---
    // DAO_MULTISIG for contract management (Pausable/AccessControl Admin)
    // ORACLE_TEAM for Daily Snapshot posting (Tech Lead / Data Admin)
    // SETTLEMENT_MULTISIG for Monthly Settlement (Finance + Tech)
    bytes32 public constant SETTLEMENT_MULTISIG = keccak256("SETTLEMENT_MULTISIG");
    bytes32 public constant ORACLE_TEAM = keccak256("ORACLE_TEAM");

    // --- Data Structures ---
    // Note: All date/datetime are UTC ISO-8601

    // Maps to Daily_Snapshot fields, scaled for on-chain storage
    struct DailySnapshotData {
        uint256 solarKWhSum_x10; // kWh * 10 (Grid-Delivered Basis)
        uint256 selfConsumedKWh_x10; // kWh * 10 (Disclosure only)
        uint256 computeHoursSum_x10; // h * 10
        uint16 records; // Expected 96 (15-minute sampling)
        bytes32 sheetSha256; // SHA-256 of the canonical CSV file
        address signer; // EIP-712 signer
    }

    // Maps to Monthly_Settlement fields, scaled for on-chain storage
    struct MonthlySettlementData {
        uint256 gridDeliveredKWh_x10; // kWh * 10 (State Grid billed energy)
        uint256 selfConsumedKWh_x10; // kWh * 10 (Disclosure only)
        uint256 tariff_bp; // Tariff * 10,000 (Basis Points)
        bytes32 monthFilesAggSha256; // SHA-256 of all daily CSV hashes aggregated
        bytes32 settlementPdfSha256; // SHA-256 of State Grid bill PDF (Audit Master)
        bytes32 bankSlipSha256; // SHA-256 of bank receipt PDF (Optional)
        uint8 revision; // Starts from 1
        uint256 timestamp; // Block timestamp when stored
        address reconciler; // Multisig/Role address that submitted
    }

    // Maps to EIP-712 structure for off-chain signing (DailySnapshot is the example)
    struct DailySnapshotEIP712 {
        string date;
        string stationId;
        uint256 solarKWhSum_x10;
        uint256 selfConsumedKWh_x10;
        uint256 computeHoursSum_x10;
        uint16 records;
        bytes32 sheetSha256;
    }

    // --- Station Registry (P0 Extension) ---
    enum StationStatus { Unregistered, Active, Suspended, Purged }

    struct StationInfo {
        StationStatus status;
        uint256 registeredAt;       // block.timestamp when registered
        uint256 suspendedAt;        // 0 = not suspended
        uint256 purgedAt;           // 0 = not purged
        uint32 epochId;             // increments on reactivation
    }

    // --- Storage ---
    // Daily Snapshots (evidence only, not mint-determining)
    // mapping: stationId => date (YYYY-MM-DD) => DailySnapshotData
    mapping(string => mapping(string => DailySnapshotData)) public dailySnapshots;

    // Monthly Settlements (sole minting anchor)
    // mapping: stationId => period (YYYY-MM) => revision number => MonthlySettlementData
    mapping(string => mapping(string => mapping(uint8 => MonthlySettlementData))) public monthlySettlements;

    // Tracks the current effective revision for a given period and station
    mapping(string => mapping(string => uint8)) public effectiveRevision;

    // Station Registry: stationId => registration info (P0 Extension)
    mapping(string => StationInfo) public stationRegistry;

    // Chain Hash: stationId => latest snapshot chain head (P0 Extension)
    mapping(string => bytes32) public latestSnapshotHash;

    // Chain Date: stationId => latest snapshot date string (P0 Extension)
    mapping(string => string) public latestSnapshotDate;

    // EIP-712 Typehash for Daily Snapshot
    bytes32 private constant DAILY_SNAPSHOT_TYPEHASH = keccak256(
        "DailySnapshot(string date,string stationId,uint256 solarKWhSum_x10,uint256 selfConsumedKWh_x10,uint256 computeHoursSum_x10,uint16 records,bytes32 sheetSha256)"
    );

    // --- Events (IAGVOracle interface) ---
    // Daily snapshot event
    // "YYYY-MM-DD" (UTC)
    //
    // kWh*10
    // h*10
    // expected 96
    // daily CSV SHA-256
    // optional: EIP-712 signer
    event DailySnapshotStored( // keccak256(JSON; sorted keys; integerized; scaled decimals)
        bytes32 indexed snapshotHash,
        string date,
        string stationId,
        uint256 solarKWhSum_x10,
        // kWh*10
        uint256 selfConsumedKWh_x10,
        uint256 computeHoursSum_x10,
        uint16 records,
        bytes32 sheetSha256,
        address signer
    );

    // Monthly settlement event
    //
    // kWh*10
    // tariff * 10000
    // aggregated hash
    // State Grid bill PDF hash
    // bank receipt hash (optional)
    // starts from 1
    // multisig/role
    event MonthlySettlementStored( // "YYYY-MM"
        string period,
        string stationId,
        uint256 gridDeliveredKWh_x10,
        // kWh*10
        uint256 selfConsumedKWh_x10,
        uint256 tariff_bp,
        bytes32 monthFilesAggSha256,
        bytes32 settlementPdfSha256,
        bytes32 bankSlipSha256,
        uint8 revision,
        address reconciler
    );

    // Amendment event
    //
    // red invoice / supplement / cross-period correction / other
    event MonthlySettlementAmended( //
        string period,
        string stationId,
        //
        uint8 oldRevision,
        uint8 newRevision,
        //
        string reason
    );

    // Station lifecycle events (P0 Extension)
    event StationRegistered(string indexed stationId, uint256 timestamp);
    event StationSuspended(string indexed stationId, uint256 timestamp);
    event StationPurged(string indexed stationId, uint256 timestamp);
    event StationReactivated(string indexed stationId, uint32 newEpochId);
    event ChainHashUpdated(string indexed stationId, bytes32 newHash, bytes32 prevHash);

    constructor(address _admin, address[] memory _initialTechTeam, address[] memory _initialSettlementMultisig)
        EIP712("AGV Oracle", "1") // EIP-712 Domain: name="AGV Oracle", version="1", chainId, verifyingContract
    {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(SETTLEMENT_MULTISIG, _admin); // Grant admin the multisig role for initial setup

        // Grant initial roles
        for (uint256 i = 0; i < _initialTechTeam.length; i++) {
            _grantRole(ORACLE_TEAM, _initialTechTeam[i]);
        }
        for (uint256 i = 0; i < _initialSettlementMultisig.length; i++) {
            // For a real multisig, this address would be the Gnosis/Safe contract address
            _grantRole(SETTLEMENT_MULTISIG, _initialSettlementMultisig[i]);
        }
    }

    /**
     * @notice Stores a daily power generation snapshot with Bitcoin-style chain linking.
     * @param data The DailySnapshot EIP-712 data payload.
     * @param signature The EIP-712 signature of the data.
     * @param prevHash The expected current chain head hash (bytes32(0) for genesis).
     */
    function storeDailySnapshot(DailySnapshotEIP712 calldata data, bytes calldata signature, bytes32 prevHash)
        external
        whenNotPaused
        onlyRole(ORACLE_TEAM)
    {
        // 0. Station must be Active
        require(
            stationRegistry[data.stationId].status == StationStatus.Active,
            "Station not active"
        );

        // 1. Chain hash verification — prevHash must match current chain head
        require(
            prevHash == latestSnapshotHash[data.stationId],
            "Chain hash mismatch"
        );

        // 2. Recover EIP-712 Signer
        bytes32 structHash = keccak256(
            abi.encode(
                DAILY_SNAPSHOT_TYPEHASH,
                keccak256(bytes(data.date)),
                keccak256(bytes(data.stationId)),
                data.solarKWhSum_x10,
                data.selfConsumedKWh_x10,
                data.computeHoursSum_x10,
                data.records,
                data.sheetSha256
            )
        );
        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = digest.recover(signature);
        require(signer != address(0), "Invalid signature or signer");

        // 3. Validate/Store
        require(data.records == 96, "Records must be 96");

        // Enforce immutability for a given date/station
        require(dailySnapshots[data.stationId][data.date].sheetSha256 == bytes32(0), "Daily snapshot already stored");

        dailySnapshots[data.stationId][data.date] = DailySnapshotData({
            solarKWhSum_x10: data.solarKWhSum_x10,
            selfConsumedKWh_x10: data.selfConsumedKWh_x10,
            computeHoursSum_x10: data.computeHoursSum_x10,
            records: data.records,
            sheetSha256: data.sheetSha256,
            signer: signer
        });

        // 4. Update chain hash — Bitcoin-style linking
        bytes32 newChainHash = keccak256(abi.encodePacked(digest, prevHash));
        latestSnapshotHash[data.stationId] = newChainHash;
        latestSnapshotDate[data.stationId] = data.date;

        // 5. Emit events
        emit DailySnapshotStored(
            digest,
            data.date,
            data.stationId,
            data.solarKWhSum_x10,
            data.selfConsumedKWh_x10,
            data.computeHoursSum_x10,
            data.records,
            data.sheetSha256,
            signer
        );

        emit ChainHashUpdated(data.stationId, newChainHash, prevHash);
    }

    /**
     * @notice Stores a monthly settlement. This is the sole minting anchor.
     * @param period The month in "YYYY-MM" format.
     * @param stationId The unique station ID.
     * @param gridDeliveredKWh_x10 State Grid billed energy (kWh*10).
     * @param selfConsumedKWh_x10 Monthly self-consumption (disclosure only, kWh*10).
     * @param tariff_bp Monthly tariff (tariff*10000).
     * @param monthFilesAggSha256 SHA-256 of all daily CSV hashes aggregated.
     * @param settlementPdfSha256 SHA-256 of the State Grid bill PDF (Audit Master).
     * @param bankSlipSha256 SHA-256 of the bank receipt PDF (Optional).
     */
    function storeMonthlySettlement(
        string calldata period,
        string calldata stationId,
        uint256 gridDeliveredKWh_x10,
        uint256 selfConsumedKWh_x10,
        uint256 tariff_bp,
        bytes32 monthFilesAggSha256,
        bytes32 settlementPdfSha256,
        bytes32 bankSlipSha256
    )
        external
        whenNotPaused
        onlyRole(SETTLEMENT_MULTISIG) // Multisig-gated (Finance + Tech)
    {
        uint8 currentRevision = effectiveRevision[stationId][period];
        require(currentRevision == 0, "Initial settlement already stored. Use amendMonthlySettlement.");

        uint8 newRevision = 1; // Starts from 1

        // Store settlement
        monthlySettlements[stationId][period][newRevision] = MonthlySettlementData({
            gridDeliveredKWh_x10: gridDeliveredKWh_x10,
            selfConsumedKWh_x10: selfConsumedKWh_x10,
            tariff_bp: tariff_bp,
            monthFilesAggSha256: monthFilesAggSha256,
            settlementPdfSha256: settlementPdfSha256,
            bankSlipSha256: bankSlipSha256,
            revision: newRevision,
            timestamp: block.timestamp,
            reconciler: msg.sender
        });

        effectiveRevision[stationId][period] = newRevision;

        // Emit event
        emit MonthlySettlementStored(
            period,
            stationId,
            gridDeliveredKWh_x10,
            selfConsumedKWh_x10,
            tariff_bp,
            monthFilesAggSha256,
            settlementPdfSha256,
            bankSlipSha256,
            newRevision,
            msg.sender
        );
    }

    /**
     * @notice Allows revision of a monthly settlement with fully preserved history.
     * @param period The month in "YYYY-MM" format.
     * @param stationId The unique station ID.
     * @param reason The reason for the amendment (e.g., red invoice, supplement, cross-period correction).
     * @param gridDeliveredKWh_x10 Revised State Grid billed energy (kWh*10).
     * @param selfConsumedKWh_x10 Revised Monthly self-consumption (disclosure only, kWh*10).
     * @param tariff_bp Revised Monthly tariff (tariff*10000).
     * @param monthFilesAggSha256 Revised SHA-256 of all daily CSV hashes aggregated (if underlying data changed).
     * @param settlementPdfSha256 Revised SHA-256 of the State Grid bill PDF (new audit master).
     * @param bankSlipSha256 Revised SHA-256 of the bank receipt PDF (Optional).
     */
    function amendMonthlySettlement(
        string calldata period,
        string calldata stationId,
        string calldata reason,
        uint256 gridDeliveredKWh_x10,
        uint256 selfConsumedKWh_x10,
        uint256 tariff_bp,
        bytes32 monthFilesAggSha256,
        bytes32 settlementPdfSha256,
        bytes32 bankSlipSha256
    )
        external
        whenNotPaused
        onlyRole(SETTLEMENT_MULTISIG) // Multisig-gated
    {
        uint8 oldRevision = effectiveRevision[stationId][period];
        require(oldRevision > 0, "No initial settlement to amend.");
        require(oldRevision < type(uint8).max, "Max revision reached");

        uint8 newRevision = oldRevision + 1; // Revision auto-increments

        // Store new settlement data
        monthlySettlements[stationId][period][newRevision] = MonthlySettlementData({
            gridDeliveredKWh_x10: gridDeliveredKWh_x10,
            selfConsumedKWh_x10: selfConsumedKWh_x10,
            tariff_bp: tariff_bp,
            monthFilesAggSha256: monthFilesAggSha256,
            settlementPdfSha256: settlementPdfSha256,
            bankSlipSha256: bankSlipSha256,
            revision: newRevision,
            timestamp: block.timestamp,
            reconciler: msg.sender
        });

        effectiveRevision[stationId][period] = newRevision; // Latest revision is effective

        // Emit amendment event
        emit MonthlySettlementAmended(period, stationId, oldRevision, newRevision, reason);

        // Emit new settlement event for the latest data
        emit MonthlySettlementStored(
            period,
            stationId,
            gridDeliveredKWh_x10,
            selfConsumedKWh_x10,
            tariff_bp,
            monthFilesAggSha256,
            settlementPdfSha256,
            bankSlipSha256,
            newRevision,
            msg.sender
        );
    }

    // --- Station Management (P0 Extension) ---

    /**
     * @notice Registers a new station. Only ORACLE_TEAM can call.
     * @param stationId Unique station identifier.
     */
    function registerStation(string calldata stationId) external onlyRole(ORACLE_TEAM) {
        require(
            stationRegistry[stationId].status == StationStatus.Unregistered,
            "Station already registered"
        );

        stationRegistry[stationId] = StationInfo({
            status: StationStatus.Active,
            registeredAt: block.timestamp,
            suspendedAt: 0,
            purgedAt: 0,
            epochId: 0
        });

        emit StationRegistered(stationId, block.timestamp);
    }

    /**
     * @notice Suspends an active station. Chain is frozen but preserved.
     * @param stationId Unique station identifier.
     */
    function suspendStation(string calldata stationId) external onlyRole(ORACLE_TEAM) {
        StationInfo storage info = stationRegistry[stationId];
        require(info.status == StationStatus.Active, "Station not active");

        info.status = StationStatus.Suspended;
        info.suspendedAt = block.timestamp;

        emit StationSuspended(stationId, block.timestamp);
    }

    /**
     * @notice Permanently purges a station. Irreversible.
     * @param stationId Unique station identifier.
     */
    function purgeStation(string calldata stationId) external onlyRole(ORACLE_TEAM) {
        StationInfo storage info = stationRegistry[stationId];
        require(
            info.status == StationStatus.Active || info.status == StationStatus.Suspended,
            "Station not active or suspended"
        );

        info.status = StationStatus.Purged;
        info.purgedAt = block.timestamp;

        emit StationPurged(stationId, block.timestamp);
    }

    /**
     * @notice Reactivates a suspended station with a new epoch. Old chain is sealed.
     * @param stationId Unique station identifier.
     */
    function reactivateStation(string calldata stationId) external onlyRole(ORACLE_TEAM) {
        StationInfo storage info = stationRegistry[stationId];
        require(info.status == StationStatus.Suspended, "Station not suspended");

        info.status = StationStatus.Active;
        info.suspendedAt = 0;
        info.epochId += 1;

        // Reset chain head — new epoch starts from genesis
        latestSnapshotHash[stationId] = bytes32(0);
        latestSnapshotDate[stationId] = "";

        emit StationReactivated(stationId, info.epochId);
    }

    // --- Views (IAGVOracle interface) ---
    /**
     * @notice Returns the current effective revision of the monthly settlement for a given period and station.
     * @param period The month in "YYYY-MM" format.
     * @param stationId The unique station ID.
     * @return data The full MonthlySettlementData, including the revision.
     */
    function getEffectiveMonthlySettlement(string calldata period, string calldata stationId)
        external
        view
        returns (MonthlySettlementData memory data)
    {
        uint8 currentRevision = effectiveRevision[stationId][period];
        require(currentRevision > 0, "No settlement found for this period/station.");
        return monthlySettlements[stationId][period][currentRevision];
    }

    /**
     * @notice Gets a specific revision of the monthly settlement (for history queryable).
     */
    function getMonthlySettlementByRevision(string calldata period, string calldata stationId, uint8 revision)
        external
        view
        returns (MonthlySettlementData memory data)
    {
        require(revision > 0, "Revision must be greater than 0.");
        data = monthlySettlements[stationId][period][revision];
        require(data.revision == revision, "Revision not found.");
        return data;
    }

    /**
     * @notice Returns full station info including status, timestamps, and epoch.
     * @param stationId Unique station identifier.
     */
    function getStationInfo(string calldata stationId)
        external
        view
        returns (StationInfo memory)
    {
        return stationRegistry[stationId];
    }

    // --- AccessControl/Pausable Helpers ---
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
