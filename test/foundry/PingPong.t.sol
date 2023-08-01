// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import {BytesLib} from "../../contracts/dependencies/@layerzerolabs/solidity-examples/util/BytesLib.sol";
import {LZEndpointMock, ILayerZeroEndpoint, ILayerZeroReceiver} from "../../contracts/mock/LZEndpointMock.sol";
import "../../contracts/PingPong.sol";

interface ILayerZeroEndpointExtended is ILayerZeroEndpoint {
    function defaultReceiveLibraryAddress() external view returns (address);
}

contract PingPong_Test is Test {
    using stdStorage for StdStorage;
    using BytesLib for bytes;

    uint16 public constant LZ_MAINNET_CHAIN_ID = 101;
    uint16 public constant LZ_OP_CHAIN_ID = 111;

    address feeCollector = address(999);
    address alice = address(10);
    address bob = address(20);
    PingPong pingPong_optimistic;
    PingPong pingPong_mainnet;

    uint256 mainnetFork;
    uint256 optimismFork;

    // Layer 2
    ILayerZeroEndpointExtended lzEndpoint_optimism =
        ILayerZeroEndpointExtended(0x3c2269811836af69497E5F486A85D7316753cf62);
    // Mainnet
    ILayerZeroEndpointExtended lzEndpoint_mainnet =
        ILayerZeroEndpointExtended(0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);

    function setUp() public {
        mainnetFork = vm.createSelectFork("https://eth-mainnet.alchemyapi.io/v2/NbZ2px662CNSwdw3ZxdaZNe31yZbyddK");
        vm.rollFork(mainnetFork, 17642438);
        optimismFork = vm.createSelectFork("https://optimism-mainnet.infura.io/v3/9989c2cf77a24bddaa43103463cb8047");
        vm.rollFork(optimismFork, 106576271);

        //
        // Layer 2
        //
        vm.selectFork(optimismFork);
        pingPong_optimistic = new PingPong(address(lzEndpoint_optimism));

        //
        // Mainnet
        //
        vm.selectFork(mainnetFork);
        pingPong_mainnet = new PingPong(address(lzEndpoint_mainnet));
        // pingPong_mainnet.setTrustedRemote(LZ_OP_CHAIN_ID, abi.encode(pingPong_optimistic));
        pingPong_mainnet.setTrustedRemoteAddress(LZ_OP_CHAIN_ID, abi.encodePacked(pingPong_optimistic));
        console.log("enter following to ping pong of OP");
        console.logBytes(abi.encodePacked(0x83415985AFAda556689b1675cB468B9390b2db67));

        console.log("enter following to ping pong of mainnet");
        console.logBytes(abi.encodePacked(0xF708bc4a9a8fa089D5bb0558Eb6ac581b63658D1));
        
        // Setup
        vm.selectFork(optimismFork);
        // pingPong_optimistic.setTrustedRemote(LZ_MAINNET_CHAIN_ID, abi.encode(pingPong_mainnet));
        pingPong_optimistic.setTrustedRemoteAddress(LZ_MAINNET_CHAIN_ID, abi.encodePacked(pingPong_mainnet));
    }

    function _readEvents()
        private
        returns (Vm.Log memory SendToChain, Vm.Log memory Packet, Vm.Log memory RelayerParams)
    {   
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory entry = entries[i];
            if (entry.topics[0] == keccak256("SendToChain(uint16,address,bytes)")) {
                SendToChain = entry;
            } else if (entry.topics[0] == keccak256("Packet(bytes)")) {
                Packet = entry;
            } else if (entry.topics[0] == keccak256("RelayerParams(bytes,uint16)")) {
                RelayerParams = entry;
            }
        }
    }

    function _receiveTx(Vm.Log memory SendToChainTx1, Vm.Log memory PacketTx1, Vm.Log memory RelayerParamsTx1, ILayerZeroEndpointExtended _endPoint, uint16 _sourceChainId) private {
        // Airdrop ETH
        // Note: Adapter params uses (uint16 version, uint256 gasAmount, uint256 nativeForDst, address addressOnDst)
        // See more: https://layerzero.gitbook.io/docs/evm-guides/advanced/relayer-adapter-parameters
        (bytes memory adapterParams, ) = abi.decode(RelayerParamsTx1.data, (bytes, uint16));
        console.logBytes(adapterParams);
        address toAddress = (abi.decode(SendToChainTx1.data, (bytes))).toAddress(0);
        uint16 version = adapterParams.toUint16(0);
        if(version == 2) {
        uint256 nativeForDst = adapterParams.toUint256(34);
        assertEq(toAddress.balance, 0);
        deal(toAddress, nativeForDst);
        }
   
        bytes memory from = abi.encodePacked(SendToChainTx1.topics[2]);
        uint64 nonce = _endPoint.getInboundNonce(_sourceChainId, from) + 1;
        // Note: Remove prefix added for `Packet` event
        // uint64 nonce, uint16 localChainId, address ua, uint16 dstChainId, bytes dstAddress, bytes payload
        // bytes memory encodedPayload = abi.encodePacked(nonce, localChainId, ua, dstChainId, dstAddress, payload);
        // emit Packet(encodedPayload);
        bytes memory encodedPayload = abi.decode(PacketTx1.data, (bytes));
        bytes memory payload = encodedPayload.slice(52, encodedPayload.length - 52);
        // (, , , , , uint64 _dstGasForCall) = abi.decode(payload, (uint16, bytes, bytes, uint256, bytes, uint64));
        //
        bytes memory path =  abi.encodePacked(abi.decode(from, (address)), toAddress);
        vm.prank(_endPoint.defaultReceiveLibraryAddress());
        _endPoint.receivePayload({
            _srcChainId: _sourceChainId,
            _srcAddress:path,
            _dstAddress: toAddress,
            _nonce: nonce,
            _gasLimit: 500_000,
            _payload: payload
        });
    }

    function test_pingPong() external {
        vm.selectFork(mainnetFork);
        (uint256 callbackFee, ) = pingPong_mainnet.estimateCallbackFee(LZ_OP_CHAIN_ID);

        vm.selectFork(optimismFork);
        (uint256 pingNativeFee, ) = pingPong_optimistic.estimatePingFee(LZ_MAINNET_CHAIN_ID, callbackFee);

        deal(alice, pingNativeFee);
        vm.startPrank(alice);
        vm.recordLogs();
        pingPong_optimistic.ping{value: pingNativeFee}(LZ_MAINNET_CHAIN_ID, callbackFee);
       //  vm.stopPrank();
        console.log("fetching log of op");
        (Vm.Log memory SendToChain, Vm.Log memory Packet, Vm.Log memory RelayerParams) = _readEvents();
        
        vm.selectFork(mainnetFork);
         vm.recordLogs();
        _receiveTx(SendToChain, Packet, RelayerParams, lzEndpoint_mainnet, LZ_OP_CHAIN_ID);
        console.log("calling received of mainnet");
        vm.selectFork(optimismFork);
        
        vm.selectFork(optimismFork);
        console.log("calling received of OP");
        (SendToChain, Packet, RelayerParams) = _readEvents();
        _receiveTx(SendToChain, Packet, RelayerParams, lzEndpoint_optimism, LZ_MAINNET_CHAIN_ID);

        (bool sent, bool receivedCallback) = pingPong_optimistic.sent(pingPong_optimistic.nonce());

        assertEq(sent, true);
        assertEq(receivedCallback, true);
    }
}
