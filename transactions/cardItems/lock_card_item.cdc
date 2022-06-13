import NonFungibleToken from "./contracts/NonFungibleToken.cdc"
import CardItems from "./contracts/CardItems.cdc"

// This transaction transfers a Kitty Item from one account to another.

transaction(withdrawID: UInt64) {
    prepare(signer: AuthAccount) {
        assert(CardItems.isTokenLocked[withdrawID] == nil || CardItems.isTokenLocked[withdrawID] == false, message: "This token is already locked")
        // get the recipients public account object
        let recipient = getAccount(0xf8d6e0586b0a20c7)

        // borrow a reference to the signer's NFT collection
        let collectionRef = signer.borrow<&CardItems.Collection>(from: CardItems.CollectionStoragePath)
            ?? panic("Could not borrow a reference to the owner's collection")

        // borrow a public reference to the receivers collection
        let depositRef = recipient.getCapability(CardItems.CollectionPublicPath)!.borrow<&{NonFungibleToken.CollectionPublic}>()!

        // withdraw the NFT from the owner's collection
        let nft <- collectionRef.withdraw(withdrawID: withdrawID)

        // Deposit the NFT in the recipient's collection
        depositRef.deposit(token: <-nft)
        
        CardItems.setTokenLocked(withdrawID)
    }
}
