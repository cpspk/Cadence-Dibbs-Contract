import FungibleToken from "./contracts/FungibleToken.cdc"
import FlowToken from "./contracts/FlowToken.cdc"
import IFractionToken from "./contracts/IFractionToken.cdc"
import Shotgun from "./contracts/Shotgun.cdc"

transaction(auctionID: UInt64, flowAmount: UFix64, seller: Address) {
    let flowTokenReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>

    let vaultReceiverPublicPath: PublicPath?
    let vaultReceiverPublicPathPrefix: String

    prepare(buyer: AuthAccount) {
        let auction = getAccount(seller).getCapability<&{Shotgun.AuctionPublic}>(Shotgun.ShotgunPublicPath).borrow()
            ?? panic("Couldn't borrow a reference to the Auction Collection")

        let itemRef = auction.borrowShotgunItem(id: auctionID)
            ?? panic("No shotgun item with that ID")

        let itemMeta = itemRef.meta
        let tokenTypeId = itemMeta.tokenID

        self.vaultReceiverPublicPathPrefix = "FractionTokenReceiver"
        self.vaultReceiverPublicPath = PublicPath(identifier: self.vaultReceiverPublicPathPrefix.concat(tokenTypeId.toString()))

        self.flowTokenReceiver = buyer.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)!

        assert(self.flowTokenReceiver.borrow() != nil, message: "Missing or mis-typed FLOW receiver")

        let flowVaultRef = buyer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        let fractionVaultCap = buyer.getCapability<&{IFractionToken.Receiver}>(self.vaultReceiverPublicPath!)
        
        assert(fractionVaultCap.borrow() != nil, message: "Missing or mis-typed Fraction receiver")

        itemRef.purchase(
            flowVault: <- flowVaultRef.withdraw(amount: flowAmount),
            flowVaultCap: self.flowTokenReceiver,
            fractionVaultCap: fractionVaultCap  
        )
    }
}
