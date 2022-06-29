import Shotgun from "./contracts/Shotgun.cdc"

pub fun main(tokenId: UInt64): UInt64? {
    if  Shotgun.auctionId[tokenId] != nil {
        return Shotgun.auctionId[tokenId]
    }

    return nil
}
