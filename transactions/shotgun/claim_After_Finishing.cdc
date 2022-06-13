import FungibleToken from "./contracts/FungibleToken.cdc"
import Shotgun from "./contracts/Shotgun.cdc"

transaction(auctionID: UInt64) {
    let flowVaultCap: Capability<&{FungibleToken.Receiver}>

    prepare(signer: AuthAccount) {
        self.flowVaultCap = signer.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        assert(self.flowVaultCap.borrow() != nil, message: "Missing or mis-typed FLOW receiver")

        let auction = signer.getCapability<&{Shotgun.AuctionPublic}>(Shotgun.ShotgunPublicPath).borrow()
            ?? panic("Couldn't borrow a reference to the Auction Collection")

        let itemRef = auction.borrowShotgunItem(id: auctionID)
            ?? panic("No shotgun item with that ID")

        itemRef.claimFlow(
            claimer: signer.address,
            flowVaultCap: self.flowVaultCap
        )
    }
}
