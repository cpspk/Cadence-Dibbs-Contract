import IFractionToken from "./contracts/IFractionToken.cdc"
import FractionToken from "./contracts/FractionToken.cdc"

transaction(recipient: Address, amount: UInt64, tokenTypeId: UInt64) {
    let sentVault: @IFractionToken.Vault

    let vaultStoragePath: StoragePath?
    let vaultStoragePathPrefix: String
    let vaultReceiverPublicPath: PublicPath?
    let vaultReceiverPublicPathPrefix: String

    prepare(signer: AuthAccount) {
        self.vaultStoragePathPrefix = "FractionTokenVault"
        self.vaultReceiverPublicPathPrefix = "FractionTokenReceiver"

        self.vaultStoragePath = StoragePath(identifier: self.vaultStoragePathPrefix.concat(tokenTypeId.toString()))
        self.vaultReceiverPublicPath = PublicPath(identifier: self.vaultReceiverPublicPathPrefix.concat(tokenTypeId.toString()))

        let vaultRef = signer.borrow<&FractionToken.Vault>(from: self.vaultStoragePath!)
            ?? panic("Could not borrow reference to owner's vault!")
        
        self.sentVault <- vaultRef.withdraw(amount: amount)
    }

    execute {
        let receiverRef = getAccount(recipient)
            .getCapability(self.vaultReceiverPublicPath!)!
            .borrow<&{IFractionToken.Receiver}>()
            ?? panic("Could not borrow receiver reference to the recipient's Vault")

        receiverRef.deposit(from: <- self.sentVault)
    }
}
