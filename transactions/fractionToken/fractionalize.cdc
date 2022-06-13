import IFractionToken from "./contracts/IFractionToken.cdc"
import FractionToken from "./contracts/FractionToken.cdc"
import CardItems from "./contracts/CardItems.cdc"

transaction(recipient: Address, tokenTypeId: UInt64) {
    let tokenAdmin: &FractionToken.Administrator
    let tokenReceiver: &{IFractionToken.Receiver}
    let vaultReceiverPublicPath: PublicPath?
    let vaultReceiverPublicPathPrefix: String

    prepare(signer: AuthAccount) {
        assert(CardItems.fractionalized[tokenTypeId] == nil || CardItems.fractionalized[tokenTypeId] == false, message: "This token is already fractionalized")
        assert(CardItems.isTokenLocked[tokenTypeId] == true, message: "This token is not locked")
        self.vaultReceiverPublicPathPrefix = "FractionTokenReceiver"
        self.vaultReceiverPublicPath = PublicPath(identifier: self.vaultReceiverPublicPathPrefix.concat(tokenTypeId.toString()))

        self.tokenAdmin = signer
            .borrow<&FractionToken.Administrator>(from: FractionToken.AdminStoragePath)
            ?? panic("Signer is not the Dibbs admin.")

        self.tokenReceiver = getAccount(recipient)
            .getCapability(self.vaultReceiverPublicPath!)!
            .borrow<&{IFractionToken.Receiver}>()
            ?? panic("Unable to borrow receiver reference")
    }

    execute {
        let minter <- self.tokenAdmin.createNewMinter()
        let mintedVault <- minter.mintTokens()

        self.tokenReceiver.deposit(from: <- mintedVault)

        CardItems.setFractionalized(tokenTypeId)
        
        destroy minter
    }
}
