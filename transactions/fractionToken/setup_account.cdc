import FractionToken from "./contracts/FractionToken.cdc"

transaction(tokenTypeId: UInt64) {
    let vaultStoragePath: StoragePath?
    let vaultStoragePathPrefix: String
    let vaultReceiverPublicPath: PublicPath?
    let vaultReceiverPublicPathPrefix: String
    let vaultBalancePublicPath: PublicPath?
    let vaultBalancePublicPathPrefix: String

    prepare(signer: AuthAccount) {
        self.vaultStoragePathPrefix = "FractionTokenVault"
        self.vaultReceiverPublicPathPrefix = "FractionTokenReceiver"
        self.vaultBalancePublicPathPrefix = "FractionTokenBalance"

        self.vaultStoragePath = StoragePath(identifier: self.vaultStoragePathPrefix.concat(tokenTypeId.toString()))
        self.vaultReceiverPublicPath = PublicPath(identifier: self.vaultReceiverPublicPathPrefix.concat(tokenTypeId.toString()))
        self.vaultBalancePublicPath = PublicPath(identifier: self.vaultBalancePublicPathPrefix.concat(tokenTypeId.toString()))
        
        if signer.borrow<&FractionToken.Vault>(from: self.vaultStoragePath!) == nil {

            let vault <- FractionToken.createEmptyVault()

            signer.save(<- vault, to: self.vaultStoragePath!)
            
            signer.link<&FractionToken.Vault>(
                self.vaultReceiverPublicPath!,
                target: self.vaultStoragePath!
            )

            signer.link<&FractionToken.Vault>(
                self.vaultBalancePublicPath!,
                target: self.vaultStoragePath!
            )
        }
    }
}
