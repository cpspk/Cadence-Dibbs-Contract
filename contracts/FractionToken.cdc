import  IFractionToken from "./IFractionToken.cdc"

pub contract FractionToken:  IFractionToken {

    // Total supply of Flow tokens in existence
    pub var totalSupply: UInt64

    // Event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UInt64)

    // Event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UInt64, from: Address?)

    // Event that is emitted when tokens are deposited to a Vault
    pub event TokensDeposited(amount: UInt64, to: Address?)

    // Event that is emitted when new tokens are minted
    pub event TokensMinted(amount: UInt64)

    // Event that is emitted when tokens are destroyed
    pub event TokensBurned(amount: UInt64)

    // Event that is emitted when a new minter resource is created
    pub event MinterCreated()

    // Event that is emitted when a new burner resource is created
    pub event BurnerCreated()

    pub let AdminStoragePath: StoragePath

    // Vault
    //
    // Each user stores an instance of only the Vault in their storage
    // The functions in the Vault and governed by the pre and post conditions
    // in  IFractionToken when they are called.
    // The checks happen at runtime whenever a function is called.
    //
    // Resources can only be created in the context of the contract that they
    // are defined in, so there is no way for a malicious user to create Vaults
    // out of thin air. A special Minter resource needs to be defined to mint
    // new tokens.
    //
    pub resource Vault:  IFractionToken.Provider,  IFractionToken.Receiver,  IFractionToken.Balance {

        // holds the balance of a users tokens
        pub var balance: UInt64

        // initialize the balance at resource creation time
        init(balance: UInt64) {
            self.balance = balance
        }

        // withdraw
        //
        // Function that takes an integer amount as an argument
        // and withdraws that amount from the Vault.
        // It creates a new temporary Vault that is used to hold
        // the money that is being transferred. It returns the newly
        // created Vault to the context that called so it can be deposited
        // elsewhere.
        //
        pub fun withdraw(amount: UInt64): @ IFractionToken.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        // deposit
        //
        // Function that takes a Vault object as an argument and adds
        // its balance to the balance of the owners Vault.
        // It is allowed to destroy the sent Vault because the Vault
        // was a temporary holder of the tokens. The Vault's balance has
        // been consumed and therefore can be destroyed.
        pub fun deposit(from: @ IFractionToken.Vault) {
            let vault <- from as! @FractionToken.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0
            destroy vault
        }

        destroy() {
            FractionToken.totalSupply = FractionToken.totalSupply - self.balance
        }
    }

    // createEmptyVault
    //
    // Function that creates a new Vault with a balance of zero
    // and returns it to the calling context. A user must call this function
    // and store the returned Vault in their storage in order to allow their
    // account to be able to receive deposits of this token type.
    //
    pub fun createEmptyVault(): @ IFractionToken.Vault {
        return <-create Vault(balance: 0)
    }

    pub resource Administrator {
        // createNewMinter
        //
        // Function that creates and returns a new minter resource
        //
        pub fun createNewMinter(): @Minter {
            emit MinterCreated()
            return <-create Minter()
        }

        // createNewBurner
        //
        // Function that creates and returns a new burner resource
        //
        pub fun createNewBurner(): @Burner {
            emit BurnerCreated()
            return <-create Burner()
        }
    }

    // Minter
    //
    // Resource object that token admin accounts can hold to mint new tokens.
    //
    pub resource Minter {
        // mintTokens
        //
        // Function that mints new tokens, adds them to the total supply,
        // and returns them to the calling context.
        //
        pub fun mintTokens(): @FractionToken.Vault {
            let amount: UInt64 = 10000000000000000
            FractionToken.totalSupply = FractionToken.totalSupply + amount
            emit TokensMinted(amount: amount)
            return <-create Vault(balance: amount)
        }
    }

    // Burner
    //
    // Resource object that token admin accounts can hold to burn tokens.
    //
    pub resource Burner {

        // burnTokens
        //
        // Function that destroys a Vault instance, effectively burning the tokens.
        //
        // Note: the burned tokens are automatically subtracted from the
        // total supply in the Vault destructor.
        //
        pub fun burnTokens(from: @ IFractionToken.Vault) {
            let vault <- from as! @FractionToken.Vault
            let amount = vault.balance
            destroy vault
            emit TokensBurned(amount: amount)
        }
    }

    init() {
        self.totalSupply = 0
        self.AdminStoragePath= /storage/FractionTokenAdmin

        let admin <- create Administrator()
        self.account.save(<-admin, to: self.AdminStoragePath)

        // Emit an event that shows that the contract was initialized
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}
