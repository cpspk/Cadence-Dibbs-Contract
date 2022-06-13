import Shotgun from "./contracts/Shotgun.cdc"

pub fun main(address: Address, id: UInt64): Bool {
    if let auction = getAccount(address).getCapability<&{Shotgun.AuctionPublic}>(Shotgun.ShotgunPublicPath).borrow() {
        if let itemRef = auction.borrowShotgunItem(id: id) {
            return itemRef.isAuctionExpired()
        }
    }

    return false
}
