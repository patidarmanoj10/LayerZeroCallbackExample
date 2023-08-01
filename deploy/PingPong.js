const LZ_ENDPOINTS = require("../constants/layerzeroEndpoints.json")

module.exports = async function ({ deployments, getNamedAccounts }) {
    const owner = (await ethers.getSigners())[0]
    const { deploy } = deployments
    console.log("getNamedAccounts", getNamedAccounts)
    const { deployer } = await getNamedAccounts()
    console.log(`>>> your address: ${deployer}`)

    // get the Endpoint address
    const endpointAddr = LZ_ENDPOINTS[hre.network.name]
    console.log(`[${hre.network.name}] Endpoint address: ${endpointAddr}`)

    await deploy("PingPong", {
        from: "0xdf826ff6518e609E4cEE86299d40611C148099d5",
        args: [endpointAddr],
        log: true,
        waitConfirmations: 1,
    })

    // let eth = "0.99"
    // let tx = await (
    //     await owner.sendTransaction({
    //         to: pingPong.address,
    //         value: ethers.utils.parseEther(eth),
    //     })
    // ).wait()
    // console.log(`send it [${eth}] ether | tx: ${tx.transactionHash}`)
}

module.exports.tags = ["PingPong"]
