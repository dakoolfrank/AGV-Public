// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/AGVOracle.sol";

contract AGVOracleTest is Test {
    AGVOracle public oracle;

    // Test accounts
    address public admin;
    address public techTeam1;
    address public techTeam2;
    address public settlementMultisig1;
    address public settlementMultisig2;
    address public unauthorized;

    // Private keys for EIP-712 signing
    uint256 public techTeam1PK = 0x1234;
    uint256 public techTeam2PK = 0x5678;

    // Role constants
    bytes32 public constant SETTLEMENT_MULTISIG = keccak256("SETTLEMENT_MULTISIG");
    bytes32 public constant ORACLE_TEAM = keccak256("ORACLE_TEAM");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    // EIP-712 constants
    bytes32 public constant DAILY_SNAPSHOT_TYPEHASH = keccak256(
        "DailySnapshot(string date,string stationId,uint256 solarKWhSum_x10,uint256 selfConsumedKWh_x10,uint256 computeHoursSum_x10,uint16 records,bytes32 sheetSha256)"
    );

    function setUp() public {
        admin = makeAddr("admin");
        techTeam1 = vm.addr(techTeam1PK);
        techTeam2 = vm.addr(techTeam2PK);
        settlementMultisig1 = makeAddr("settlementMultisig1");
        settlementMultisig2 = makeAddr("settlementMultisig2");
        unauthorized = makeAddr("unauthorized");

        address[] memory initialTechTeam = new address[](2);
        initialTechTeam[0] = techTeam1;
        initialTechTeam[1] = techTeam2;

        address[] memory initialSettlementMultisig = new address[](2);
        initialSettlementMultisig[0] = settlementMultisig1;
        initialSettlementMultisig[1] = settlementMultisig2;

        vm.prank(admin);
        oracle = new AGVOracle(admin, initialTechTeam, initialSettlementMultisig);
    }

    // --- Helpers ---

    function computeDigest(AGVOracle.DailySnapshotEIP712 memory data) internal view returns (bytes32) {
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
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("AGV Oracle"),
                keccak256("1"),
                block.chainid,
                address(oracle)
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function signDailySnapshot(uint256 privateKey, AGVOracle.DailySnapshotEIP712 memory data)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = computeDigest(data);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function computeChainHash(bytes32 digest, bytes32 prevHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(digest, prevHash));
    }

    // ============ Constructor Tests ============

    function test_Constructor_Success() public view {
        assertTrue(oracle.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertTrue(oracle.hasRole(SETTLEMENT_MULTISIG, admin));
        assertTrue(oracle.hasRole(ORACLE_TEAM, techTeam1));
        assertTrue(oracle.hasRole(ORACLE_TEAM, techTeam2));
        assertTrue(oracle.hasRole(SETTLEMENT_MULTISIG, settlementMultisig1));
        assertTrue(oracle.hasRole(SETTLEMENT_MULTISIG, settlementMultisig2));
    }

    // ============ Station Registry Tests ============

    function test_RegisterStation_Success() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        AGVOracle.StationInfo memory info = oracle.getStationInfo("STATION-001");
        assertEq(uint8(info.status), uint8(AGVOracle.StationStatus.Active));
        assertGt(info.registeredAt, 0);
        assertEq(info.suspendedAt, 0);
        assertEq(info.purgedAt, 0);
        assertEq(info.epochId, 0);
    }

    function test_RegisterStation_RevertIfAlreadyRegistered() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        vm.prank(techTeam1);
        vm.expectRevert("Station already registered");
        oracle.registerStation("STATION-001");
    }

    function test_RegisterStation_RevertIfNotOracleTeam() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        oracle.registerStation("STATION-001");
    }

    function test_RegisterStation_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit AGVOracle.StationRegistered("STATION-001", block.timestamp);

        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");
    }

    function test_SuspendStation_Success() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        vm.prank(techTeam1);
        oracle.suspendStation("STATION-001");

        AGVOracle.StationInfo memory info = oracle.getStationInfo("STATION-001");
        assertEq(uint8(info.status), uint8(AGVOracle.StationStatus.Suspended));
        assertGt(info.suspendedAt, 0);
    }

    function test_SuspendStation_RevertIfNotActive() public {
        vm.prank(techTeam1);
        vm.expectRevert("Station not active");
        oracle.suspendStation("STATION-001");
    }

    function test_SuspendStation_EmitsEvent() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        vm.expectEmit(true, false, false, true);
        emit AGVOracle.StationSuspended("STATION-001", block.timestamp);

        vm.prank(techTeam1);
        oracle.suspendStation("STATION-001");
    }

    function test_PurgeStation_FromActive() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        vm.prank(techTeam1);
        oracle.purgeStation("STATION-001");

        AGVOracle.StationInfo memory info = oracle.getStationInfo("STATION-001");
        assertEq(uint8(info.status), uint8(AGVOracle.StationStatus.Purged));
        assertGt(info.purgedAt, 0);
    }

    function test_PurgeStation_FromSuspended() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        vm.prank(techTeam1);
        oracle.suspendStation("STATION-001");

        vm.prank(techTeam1);
        oracle.purgeStation("STATION-001");

        AGVOracle.StationInfo memory info = oracle.getStationInfo("STATION-001");
        assertEq(uint8(info.status), uint8(AGVOracle.StationStatus.Purged));
    }

    function test_PurgeStation_RevertIfUnregistered() public {
        vm.prank(techTeam1);
        vm.expectRevert("Station not active or suspended");
        oracle.purgeStation("STATION-001");
    }

    function test_PurgeStation_RevertIfAlreadyPurged() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        vm.prank(techTeam1);
        oracle.purgeStation("STATION-001");

        vm.prank(techTeam1);
        vm.expectRevert("Station not active or suspended");
        oracle.purgeStation("STATION-001");
    }

    function test_PurgeStation_EmitsEvent() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        vm.expectEmit(true, false, false, true);
        emit AGVOracle.StationPurged("STATION-001", block.timestamp);

        vm.prank(techTeam1);
        oracle.purgeStation("STATION-001");
    }

    function test_ReactivateStation_Success() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        vm.prank(techTeam1);
        oracle.suspendStation("STATION-001");

        vm.prank(techTeam1);
        oracle.reactivateStation("STATION-001");

        AGVOracle.StationInfo memory info = oracle.getStationInfo("STATION-001");
        assertEq(uint8(info.status), uint8(AGVOracle.StationStatus.Active));
        assertEq(info.suspendedAt, 0);
        assertEq(info.epochId, 1);
    }

    function test_ReactivateStation_RevertIfNotSuspended() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        vm.prank(techTeam1);
        vm.expectRevert("Station not suspended");
        oracle.reactivateStation("STATION-001");
    }

    function test_ReactivateStation_RevertIfPurged() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        vm.prank(techTeam1);
        oracle.purgeStation("STATION-001");

        vm.prank(techTeam1);
        vm.expectRevert("Station not suspended");
        oracle.reactivateStation("STATION-001");
    }

    function test_ReactivateStation_ResetsChainHash() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        AGVOracle.DailySnapshotEIP712 memory data = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-001",
            solarKWhSum_x10: 5000,
            selfConsumedKWh_x10: 1000,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("test-sheet-data")
        });
        bytes memory signature = signDailySnapshot(techTeam1PK, data);

        vm.prank(techTeam1);
        oracle.storeDailySnapshot(data, signature, bytes32(0));

        bytes32 hashBefore = oracle.latestSnapshotHash("STATION-001");
        assertTrue(hashBefore != bytes32(0));

        vm.prank(techTeam1);
        oracle.suspendStation("STATION-001");

        vm.prank(techTeam1);
        oracle.reactivateStation("STATION-001");

        bytes32 hashAfter = oracle.latestSnapshotHash("STATION-001");
        assertEq(hashAfter, bytes32(0));
    }

    function test_ReactivateStation_EpochIncrements() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        vm.prank(techTeam1);
        oracle.suspendStation("STATION-001");
        vm.prank(techTeam1);
        oracle.reactivateStation("STATION-001");

        vm.prank(techTeam1);
        oracle.suspendStation("STATION-001");
        vm.prank(techTeam1);
        oracle.reactivateStation("STATION-001");

        AGVOracle.StationInfo memory info = oracle.getStationInfo("STATION-001");
        assertEq(info.epochId, 2);
    }

    function test_ReactivateStation_EmitsEvent() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        vm.prank(techTeam1);
        oracle.suspendStation("STATION-001");

        vm.expectEmit(true, false, false, true);
        emit AGVOracle.StationReactivated("STATION-001", 1);

        vm.prank(techTeam1);
        oracle.reactivateStation("STATION-001");
    }

    // ============ Daily Snapshot Tests ============

    function test_StoreDailySnapshot_Success() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        AGVOracle.DailySnapshotEIP712 memory data = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-001",
            solarKWhSum_x10: 5000,
            selfConsumedKWh_x10: 1000,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("test-sheet-data")
        });

        bytes memory signature = signDailySnapshot(techTeam1PK, data);

        vm.prank(techTeam1);
        oracle.storeDailySnapshot(data, signature, bytes32(0));

        (
            uint256 solarKWh,
            uint256 selfConsumed,
            uint256 computeHours,
            uint16 records,
            bytes32 sheetHash,
            address signer
        ) = oracle.dailySnapshots(data.stationId, data.date);

        assertEq(solarKWh, data.solarKWhSum_x10);
        assertEq(selfConsumed, data.selfConsumedKWh_x10);
        assertEq(computeHours, data.computeHoursSum_x10);
        assertEq(records, data.records);
        assertEq(sheetHash, data.sheetSha256);
        assertEq(signer, techTeam1);
    }

    function test_StoreDailySnapshot_RevertIfNotOracleTeam() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        AGVOracle.DailySnapshotEIP712 memory data = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-001",
            solarKWhSum_x10: 5000,
            selfConsumedKWh_x10: 1000,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("test-sheet-data")
        });

        bytes memory signature = signDailySnapshot(techTeam1PK, data);

        vm.prank(unauthorized);
        vm.expectRevert();
        oracle.storeDailySnapshot(data, signature, bytes32(0));
    }

    function test_StoreDailySnapshot_RevertIfRecordsNot96() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        AGVOracle.DailySnapshotEIP712 memory data = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-001",
            solarKWhSum_x10: 5000,
            selfConsumedKWh_x10: 1000,
            computeHoursSum_x10: 240,
            records: 95,
            sheetSha256: keccak256("test-sheet-data")
        });

        bytes memory signature = signDailySnapshot(techTeam1PK, data);

        vm.prank(techTeam1);
        vm.expectRevert("Records must be 96");
        oracle.storeDailySnapshot(data, signature, bytes32(0));
    }

    function test_StoreDailySnapshot_RevertIfAlreadyStored() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        AGVOracle.DailySnapshotEIP712 memory data = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-001",
            solarKWhSum_x10: 5000,
            selfConsumedKWh_x10: 1000,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("test-sheet-data")
        });

        bytes memory signature = signDailySnapshot(techTeam1PK, data);

        vm.prank(techTeam1);
        oracle.storeDailySnapshot(data, signature, bytes32(0));

        bytes32 chainHash = oracle.latestSnapshotHash("STATION-001");

        vm.prank(techTeam1);
        vm.expectRevert("Daily snapshot already stored");
        oracle.storeDailySnapshot(data, signature, chainHash);
    }

    function test_StoreDailySnapshot_RevertIfInvalidSignature() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        AGVOracle.DailySnapshotEIP712 memory data = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-001",
            solarKWhSum_x10: 5000,
            selfConsumedKWh_x10: 1000,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("test-sheet-data")
        });

        bytes memory invalidSignature = new bytes(65);

        vm.prank(techTeam1);
        vm.expectRevert();
        oracle.storeDailySnapshot(data, invalidSignature, bytes32(0));
    }

    function test_StoreDailySnapshot_RevertIfStationNotActive() public {
        AGVOracle.DailySnapshotEIP712 memory data = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-001",
            solarKWhSum_x10: 5000,
            selfConsumedKWh_x10: 1000,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("test-sheet-data")
        });

        bytes memory signature = signDailySnapshot(techTeam1PK, data);

        vm.prank(techTeam1);
        vm.expectRevert("Station not active");
        oracle.storeDailySnapshot(data, signature, bytes32(0));
    }

    function test_StoreDailySnapshot_RevertIfStationSuspended() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        vm.prank(techTeam1);
        oracle.suspendStation("STATION-001");

        AGVOracle.DailySnapshotEIP712 memory data = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-001",
            solarKWhSum_x10: 5000,
            selfConsumedKWh_x10: 1000,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("test-sheet-data")
        });

        bytes memory signature = signDailySnapshot(techTeam1PK, data);

        vm.prank(techTeam1);
        vm.expectRevert("Station not active");
        oracle.storeDailySnapshot(data, signature, bytes32(0));
    }

    function test_StoreDailySnapshot_RevertIfStationPurged() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        vm.prank(techTeam1);
        oracle.purgeStation("STATION-001");

        AGVOracle.DailySnapshotEIP712 memory data = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-001",
            solarKWhSum_x10: 5000,
            selfConsumedKWh_x10: 1000,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("test-sheet-data")
        });

        bytes memory signature = signDailySnapshot(techTeam1PK, data);

        vm.prank(techTeam1);
        vm.expectRevert("Station not active");
        oracle.storeDailySnapshot(data, signature, bytes32(0));
    }

    function test_StoreDailySnapshot_MultipleStations() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");
        vm.prank(techTeam1);
        oracle.registerStation("STATION-002");

        AGVOracle.DailySnapshotEIP712 memory data1 = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-001",
            solarKWhSum_x10: 5000,
            selfConsumedKWh_x10: 1000,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("test-sheet-data-1")
        });

        bytes memory signature1 = signDailySnapshot(techTeam1PK, data1);

        vm.prank(techTeam1);
        oracle.storeDailySnapshot(data1, signature1, bytes32(0));

        AGVOracle.DailySnapshotEIP712 memory data2 = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-002",
            solarKWhSum_x10: 3000,
            selfConsumedKWh_x10: 500,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("test-sheet-data-2")
        });

        bytes memory signature2 = signDailySnapshot(techTeam1PK, data2);

        vm.prank(techTeam1);
        oracle.storeDailySnapshot(data2, signature2, bytes32(0));

        (,,,, bytes32 hash1,) = oracle.dailySnapshots("STATION-001", "2025-01-15");
        (,,,, bytes32 hash2,) = oracle.dailySnapshots("STATION-002", "2025-01-15");

        assertEq(hash1, keccak256("test-sheet-data-1"));
        assertEq(hash2, keccak256("test-sheet-data-2"));
    }

    // ============ Chain Hash Tests ============

    function test_ChainHash_Genesis() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        AGVOracle.DailySnapshotEIP712 memory data = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-001",
            solarKWhSum_x10: 5000,
            selfConsumedKWh_x10: 1000,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("test-sheet-data")
        });

        bytes memory signature = signDailySnapshot(techTeam1PK, data);
        bytes32 digest = computeDigest(data);
        bytes32 expectedChainHash = computeChainHash(digest, bytes32(0));

        vm.prank(techTeam1);
        oracle.storeDailySnapshot(data, signature, bytes32(0));

        assertEq(oracle.latestSnapshotHash("STATION-001"), expectedChainHash);
        assertEq(oracle.latestSnapshotDate("STATION-001"), "2025-01-15");
    }

    function test_ChainHash_Sequential() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        // Day 1 (genesis)
        AGVOracle.DailySnapshotEIP712 memory data1 = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-001",
            solarKWhSum_x10: 5000,
            selfConsumedKWh_x10: 1000,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("day1-data")
        });

        bytes memory sig1 = signDailySnapshot(techTeam1PK, data1);
        bytes32 digest1 = computeDigest(data1);

        vm.prank(techTeam1);
        oracle.storeDailySnapshot(data1, sig1, bytes32(0));

        bytes32 chainHash1 = computeChainHash(digest1, bytes32(0));
        assertEq(oracle.latestSnapshotHash("STATION-001"), chainHash1);

        // Day 2 (linked to day 1)
        AGVOracle.DailySnapshotEIP712 memory data2 = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-16",
            stationId: "STATION-001",
            solarKWhSum_x10: 4800,
            selfConsumedKWh_x10: 900,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("day2-data")
        });

        bytes memory sig2 = signDailySnapshot(techTeam1PK, data2);
        bytes32 digest2 = computeDigest(data2);

        vm.prank(techTeam1);
        oracle.storeDailySnapshot(data2, sig2, chainHash1);

        bytes32 chainHash2 = computeChainHash(digest2, chainHash1);
        assertEq(oracle.latestSnapshotHash("STATION-001"), chainHash2);
        assertEq(oracle.latestSnapshotDate("STATION-001"), "2025-01-16");

        // Day 3 (linked to day 2)
        AGVOracle.DailySnapshotEIP712 memory data3 = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-17",
            stationId: "STATION-001",
            solarKWhSum_x10: 5100,
            selfConsumedKWh_x10: 1100,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("day3-data")
        });

        bytes memory sig3 = signDailySnapshot(techTeam1PK, data3);
        bytes32 digest3 = computeDigest(data3);

        vm.prank(techTeam1);
        oracle.storeDailySnapshot(data3, sig3, chainHash2);

        bytes32 chainHash3 = computeChainHash(digest3, chainHash2);
        assertEq(oracle.latestSnapshotHash("STATION-001"), chainHash3);
    }

    function test_ChainHash_RevertIfMismatch() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        AGVOracle.DailySnapshotEIP712 memory data1 = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-001",
            solarKWhSum_x10: 5000,
            selfConsumedKWh_x10: 1000,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("day1-data")
        });

        bytes memory sig1 = signDailySnapshot(techTeam1PK, data1);

        vm.prank(techTeam1);
        oracle.storeDailySnapshot(data1, sig1, bytes32(0));

        AGVOracle.DailySnapshotEIP712 memory data2 = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-16",
            stationId: "STATION-001",
            solarKWhSum_x10: 4800,
            selfConsumedKWh_x10: 900,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("day2-data")
        });

        bytes memory sig2 = signDailySnapshot(techTeam1PK, data2);

        bytes32 wrongPrevHash = keccak256("fake-hash");
        vm.prank(techTeam1);
        vm.expectRevert("Chain hash mismatch");
        oracle.storeDailySnapshot(data2, sig2, wrongPrevHash);
    }

    function test_ChainHash_NewEpochGenesis() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        AGVOracle.DailySnapshotEIP712 memory data1 = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-001",
            solarKWhSum_x10: 5000,
            selfConsumedKWh_x10: 1000,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("epoch0-data")
        });

        bytes memory sig1 = signDailySnapshot(techTeam1PK, data1);

        vm.prank(techTeam1);
        oracle.storeDailySnapshot(data1, sig1, bytes32(0));

        vm.prank(techTeam1);
        oracle.suspendStation("STATION-001");
        vm.prank(techTeam1);
        oracle.reactivateStation("STATION-001");

        AGVOracle.DailySnapshotEIP712 memory data2 = AGVOracle.DailySnapshotEIP712({
            date: "2025-02-01",
            stationId: "STATION-001",
            solarKWhSum_x10: 4500,
            selfConsumedKWh_x10: 800,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("epoch1-data")
        });

        bytes memory sig2 = signDailySnapshot(techTeam1PK, data2);
        bytes32 digest2 = computeDigest(data2);

        vm.prank(techTeam1);
        oracle.storeDailySnapshot(data2, sig2, bytes32(0));

        bytes32 expectedHash = computeChainHash(digest2, bytes32(0));
        assertEq(oracle.latestSnapshotHash("STATION-001"), expectedHash);

        AGVOracle.StationInfo memory info = oracle.getStationInfo("STATION-001");
        assertEq(info.epochId, 1);
    }

    function test_ChainHash_IndependentPerStation() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");
        vm.prank(techTeam1);
        oracle.registerStation("STATION-002");

        AGVOracle.DailySnapshotEIP712 memory data1 = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-001",
            solarKWhSum_x10: 5000,
            selfConsumedKWh_x10: 1000,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("station1-data")
        });

        bytes memory sig1 = signDailySnapshot(techTeam1PK, data1);

        vm.prank(techTeam1);
        oracle.storeDailySnapshot(data1, sig1, bytes32(0));

        bytes32 hash1 = oracle.latestSnapshotHash("STATION-001");
        bytes32 hash2 = oracle.latestSnapshotHash("STATION-002");

        assertTrue(hash1 != bytes32(0));
        assertEq(hash2, bytes32(0));
    }

    function test_ChainHash_EmitsEvent() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        AGVOracle.DailySnapshotEIP712 memory data = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-001",
            solarKWhSum_x10: 5000,
            selfConsumedKWh_x10: 1000,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("test-sheet-data")
        });

        bytes memory signature = signDailySnapshot(techTeam1PK, data);
        bytes32 digest = computeDigest(data);
        bytes32 expectedChainHash = computeChainHash(digest, bytes32(0));

        vm.expectEmit(true, false, false, true);
        emit AGVOracle.ChainHashUpdated("STATION-001", expectedChainHash, bytes32(0));

        vm.prank(techTeam1);
        oracle.storeDailySnapshot(data, signature, bytes32(0));
    }

    // ============ Monthly Settlement Tests ============

    function test_StoreMonthlySettlement_Success() public {
        vm.prank(settlementMultisig1);
        oracle.storeMonthlySettlement(
            "2025-01",
            "STATION-001",
            50000,
            10000,
            5000,
            keccak256("aggregated-hashes"),
            keccak256("settlement-pdf"),
            keccak256("bank-slip")
        );

        AGVOracle.MonthlySettlementData memory settlement =
            oracle.getEffectiveMonthlySettlement("2025-01", "STATION-001");

        assertEq(settlement.gridDeliveredKWh_x10, 50000);
        assertEq(settlement.selfConsumedKWh_x10, 10000);
        assertEq(settlement.tariff_bp, 5000);
        assertEq(settlement.revision, 1);
        assertEq(settlement.reconciler, settlementMultisig1);
    }

    function test_StoreMonthlySettlement_RevertIfNotSettlementMultisig() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        oracle.storeMonthlySettlement(
            "2025-01",
            "STATION-001",
            50000,
            10000,
            5000,
            keccak256("aggregated-hashes"),
            keccak256("settlement-pdf"),
            keccak256("bank-slip")
        );
    }

    function test_StoreMonthlySettlement_RevertIfAlreadyStored() public {
        vm.prank(settlementMultisig1);
        oracle.storeMonthlySettlement(
            "2025-01",
            "STATION-001",
            50000,
            10000,
            5000,
            keccak256("aggregated-hashes"),
            keccak256("settlement-pdf"),
            keccak256("bank-slip")
        );

        vm.prank(settlementMultisig1);
        vm.expectRevert("Initial settlement already stored. Use amendMonthlySettlement.");
        oracle.storeMonthlySettlement(
            "2025-01",
            "STATION-001",
            60000,
            12000,
            5500,
            keccak256("new-aggregated-hashes"),
            keccak256("new-settlement-pdf"),
            keccak256("new-bank-slip")
        );
    }

    // ============ Amendment Tests ============

    function test_AmendMonthlySettlement_Success() public {
        vm.prank(settlementMultisig1);
        oracle.storeMonthlySettlement(
            "2025-01",
            "STATION-001",
            50000,
            10000,
            5000,
            keccak256("aggregated-hashes"),
            keccak256("settlement-pdf"),
            keccak256("bank-slip")
        );

        vm.prank(settlementMultisig2);
        oracle.amendMonthlySettlement(
            "2025-01",
            "STATION-001",
            "Red invoice correction",
            55000,
            11000,
            5200,
            keccak256("new-aggregated-hashes"),
            keccak256("new-settlement-pdf"),
            keccak256("new-bank-slip")
        );

        AGVOracle.MonthlySettlementData memory settlement =
            oracle.getEffectiveMonthlySettlement("2025-01", "STATION-001");

        assertEq(settlement.gridDeliveredKWh_x10, 55000);
        assertEq(settlement.revision, 2);
        assertEq(settlement.reconciler, settlementMultisig2);

        AGVOracle.MonthlySettlementData memory oldSettlement =
            oracle.getMonthlySettlementByRevision("2025-01", "STATION-001", 1);

        assertEq(oldSettlement.gridDeliveredKWh_x10, 50000);
        assertEq(oldSettlement.revision, 1);
    }

    function test_AmendMonthlySettlement_RevertIfNoInitialSettlement() public {
        vm.prank(settlementMultisig1);
        vm.expectRevert("No initial settlement to amend.");
        oracle.amendMonthlySettlement(
            "2025-01",
            "STATION-001",
            "Test amendment",
            55000,
            11000,
            5200,
            keccak256("new-aggregated-hashes"),
            keccak256("new-settlement-pdf"),
            keccak256("new-bank-slip")
        );
    }

    function test_AmendMonthlySettlement_MultipleAmendments() public {
        vm.prank(settlementMultisig1);
        oracle.storeMonthlySettlement(
            "2025-01", "STATION-001", 50000, 10000, 5000,
            keccak256("hash-v1"), keccak256("pdf-v1"), keccak256("slip-v1")
        );

        vm.prank(settlementMultisig1);
        oracle.amendMonthlySettlement(
            "2025-01", "STATION-001", "First correction", 51000, 10100, 5100,
            keccak256("hash-v2"), keccak256("pdf-v2"), keccak256("slip-v2")
        );

        vm.prank(settlementMultisig1);
        oracle.amendMonthlySettlement(
            "2025-01", "STATION-001", "Second correction", 52000, 10200, 5200,
            keccak256("hash-v3"), keccak256("pdf-v3"), keccak256("slip-v3")
        );

        AGVOracle.MonthlySettlementData memory current = oracle.getEffectiveMonthlySettlement("2025-01", "STATION-001");
        assertEq(current.revision, 3);
        assertEq(current.gridDeliveredKWh_x10, 52000);

        AGVOracle.MonthlySettlementData memory rev1 = oracle.getMonthlySettlementByRevision("2025-01", "STATION-001", 1);
        assertEq(rev1.gridDeliveredKWh_x10, 50000);

        AGVOracle.MonthlySettlementData memory rev2 = oracle.getMonthlySettlementByRevision("2025-01", "STATION-001", 2);
        assertEq(rev2.gridDeliveredKWh_x10, 51000);
    }

    function test_GetMonthlySettlementByRevision_RevertIfInvalidRevision() public {
        vm.prank(settlementMultisig1);
        oracle.storeMonthlySettlement(
            "2025-01", "STATION-001", 50000, 10000, 5000,
            keccak256("hash"), keccak256("pdf"), keccak256("slip")
        );

        vm.expectRevert("Revision not found.");
        oracle.getMonthlySettlementByRevision("2025-01", "STATION-001", 99);
    }

    // ============ Pausable Tests ============

    function test_Pause_Success() public {
        vm.prank(admin);
        oracle.pause();
        assertTrue(oracle.paused());
    }

    function test_Pause_RevertIfNotAdmin() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        oracle.pause();
    }

    function test_Unpause_Success() public {
        vm.prank(admin);
        oracle.pause();
        vm.prank(admin);
        oracle.unpause();
        assertFalse(oracle.paused());
    }

    function test_StoreDailySnapshot_RevertWhenPaused() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        vm.prank(admin);
        oracle.pause();

        AGVOracle.DailySnapshotEIP712 memory data = AGVOracle.DailySnapshotEIP712({
            date: "2025-01-15",
            stationId: "STATION-001",
            solarKWhSum_x10: 5000,
            selfConsumedKWh_x10: 1000,
            computeHoursSum_x10: 240,
            records: 96,
            sheetSha256: keccak256("test")
        });

        bytes memory signature = signDailySnapshot(techTeam1PK, data);

        vm.prank(techTeam1);
        vm.expectRevert();
        oracle.storeDailySnapshot(data, signature, bytes32(0));
    }

    function test_StoreMonthlySettlement_RevertWhenPaused() public {
        vm.prank(admin);
        oracle.pause();

        vm.prank(settlementMultisig1);
        vm.expectRevert();
        oracle.storeMonthlySettlement(
            "2025-01", "STATION-001", 50000, 10000, 5000,
            keccak256("hash"), keccak256("pdf"), keccak256("slip")
        );
    }

    // ============ Access Control Tests ============

    function test_GrantRole_Success() public {
        address newTechMember = makeAddr("newTechMember");
        vm.prank(admin);
        oracle.grantRole(ORACLE_TEAM, newTechMember);
        assertTrue(oracle.hasRole(ORACLE_TEAM, newTechMember));
    }

    function test_RevokeRole_Success() public {
        vm.prank(admin);
        oracle.revokeRole(ORACLE_TEAM, techTeam1);
        assertFalse(oracle.hasRole(ORACLE_TEAM, techTeam1));
    }

    function test_RenounceRole_Success() public {
        vm.prank(techTeam1);
        oracle.renounceRole(ORACLE_TEAM, techTeam1);
        assertFalse(oracle.hasRole(ORACLE_TEAM, techTeam1));
    }

    // ============ Edge Case Tests ============

    function test_ZeroValues_Allowed() public {
        vm.prank(settlementMultisig1);
        oracle.storeMonthlySettlement(
            "2025-01", "STATION-001", 0, 0, 0, bytes32(0), keccak256("pdf"), bytes32(0)
        );

        AGVOracle.MonthlySettlementData memory settlement =
            oracle.getEffectiveMonthlySettlement("2025-01", "STATION-001");
        assertEq(settlement.gridDeliveredKWh_x10, 0);
    }

    function test_DifferentPeriodsForSameStation() public {
        vm.prank(settlementMultisig1);
        oracle.storeMonthlySettlement(
            "2025-01", "STATION-001", 50000, 10000, 5000,
            keccak256("jan-hash"), keccak256("jan-pdf"), keccak256("jan-slip")
        );

        vm.prank(settlementMultisig1);
        oracle.storeMonthlySettlement(
            "2025-02", "STATION-001", 60000, 12000, 5500,
            keccak256("feb-hash"), keccak256("feb-pdf"), keccak256("feb-slip")
        );

        AGVOracle.MonthlySettlementData memory jan = oracle.getEffectiveMonthlySettlement("2025-01", "STATION-001");
        AGVOracle.MonthlySettlementData memory feb = oracle.getEffectiveMonthlySettlement("2025-02", "STATION-001");

        assertEq(jan.gridDeliveredKWh_x10, 50000);
        assertEq(feb.gridDeliveredKWh_x10, 60000);
    }

    // ============ GetStationInfo View Tests ============

    function test_GetStationInfo_Unregistered() public view {
        AGVOracle.StationInfo memory info = oracle.getStationInfo("NONEXISTENT");
        assertEq(uint8(info.status), uint8(AGVOracle.StationStatus.Unregistered));
        assertEq(info.registeredAt, 0);
        assertEq(info.epochId, 0);
    }

    function test_GetStationInfo_Active() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        AGVOracle.StationInfo memory info = oracle.getStationInfo("STATION-001");
        assertEq(uint8(info.status), uint8(AGVOracle.StationStatus.Active));
        assertGt(info.registeredAt, 0);
    }

    function test_GetStationInfo_FullLifecycle() public {
        vm.prank(techTeam1);
        oracle.registerStation("STATION-001");

        AGVOracle.StationInfo memory info1 = oracle.getStationInfo("STATION-001");
        assertEq(uint8(info1.status), uint8(AGVOracle.StationStatus.Active));
        assertEq(info1.epochId, 0);

        vm.prank(techTeam1);
        oracle.suspendStation("STATION-001");

        AGVOracle.StationInfo memory info2 = oracle.getStationInfo("STATION-001");
        assertEq(uint8(info2.status), uint8(AGVOracle.StationStatus.Suspended));
        assertGt(info2.suspendedAt, 0);

        vm.prank(techTeam1);
        oracle.reactivateStation("STATION-001");

        AGVOracle.StationInfo memory info3 = oracle.getStationInfo("STATION-001");
        assertEq(uint8(info3.status), uint8(AGVOracle.StationStatus.Active));
        assertEq(info3.epochId, 1);
        assertEq(info3.suspendedAt, 0);

        vm.prank(techTeam1);
        oracle.purgeStation("STATION-001");

        AGVOracle.StationInfo memory info4 = oracle.getStationInfo("STATION-001");
        assertEq(uint8(info4.status), uint8(AGVOracle.StationStatus.Purged));
        assertGt(info4.purgedAt, 0);
    }
}
