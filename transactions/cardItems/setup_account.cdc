import NonFungibleToken from "./contracts/NonFungibleToken.cdc"
import CardItems from "./contracts/CardItems.cdc"

// This transaction configures an account to hold Kitty Items.

transaction {
    prepare(signer: AuthAccount) {
        // if the account doesn't already have a collection
        if signer.borrow<&CardItems.Collection>(from: CardItems.CollectionStoragePath) == nil {

            // create a new empty collection
            let collection <- CardItems.createEmptyCollection()
            
            // save it to the account
            signer.save(<-collection, to: CardItems.CollectionStoragePath)

            // create a public capability for the collection
            signer.link<&CardItems.Collection{NonFungibleToken.CollectionPublic, CardItems.CardItemsCollectionPublic}>(CardItems.CollectionPublicPath, target: CardItems.CollectionStoragePath)
        }
    }
}
