import Shotgun from "./contracts/Shotgun.cdc"
import NonFungibleToken from "./contracts/NonFungibleToken.cdc"
import CardItems from "./contracts/CardItems.cdc"

transaction(auctionID: UInt64, starter: Address) {
    prepare(signer: AuthAccount) {
        let auction = getAccount(starter).getCapability<&{Shotgun.AuctionPublic}>(Shotgun.ShotgunPublicPath).borrow()
            ?? panic("Couldn't borrow a reference to the Auction Collection")
        let itemRef = auction.borrowShotgunItem(id: auctionID)
            ?? panic("NO shotgun item with that ID")
        let itemMeta = itemRef.meta
        let tokenTypeId = itemMeta.tokenID
        let recipient = getAccount(starter)

        assert(CardItems.isTokenLocked[tokenTypeId] == true, message: "This token is not locked")
        assert(
            itemRef.isAuctionExpired() && itemMeta.status == Shotgun.AuctionStatus.ONGOING,
            message: "Shotgun is not expired yet."
        )

        let collectionRef = signer.borrow<&CardItems.Collection{NonFungibleToken.Provider}>(from: CardItems.CollectionStoragePath)
            ?? panic("Couldn't borrow Provider reference")
        let nft <- collectionRef.withdraw(withdrawID: tokenTypeId)

        let depositRef = recipient.getCapability(CardItems.CollectionPublicPath)!.borrow<&{NonFungibleToken.CollectionPublic}>()!
        depositRef.deposit(token: <- nft)

        itemRef.updateItemStatus(newStatus: Shotgun.AuctionStatus.FREE)
        CardItems.removeTokenLocked(tokenTypeId)
    }
}
