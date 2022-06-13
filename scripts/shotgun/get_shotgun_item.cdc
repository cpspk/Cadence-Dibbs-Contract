import Shotgun from "./contracts/Shotgun.cdc"

pub fun main(address: Address, id: UInt64): &Shotgun.AuctionItem? {
    if let collection = getAccount(address).getCapability<&{Shotgun.AuctionPublic}>(Shotgun.ShotgunPublicPath).borrow() {
        if let item = collection.borrowShotgunItem(id: id) {
            return item
        }
    }

    return nil
}

// A.f8d6e0586b0a20c7.Shotgun.AuctionItem(
//     fractionVault: A.f8d6e0586b0a20c7.FractionToken.Vault(balance: 6000000000000000, uuid: 100),
//     meta: A.f8d6e0586b0a20c7.Shotgun.ItemMeta(starterAddr: 0x1cf0e2f2f715450, tokenID: 3, status: A.f8d6e0586b0a20c7.Shotgun.AuctionStatus(rawValue: 1), starterFlowBalance: 60.00000000, auctionID: 3, restFlowBalance: 0.00000000, starterFractionBalance: 6000000000000000, startedAt: 253),
//     flowVault: A.0ae53cb6e3f42a79.FlowToken.Vault(uuid: 101, balance: 60.00000000), uuid: 102)
// 1654045984.00000000
// 1654045516.00000000
// 1654049899.00000000