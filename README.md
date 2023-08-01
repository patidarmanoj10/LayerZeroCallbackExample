# LayerZeroCallBackExample

This is POC about how to use Layerzero bridge to send callback cross chain. The PingPong contract send message to destination chain. 
When destination chain receive message from bridge then it send back acknowledgement to source chain.
Caller pays the gas cost in native token on source destination. This fee includes the gas cost of source chain, 
destination chain and callback of source chain.

Tx1: Chain A - Send payload to chain B.

Tx2: Chain B - Receive payload, update status and send callback to chain A

Tx3: Chain A - Receive callback and update status
## Steps:

1. Get estimation of callback native fee. Call `estimateCallbackFee()` on destination chain.
2. Get estimation of native fee of ping(). Call `estimatePingFee()` on source chain.
3. Execute `ping()`. Make sure to supply estimated native fee.
4. After couple of minutes, check status on destination chain. Read `pingPong.received(nonce)`. Once messaged receive, it will trigger callback to source chain.
5. After couple of minutes , check status on source chain. Read `pingPong.sent(nonce)`; Once callback is received status will be updated in this contract.


## Deployed contracts:
```
Mainnet: 0x83415985AFAda556689b1675cB468B9390b2db67
Optimism: 0xF708bc4a9a8fa089D5bb0558Eb6ac581b63658D1
```

