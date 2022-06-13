import FungibleToken from "./contracts/FungibleToken.cdc"
import IFractionToken from "./contracts/IFractionToken.cdc"
import Shotgun from "./contracts/Shotgun.cdc"

transaction(auctionID: UInt64, fractionAmount: UInt64, seller: Address) {
    let vaultStoragePath: StoragePath?
    let vaultStoragePathPrefix: String

    prepare(signer: AuthAccount) {
		let auction = getAccount(seller).getCapability<&{Shotgun.AuctionPublic}>(Shotgun.ShotgunPublicPath).borrow()
            ?? panic("Couldn't borrow a reference to the Auction Collection")

        let itemRef = auction.borrowShotgunItem(id: auctionID)
            ?? panic("No shotgun item with that ID")
		let itemMeta = itemRef.meta
		let tokenTypeId = itemMeta.tokenID

		self.vaultStoragePathPrefix = "FractionTokenVault"
        self.vaultStoragePath = StoragePath(identifier: self.vaultStoragePathPrefix.concat(tokenTypeId.toString()))

        let fractionVaultRef = signer.borrow<&IFractionToken.Vault>(from: self.vaultStoragePath!)
            ?? panic("Could not borrow reference to owner's vault!")
        
        let fractionVault <- fractionVaultRef.withdraw(amount: fractionAmount)
        
        let flowVaultCap = signer.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
		    assert(flowVaultCap.borrow() != nil, message: "Missing or mis-typed flow receiver")

        itemRef.sendAndRedeemProportion(
            fractionVault: <- fractionVault,
            flowVaultCap: flowVaultCap  
        )
    }
}
