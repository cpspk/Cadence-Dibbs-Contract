import FungibleToken from "./contracts/FungibleToken.cdc"
import IFractionToken from "./contracts/IFractionToken.cdc"
import Shotgun from "./contracts/Shotgun.cdc"

transaction(tokenTypeId: UInt64, fractionAmount: UInt64, flowAmount: UFix64) {
    // let fractionVaultCap: Capability<&{IFractionToken.Receiver}>
    // let flowVaultCap: Capability<&{FungibleToken.Receiver}>

    let vaultStoragePath: StoragePath?
    let vaultStoragePathPrefix: String
    let vaultReceiverPublicPath: PublicPath?
    let vaultReceiverPublicPathPrefix: String

    prepare(signer: AuthAccount) {
        self.vaultStoragePathPrefix = "FractionTokenVault"
        self.vaultReceiverPublicPathPrefix = "FractionTokenReceiver"

        self.vaultStoragePath = StoragePath(identifier: self.vaultStoragePathPrefix.concat(tokenTypeId.toString()))
        self.vaultReceiverPublicPath = PublicPath(identifier: self.vaultReceiverPublicPathPrefix.concat(tokenTypeId.toString()))

        let fractionVaultRef = signer.borrow<&IFractionToken.Vault>(from: self.vaultStoragePath!)
            ?? panic("Could not borrow reference to owner's vault!")
        
        let fractionVault <- fractionVaultRef.withdraw(amount: fractionAmount)

        let flowVaultRef = signer.borrow<&FungibleToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        // Withdraw tokens from the signer's stored vault
        let flowVault <- flowVaultRef.withdraw(amount: flowAmount)

        let auction = signer.borrow<&Shotgun.AuctionCollection>(from: Shotgun.ShotgunStoragePath)
            ?? panic("Couldn't borrow a reference to the Auction Collection")

        auction.startAuction(
            starterAddr: signer.address,
            tokenID: tokenTypeId,
            starterFractionBalance: fractionAmount,
            fractionVault: <- fractionVault,
            starterFlowBalance: flowAmount,
            flowVault: <- flowVault
        )
    }
}
