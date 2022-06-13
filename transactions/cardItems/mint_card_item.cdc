import NonFungibleToken from "./contracts/NonFungibleToken.cdc"
import CardItems from "./contracts/CardItems.cdc"

// This transction uses the NFTMinter resource to mint a new NFT.
//
// It must be run with the account that has the minter resource
// stored at path /storage/NFTMinter.

transaction(recipient: Address, name: String, grade: String, serial: String, image: String) {

    // local variable for storing the minter reference
    let minter: &CardItems.NFTMinter
    
    // TODO:  admin can only be one or two member of Dibbs- consider it again

    prepare(signer: AuthAccount) {

        // borrow a reference to the NFTMinter resource in storage
        self.minter = signer.borrow<&CardItems.NFTMinter>(from: CardItems.MinterStoragePath)
            ?? panic("Could not borrow a reference to the NFT minter")

    }

    execute {
        // get the public account object for the recipient
        let recipient = getAccount(recipient)
        // borrow the recipient's public NFT collection reference
        let receiver = recipient
            .getCapability(CardItems.CollectionPublicPath)!
            .borrow<&{NonFungibleToken.CollectionPublic}>()
            ?? panic("Could not get receiver reference to the NFT Collection")

        self.minter.mintNFT(
            recipient: receiver,
            name: name,
            grade: grade,
            serial: serial,
            image: image
        )
    }
}
 