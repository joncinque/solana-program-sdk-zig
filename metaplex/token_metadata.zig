const std = @import("std");
const sol = @import("sol");
const borsh = @import("borsh");

const metaplex = @import("metaplex.zig");

const token_metadata = @This();

pub const max_name_len = 32;
pub const max_symbol_len = 10;
pub const max_uri_len = 200;

pub const max_metadata_len =
    1 + // key
    32 + // update authority id
    32 + // mint id
    max_data_len +
    1 + // primary sale
    1 + // mutable
    9 + // nonce
    34 + // collection
    18 + // uses
    2 + // token standard
    118 // padding
;

pub const max_data_len = 4 +
    max_name_len +
    4 +
    max_symbol_len +
    4 +
    max_uri_len +
    2 +
    1 +
    4 +
    max_creator_limit * max_creator_len;

pub const max_edition_len = 1 + 32 + 8 + 200;

pub const max_master_edition_len = 1 + 9 + 8 + 264;
pub const max_creator_limit = 5;
pub const max_creator_len = 32 + 1 + 1;
pub const max_reservations = 200;
pub const max_reservation_list_v1_len = 1 + 32 + 8 + 8 + max_reservations * 34 + 100;
pub const max_reservation_list_len = 1 + 32 + 8 + 8 + max_reservations * 48 + 8 + 8 + 84;
pub const max_edition_marker_len = 32;
pub const edition_marker_bit_len = 248;
pub const use_authority_record_len = 18;
pub const collection_authority_record_len = 11;

pub fn getMetadataId(mint_id: sol.PublicKey) !sol.PublicKey {
    const pda = try sol.PublicKey.findProgramAddress(.{ "metadata", &metaplex.token_metadata_program_id.bytes, mint_id }, metaplex.token_metadata_program_id);
    return pda.address;
}

pub fn getMasterEditionId(mint_id: sol.PublicKey) !sol.PublicKey {
    const pda = try sol.PublicKey.findProgramAddress(.{ "metadata", &metaplex.token_metadata_program_id.bytes, mint_id, "edition" }, metaplex.token_metadata_program_id);
    return pda.address;
}

pub fn getEditionId(mint_id: sol.PublicKey, edition_number: u8) !sol.PublicKey {
    const pda = try sol.PublicKey.findProgramAddress(.{ "metadata", &metaplex.token_metadata_program_id.bytes, mint_id, "edition", edition_number / edition_marker_bit_len }, metaplex.token_metadata_program_id);
    return pda.address;
}

pub fn createMetadataAccountV2(metadata: sol.Account.Info, params: struct {
    data: DataV2,
    is_mutable: bool,
    mint: sol.Account.Info,
    mint_authority: sol.Account.Info,
    payer: sol.Account.Info,
    update_authority: sol.Account.Info,
    system_program: sol.Account.Info,
    rent: sol.Account.Info,
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try borsh.writeAlloc(sol.allocator, token_metadata.Instruction{
        .create_metadata_account_v2 = .{
            .data = params.data,
            .is_mutable = params.is_mutable,
        },
    });
    defer sol.allocator.free(data);

    const instruction = sol.Instruction.from(.{
        .program_id = &metaplex.token_metadata_program_id,
        .accounts = &[_]sol.Account.Param{
            .{ .id = metadata.id, .is_writable = true, .is_signer = false },
            .{ .id = params.mint.id, .is_writable = false, .is_signer = false },
            .{ .id = params.mint_authority.id, .is_writable = false, .is_signer = true },
            .{ .id = params.payer.id, .is_writable = true, .is_signer = true },
            .{ .id = params.update_authority.id, .is_writable = false, .is_signer = false },
            .{ .id = params.system_program.id, .is_writable = false, .is_signer = false },
            .{ .id = params.rent.id, .is_writable = false, .is_signer = false },
        },
        .data = data,
    });

    try instruction.invokeSigned(&.{
        metadata,
        params.mint,
        params.mint_authority,
        params.payer,
        params.update_authority,
        params.system_program,
        params.rent,
    }, params.seeds);
}

pub fn updateMetadataAccountV2(metadata: sol.Account.Info, params: struct {
    new_data: ?DataV2,
    new_update_authority_id: ?sol.PublicKey,
    primary_sale_happened: ?bool,
    is_mutable: ?bool,
    update_authority: sol.Account.Info,
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try borsh.writeAlloc(sol.allocator, token_metadata.Instruction{
        .update_metadata_account_v2 = .{
            .data = params.new_data,
            .update_authority_id = params.new_update_authority_id,
            .primary_sale_happened = params.primary_sale_happened,
            .is_mutable = params.is_mutable,
        },
    });
    defer sol.allocator.free(data);

    const instruction = sol.Instruction.from(.{
        .program_id = &metaplex.token_metadata_program_id,
        .accounts = &[_]sol.Account.Param{
            .{ .id = metadata.id, .is_writable = true, .is_signer = false },
            .{ .id = params.update_authority.id, .is_writable = false, .is_signer = true },
        },
        .data = data,
    });

    try instruction.invokeSigned(&.{ metadata, params.update_authority }, params.seeds);
}

pub fn createMetadataAccount(metadata: sol.Account.Info, params: struct {
    data: Data,
    is_mutable: bool,
    mint: sol.Account.Info,
    mint_authority: sol.Account.Info,
    payer: sol.Account.Info,
    update_authority: sol.Account.Info,
    system_program: sol.Account.Info,
    rent: sol.Account.Info,
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try borsh.writeAlloc(sol.allocator, token_metadata.Instruction{
        .create_metadata_account = .{
            .data = params.data,
            .is_mutable = params.is_mutable,
        },
    });
    defer sol.allocator.free(data);

    const instruction = sol.Instruction.from(.{
        .program_id = &metaplex.token_metadata_program_id,
        .accounts = &[_]sol.Account.Param{
            .{ .id = metadata.id, .is_writable = true, .is_signer = false },
            .{ .id = params.mint.id, .is_writable = false, .is_signer = false },
            .{ .id = params.mint_authority.id, .is_writable = false, .is_signer = true },
            .{ .id = params.payer.id, .is_writable = true, .is_signer = true },
            .{ .id = params.update_authority.id, .is_writable = false, .is_signer = false },
            .{ .id = params.system_program.id, .is_writable = false, .is_signer = false },
            .{ .id = params.rent.id, .is_writable = false, .is_signer = false },
        },
        .data = data,
    });

    try instruction.invokeSigned(&.{
        metadata,
        params.mint,
        params.mint_authority,
        params.payer,
        params.update_authority,
        params.system_program,
        params.rent,
    }, params.seeds);
}

pub fn updateMetadataAccount(metadata: sol.Account.Info, params: struct {
    new_data: ?Data,
    new_update_authority_id: ?sol.PublicKey,
    primary_sale_happened: ?bool,
    update_authority: sol.Account.Info,
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try borsh.writeAlloc(sol.allocator, token_metadata.Instruction{
        .update_metadata_account = .{
            .data = params.new_data,
            .update_authority_id = params.new_update_authority_id,
            .primary_sale_happened = params.primary_sale_happened,
        },
    });
    defer sol.allocator.free(data);

    const instruction = sol.Instruction.from(.{
        .program_id = &metaplex.token_metadata_program_id,
        .accounts = &[_]sol.Account.Param{
            .{ .id = metadata.id, .is_writable = true, .is_signer = false },
            .{ .id = params.update_authority.id, .is_writable = false, .is_signer = true },
        },
        .data = data,
    });

    try instruction.invokeSigned(&.{ metadata, params.update_authority }, params.seeds);
}

pub fn createMasterEditionV3(edition: sol.Account.Info, params: struct {
    max_supply: ?u64,
    mint: sol.Account.Info,
    update_authority: sol.Account.Info,
    mint_authority: sol.Account.Info,
    payer: sol.Account.Info,
    metadata: sol.Account.Info,
    token_program: sol.Account.Info,
    system_program: sol.Account.Info,
    rent: sol.Account.Info,
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try borsh.writeAlloc(sol.allocator, token_metadata.Instruction{
        .create_master_edition_v3 = .{
            .max_supply = params.max_supply,
        },
    });
    defer sol.allocator.free(data);

    const instruction = sol.Instruction.from(.{
        .program_id = &metaplex.token_metadata_program_id,
        .accounts = &[_]sol.Account.Param{
            .{ .id = edition.id, .is_writable = true, .is_signer = false },
            .{ .id = params.mint.id, .is_writable = true, .is_signer = false },
            .{ .id = params.update_authority.id, .is_writable = false, .is_signer = true },
            .{ .id = params.mint_authority.id, .is_writable = false, .is_signer = true },
            .{ .id = params.payer.id, .is_writable = true, .is_signer = true },
            .{ .id = params.metadata.id, .is_writable = true, .is_signer = false },
            .{ .id = params.token_program.id, .is_writable = false, .is_signer = false },
            .{ .id = params.system_program.id, .is_writable = false, .is_signer = false },
            .{ .id = params.rent.id, .is_writable = false, .is_signer = false },
        },
        .data = data,
    });

    try instruction.invokeSigned(&.{
        edition,
        params.mint,
        params.update_authority,
        params.mint_authority,
        params.payer,
        params.metadata,
        params.token_program,
        params.system_program,
        params.rent,
    }, params.seeds);
}

pub fn setAndVerifyCollection(params: struct {
    metadata: sol.Account.Info,
    collection_authority: sol.Account.Info,
    payer: sol.Account.Info,
    update_authority: sol.Account.Info,
    collection_mint: sol.Account.Info,
    collection_metadata: sol.Account.Info,
    collection_master_edition: sol.Account.Info,
    collection_authority_record: ?sol.Account.Info,
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try borsh.writeAlloc(sol.allocator, token_metadata.Instruction.set_and_verify_collection);
    defer sol.allocator.free(data);

    var accounts = [8]sol.Account.Param{
        .{ .id = params.metadata.id, .is_writable = true, .is_signer = false },
        .{ .id = params.collection_authority.id, .is_writable = false, .is_signer = true },
        .{ .id = params.payer.id, .is_writable = true, .is_signer = true },
        .{ .id = params.update_authority.id, .is_writable = false, .is_signer = true },
        .{ .id = params.collection_mint.id, .is_writable = false, .is_signer = false },
        .{ .id = params.collection_metadata.id, .is_writable = false, .is_signer = false },
        .{ .id = params.collection_master_edition.id, .is_writable = false, .is_signer = false },
        undefined,
    };

    if (params.collection_authority_record) |collection_authority_record| {
        accounts[accounts.len - 1] = .{ .id = collection_authority_record.id, .is_writable = false, .is_signer = false };
    }

    const instruction = sol.Instruction.from(.{
        .program_id = &metaplex.token_metadata_program_id,
        .accounts = if (params.collection_authority_record != null) accounts[0..] else accounts[0 .. accounts.len - 1],
        .data = data,
    });

    if (params.collection_authority_record) |collection_authority_record| {
        try instruction.invokeSigned(&.{
            params.metadata,
            params.collection_authority,
            params.payer,
            params.update_authority,
            params.collection_mint,
            params.collection_metadata,
            params.collection_master_edition,
            collection_authority_record,
        }, params.seeds);
    } else {
        try instruction.invokeSigned(&.{
            params.metadata,
            params.collection_authority,
            params.payer,
            params.update_authority,
            params.collection_mint,
            params.collection_metadata,
            params.collection_master_edition,
        }, params.seeds);
    }
}

pub fn burnNft(params: struct {
    metadata: sol.Account.Info,
    owner: sol.Account.Info,
    mint: sol.Account.Info,
    token_account: sol.Account.Info,
    master_edition_account: sol.Account.Info,
    token_program: sol.Account.Info,
    collection_metadata: ?sol.Account.Info,
    seeds: []const []const []const u8 = &.{},
}) !void {
    const data = try borsh.writeAlloc(sol.allocator, token_metadata.Instruction.burn_nft);
    defer sol.allocator.free(data);

    var accounts: [7]sol.Account.Param = undefined;
    accounts[0] = .{ .id = params.metadata.id, .is_writable = true, .is_signer = false };
    accounts[1] = .{ .id = params.owner.id, .is_writable = true, .is_signer = true };
    accounts[2] = .{ .id = params.mint.id, .is_writable = true, .is_signer = false };
    accounts[3] = .{ .id = params.token_account.id, .is_writable = true, .is_signer = false };
    accounts[4] = .{ .id = params.master_edition_account.id, .is_writable = true, .is_signer = false };
    accounts[5] = .{ .id = params.token_program.id, .is_writable = false, .is_signer = false };

    var num_accounts: usize = 6;
    if (params.collection_metadata) |collection_metadata| {
        accounts[6] = .{ .id = collection_metadata.id, .is_writable = true, .is_signer = false };
        num_accounts += 1;
    }

    const instruction = sol.Instruction.from(.{
        .program_id = &metaplex.token_metadata_program_id,
        .accounts = accounts[0..num_accounts],
        .data = data,
    });

    if (params.collection_metadata) |collection_metadata| {
        try instruction.invokeSigned(&.{
            params.metadata,
            params.owner,
            params.mint,
            params.token_account,
            params.master_edition_account,
            params.token_program,
            collection_metadata,
        }, params.seeds);
    } else {
        try instruction.invokeSigned(&.{
            params.metadata,
            params.owner,
            params.mint,
            params.token_account,
            params.master_edition_account,
            params.token_program,
        }, params.seeds);
    }
}

pub const Instruction = union(enum) {
    /// Create Metadata object.
    ///
    /// #[account(0, writable, name="metadata", desc="Metadata key (pda of ['metadata', program id, mint id])")]
    /// #[account(1, name="mint", desc="Mint of token asset")]
    /// #[account(2, signer, name="mint_authority", desc="Mint authority")]
    /// #[account(3, signer, name="payer", desc="payer")]
    /// #[account(4, name="update_authority", desc="update authority info")]
    /// #[account(5, name="system_program", desc="System program")]
    /// #[account(6, name="rent", desc="Rent info")]
    create_metadata_account: struct {
        /// Note that unique metadatas are disabled for now.
        data: Data,
        /// Whether you want your metadata to be updateable in the future.
        is_mutable: bool,
    },
    /// Update a Metadata
    ///
    /// #[account(0, writable, name="metadata", desc="Metadata account")]
    /// #[account(1, signer, name="update_authority", desc="Update authority key")]
    update_metadata_account: struct {
        data: ?Data,
        update_authority_id: ?sol.PublicKey,
        primary_sale_happened: ?bool,
    },
    /// Register a Metadata as a Master Edition V1, which means Editions can be minted.
    /// Henceforth, no further tokens will be mintable from this primary mint. Will throw an error if more than one
    /// token exists, and will throw an error if less than one token exists in this primary mint.
    ///
    /// #[account(0, writable, name="edition", desc="Unallocated edition V1 account with address as pda of ['metadata', program id, mint, 'edition']")]
    /// #[account(1, writable, name="mint", desc="Metadata mint")]
    /// #[account(2, writable, name="printing_mint", desc="Printing mint - A mint you control that can mint tokens that can be exchanged for limited editions of your master edition via the MintNewEditionFromMasterEditionViaToken endpoint")]
    /// #[account(3, writable, name="one_time_printing_authorization_mint", desc="One time authorization printing mint - A mint you control that prints tokens that gives the bearer permission to mint any number of tokens from the printing mint one time via an endpoint with the token-metadata program for your metadata. Also burns the token.")]
    /// #[account(4, signer, name="update_authority", desc="Current Update authority key")]
    /// #[account(5, signer, name="printing_mint_authority", desc="Printing mint authority - THIS WILL TRANSFER AUTHORITY AWAY FROM THIS KEY.")]
    /// #[account(6, signer, name="mint_authority", desc="Mint authority on the metadata's mint - THIS WILL TRANSFER AUTHORITY AWAY FROM THIS KEY")]
    /// #[account(7, name="metadata", desc="Metadata account")]
    /// #[account(8, signer, name="payer", desc="payer")]
    /// #[account(9, name="token_program", desc="Token program")]
    /// #[account(10, name="system_program", desc="System program")]
    /// #[account(11, name="rent", desc="Rent info")]
    /// #[account(12, signer, name="one_time_printing_authorization_mint_authority", desc="One time authorization printing mint authority - must be provided if using max supply. THIS WILL TRANSFER AUTHORITY AWAY FROM THIS KEY.")]
    deprecated_create_master_edition: struct {
        max_supply: ?u64,
    },
    /// Given an authority token minted by the Printing mint of a master edition, and a brand new non-metadata-ed mint with one token
    /// make a new Metadata + Edition that is a child of the master edition denoted by this authority token.
    ///
    /// #[account(0, writable, name="metadata", desc="New Metadata key (pda of ['metadata', program id, mint id])")]
    /// #[account(1, writable, name="edition", desc="New Edition V1 (pda of ['metadata', program id, mint id, 'edition'])")]
    /// #[account(2, writable, name="master_edition", desc="Master Record Edition V1 (pda of ['metadata', program id, master metadata mint id, 'edition'])")]
    /// #[account(3, writable, name="mint", desc="Mint of new token - THIS WILL TRANSFER AUTHORITY AWAY FROM THIS KEY")]
    /// #[account(4, signer, name="mint_authority", desc="Mint authority of new mint")]
    /// #[account(5, writable, name="printing_mint", desc="Printing Mint of master record edition")]
    /// #[account(6, writable, name="master_token_account", desc="Token account containing Printing mint token to be transferred")]
    /// #[account(7, writable, name="edition_marker", desc="Edition pda to mark creation - will be checked for pre-existence. (pda of ['metadata', program id, master mint id, edition_number])")]
    /// #[account(8, signer, name="burn_authority", desc="Burn authority for this token")]
    /// #[account(9, signer, name="payer", desc="payer")]
    /// #[account(10, name="master_update_authority", desc="update authority info for new metadata account")]
    /// #[account(11, name="master_metadata", desc="Master record metadata account")]
    /// #[account(12, name="token_program", desc="Token program")]
    /// #[account(13, name="system_program", desc="System program")]
    /// #[account(14, name="rent", desc="Rent info")]
    /// #[account(15, optional, writable, name="reservation_list", desc="Reservation List - If present, and you are on this list, you can get an edition number given by your position on the list.")]
    deprecated_mint_new_edition_from_master_edition_via_printing_token: struct {
        edition: u64,
    },
    /// Allows updating the primary sale boolean on Metadata solely through owning an account
    /// containing a token from the metadata's mint and being a signer on this transaction.
    /// A sort of limited authority for limited update capability that is required for things like
    /// Metaplex to work without needing full authority passing.
    ///
    /// #[account(0, writable, name="metadata", desc="Metadata key (pda of ['metadata', program id, mint id])")]
    /// #[account(1, signer, name="owner", desc="Owner on the token account")]
    /// #[account(2, name="token", desc="Account containing tokens from the metadata's mint")]
    update_primary_sale_happened_via_token: void,
    /// Reserve up to 200 editions in sequence for up to 200 addresses in an existing reservation PDA, which can then be used later by
    /// redeemers who have printing tokens as a reservation to get a specific edition number
    /// as opposed to whatever one is currently listed on the master edition. Used by Auction Manager
    /// to guarantee printing order on bid redemption. AM will call whenever the first person redeems a
    /// printing bid to reserve the whole block
    /// of winners in order and then each winner when they get their token submits their mint and account
    /// with the pda that was created by that first bidder - the token metadata can then cross reference
    /// these people with the list and see that bidder A gets edition #2, so on and so forth.
    ///
    /// NOTE: If you have more than 20 addresses in a reservation list, this may be called multiple times to build up the list,
    /// otherwise, it simply wont fit in one transaction. Only provide a total_reservation argument on the first call, which will
    /// allocate the edition space, and in follow up calls this will specifically be unnecessary (and indeed will error.)
    ///
    /// #[account(0, writable, name="master_edition", desc="Master Edition V1 key (pda of ['metadata', program id, mint id, 'edition'])")]
    /// #[account(1, writable, name="reservation_list", desc="PDA for ReservationList of ['metadata', program id, master edition key, 'reservation', resource-key]")]
    /// #[account(2, signer, name="resource", desc="The resource you tied the reservation list too")]
    deprecated_set_reservation_list: struct {
        /// If set, means that no more than this number of editions can ever be minted. This is immutable.
        reservations: []const Reservation,
        /// Should only be present on the very first call to set reservation list.
        total_reservation_spots: ?u64,
        /// Where in the reservation list you want to insert this slice of reservations.
        offset: u64,
        /// What the total spot offset is in the reservation list from the beginning to your slice of reservations.
        /// So if is going to be 4 total editions eventually reserved between your slice and the beginning of the array,
        /// split between 2 reservation entries, the offset variable above would be "2" since you start at entry 2 in 0 indexed array
        /// (first 2 taking 0 and 1) and because they each have 2 spots taken, this variable would be 4.
        total_spot_offset: u64,
    },
    /// Create an empty reservation list for a resource who can come back later as a signer and fill the reservation list
    /// with reservations to ensure that people who come to get editions get the number they expect. See SetReservationList for more.
    ///
    /// #[account(0, writable, name="reservation_list", desc="PDA for ReservationList of ['metadata', program id, master edition key, 'reservation', resource-key]")]
    /// #[account(1, signer, name="payer", desc="Payer")]
    /// #[account(2, signer, name="update_authority", desc="Update authority")]
    /// #[account(3, name="master_edition", desc=" Master Edition V1 key (pda of ['metadata', program id, mint id, 'edition'])")]
    /// #[account(4, name="resource", desc="A resource you wish to tie the reservation list to. This is so your later visitors who come to redeem can derive your reservation list PDA with something they can easily get at. You choose what this should be.")]
    /// #[account(5, name="metadata", desc="Metadata key (pda of ['metadata', program id, mint id])")]
    /// #[account(6, name="system_program", desc="System program")]
    /// #[account(7, name="rent", desc="Rent info")]
    deprecated_create_reservation_list: void,
    /// Sign a piece of metadata that has you as an unverified creator so that it is now verified.
    ///
    /// #[account(0, writable, name="metadata", desc="Metadata (pda of ['metadata', program id, mint id])")]
    /// #[account(1, signer, name="creator", desc="Creator")]
    sign_metadata: void,
    /// Using a one time authorization token from a master edition v1, print any number of printing tokens from the printing_mint
    /// one time, burning the one time authorization token.
    ///
    /// [account(0, writable, name="destination", desc="Destination account")]
    /// [account(1, writable, name="token", desc="Token account containing one time authorization token")]
    /// [account(2, writable, name="one_time_printing_authorization_mint", desc="One time authorization mint")]
    /// [account(3, writable, name="printing_mint", desc="Printing mint")]
    /// [account(4, signer, name="burn_authority", desc="Burn authority")]
    /// [account(5, name="metadata", desc="Metadata key (pda of ['metadata', program id, mint id])")]
    /// [account(6, name="master_edition", desc="Master Edition V1 key (pda of ['metadata', program id, mint id, 'edition'])")]
    /// [account(7, name="token_program", desc="Token program")]
    /// [account(8, name="rent", desc="Rent")]
    deprecated_mint_printing_tokens_via_token: struct {
        supply: u64,
    },
    /// Using your update authority, mint printing tokens for your master edition.
    ///
    /// #[account(0, writable, name="destination", desc="Destination account")]
    /// #[account(1, writable, name="printing_mint", desc="Printing mint")]
    /// #[account(2, signer, name="update_authority", desc="Update authority")]
    /// #[account(3, name="metadata", desc="Metadata key (pda of ['metadata', program id, mint id])")]
    /// #[account(4, name="master_edition", desc="Master Edition V1 key (pda of ['metadata', program id, mint id, 'edition'])")]
    /// #[account(5, name="token_program", desc="Token program")]
    /// #[account(6, name="rent", desc="Rent")]
    deprecated_mint_printing_token: struct {
        supply: u64,
    },
    /// Register a Metadata as a Master Edition V2, which means Edition V2s can be minted.
    /// Henceforth, no further tokens will be mintable from this primary mint. Will throw an error if more than one
    /// token exists, and will throw an error if less than one token exists in this primary mint.
    ///
    /// #[account(0, writable, name="edition", desc="Unallocated edition V2 account with address as pda of ['metadata', program id, mint, 'edition']")]
    /// #[account(1, writable, name="mint", desc="Metadata mint")]
    /// #[account(2, signer, name="update_authority", desc="Update authority")]
    /// #[account(3, signer, name="mint_authority", desc="Mint authority on the metadata's mint - THIS WILL TRANSFER AUTHORITY AWAY FROM THIS KEY")]
    /// #[account(4, signer, name="payer", desc="payer")]
    /// #[account(5, name="metadata", desc="Metadata account")]
    /// #[account(6, name="token_program", desc="Token program")]
    /// #[account(7, name="system_program", desc="System program")]
    /// #[account(8, name="rent", desc="Rent info")]
    create_master_edition: struct {
        /// If set, means that no more than this number of editions can ever be minted. This is immutable.
        max_supply: ?u64,
    },
    /// Given a token account containing the master edition token to prove authority, and a brand new non-metadata-ed mint with one token
    /// make a new Metadata + Edition that is a child of the master edition denoted by this authority token.
    ///
    /// #[account(0, writable, name="new_metadata", desc="New Metadata key (pda of ['metadata', program id, mint id])")]
    /// #[account(1, writable, name="new_edition", desc="New Edition (pda of ['metadata', program id, mint id, 'edition'])")]
    /// #[account(2, writable, name="master_edition", desc="Master Record Edition V2 (pda of ['metadata', program id, master metadata mint id, 'edition'])")]
    /// #[account(3, writable, name="new_mint", desc="Mint of new token - THIS WILL TRANSFER AUTHORITY AWAY FROM THIS KEY")]
    /// #[account(4, writable, name="edition_mark_pda", desc="Edition pda to mark creation - will be checked for pre-existence. (pda of ['metadata', program id, master metadata mint id, 'edition', edition_number]) where edition_number is NOT the edition number you pass in args but actually edition_number = floor(edition/EDITION_MARKER_BIT_SIZE).")]
    /// #[account(5, signer, name="new_mint_authority", desc="Mint authority of new mint")]
    /// #[account(6, signer, name="payer", desc="payer")]
    /// #[account(7, signer, name="token_account_owner", desc="owner of token account containing master token (#8)")]
    /// #[account(8, name="token_account", desc="token account containing token from master metadata mint")]
    /// #[account(9, name="new_metadata_update_authority", desc="Update authority info for new metadata")]
    /// #[account(10, name="metadata", desc="Master record metadata account")]
    /// #[account(11, name="token_program", desc="Token program")]
    /// #[account(12, name="system_program", desc="System program")]
    /// #[account(13, name="rent", desc="Rent info")]
    mint_new_edition_from_master_edition_via_token: struct {
        edition: u64,
    },
    /// Converts the Master Edition V1 to a Master Edition V2, draining lamports from the two printing mints
    /// to the owner of the token account holding the master edition token. Permissionless.
    /// Can only be called if there are currenly no printing tokens or one time authorization tokens in circulation.
    ///
    /// #[account(0, writable, name="master_edition", desc="Master Record Edition V1 (pda of ['metadata', program id, master metadata mint id, 'edition'])")]
    /// #[account(1, writable, name="one_time_auth", desc="One time authorization mint")]
    /// #[account(2, writable, name="printing_mint", desc="Printing mint")]
    convert_master_edition_v1_to_v2: void,
    /// Proxy Call to Mint Edition using a Store Token Account as a Vault Authority.
    ///
    /// #[account(0, writable, name="new_metadata", desc="New Metadata key (pda of ['metadata', program id, mint id])")]
    /// #[account(1, writable, name="new_edition", desc="New Edition (pda of ['metadata', program id, mint id, 'edition'])")]
    /// #[account(2, writable, name="master_edition", desc="Master Record Edition V2 (pda of ['metadata', program id, master metadata mint id, 'edition']")]
    /// #[account(3, writable, name="new_mint", desc="Mint of new token - THIS WILL TRANSFER AUTHORITY AWAY FROM THIS KEY")]
    /// #[account(4, writable, name="edition_mark_pda", desc="Edition pda to mark creation - will be checked for pre-existence. (pda of ['metadata', program id, master metadata mint id, 'edition', edition_number]) where edition_number is NOT the edition number you pass in args but actually edition_number = floor(edition/EDITION_MARKER_BIT_SIZE).")]
    /// #[account(5, signer, name="new_mint_authority", desc="Mint authority of new mint")]
    /// #[account(6, signer, name="payer", desc="payer")]
    /// #[account(7, signer, name="vault_authority", desc="Vault authority")]
    /// #[account(8, name="safety_deposit_store", desc="Safety deposit token store account")]
    /// #[account(9, name="safety_deposit_box", desc="Safety deposit box")]
    /// #[account(10, name="vault", desc="Vault")]
    /// #[account(11, name="new_metadata_update_authority", desc="Update authority info for new metadata")]
    /// #[account(12, name="metadata", desc="Master record metadata account")]
    /// #[account(13, name="token_program", desc="Token program")]
    /// #[account(14, name="token_vault_program", desc="Token vault program")]
    /// #[account(15, name="system_program", desc="System program")]
    /// #[account(16, name="rent", desc="Rent info")]
    mint_new_edition_from_master_edition_via_vault_proxy: struct {
        edition: u64,
    },
    /// Puff a Metadata - make all of it's variable length fields (name/uri/symbol) a fixed length using a null character
    /// so that it can be found using offset searches by the RPC to make client lookups cheaper.
    ///
    /// #[account(0, writable, name="metadata", desc="Metadata account")]
    puff_metadata: void,
    /// Update a Metadata with is_mutable as a parameter
    ///
    /// #[account(0, writable, name="metadata", desc="Metadata account")]
    /// #[account(1, signer, name="update_authority", desc="Update authority key")]
    update_metadata_account_v2: struct {
        data: ?DataV2,
        update_authority_id: ?sol.PublicKey,
        primary_sale_happened: ?bool,
        is_mutable: ?bool,
    },
    /// Create Metadata object.
    ///
    /// #[account(0, writable, name="metadata", desc="Metadata key (pda of ['metadata', program id, mint id])")]
    /// #[account(1, name="mint", desc="Mint of token asset")]
    /// #[account(2, signer, name="mint_authority", desc="Mint authority")]
    /// #[account(3, signer, name="payer", desc="payer")]
    /// #[account(4, name="update_authority", desc="update authority info")]
    /// #[account(5, name="system_program", desc="System program")]
    /// #[account(6, name="rent", desc="Rent info")]
    create_metadata_account_v2: struct {
        /// Note that unique metadatas are disabled for now.
        data: DataV2,
        /// Whether you want your metadata to be updateable in the future.
        is_mutable: bool,
    },
    /// Register a Metadata as a Master Edition V2, which means Edition V2s can be minted.
    /// Henceforth, no further tokens will be mintable from this primary mint. Will throw an error if more than one
    /// token exists, and will throw an error if less than one token exists in this primary mint.
    ///
    /// #[account(0, writable, name="edition", desc="Unallocated edition V2 account with address as pda of ['metadata', program id, mint, 'edition']")]
    /// #[account(1, writable, name="mint", desc="Metadata mint")]
    /// #[account(2, signer, name="update_authority", desc="Update authority")]
    /// #[account(3, signer, name="mint_authority", desc="Mint authority on the metadata's mint - THIS WILL TRANSFER AUTHORITY AWAY FROM THIS KEY")]
    /// #[account(4, signer, name="payer", desc="payer")]
    /// #[account(5, writable, name="metadata", desc="Metadata account")]
    /// #[account(6, name="token_program", desc="Token program")]
    /// #[account(7, name="system_program", desc="System program")]
    /// #[account(8, name="rent", desc="Rent info")]
    create_master_edition_v3: struct {
        /// If set, means that no more than this number of editions can ever be minted. This is immutable.
        max_supply: ?u64,
    },
    /// If a MetadataAccount Has a Collection allow the UpdateAuthority of the Collection to Verify the NFT Belongs in the Collection.
    ///
    /// #[account(0, writable, name="metadata", desc="Metadata account")]
    /// #[account(1, signer, name="collection_authority", desc="Collection Update authority")]
    /// #[account(2, signer, name="payer", desc="payer")]
    /// #[account(3, name="collection_mint", desc="Mint of the Collection")]
    /// #[account(4, name="collection", desc="Metadata Account of the Collection")]
    /// #[account(5, name="collection_master_edition_account", desc="MasterEdition2 Account of the Collection Token")]
    verify_collection: void,
    /// Utilize or Use an NFT , burns the NFT and returns the lamports to the update authority if the use method is burn and its out of uses.
    /// Use Authority can be the Holder of the NFT, or a Delegated Use Authority.
    ///
    /// #[account(0, writable, name="metadata", desc="Metadata account")]
    /// #[account(1, writable, name="token_account", desc="Token Account Of NFT")]
    /// #[account(2, writable, name="mint", desc="Mint of the Metadata")]
    /// #[account(3, signer, name="use_authority", desc="A Use Authority / Can be the current Owner of the NFT")]
    /// #[account(4, name="owner", desc="Owner")]
    /// #[account(5, name="token_program", desc="Token program")]
    /// #[account(6, name="ata_program", desc="Associated Token program")]
    /// #[account(7, name="system_program", desc="System program")]
    /// #[account(8, name="rent", desc="Rent info")]
    /// #[account(9, optional, writable, name="use_authority_record", desc="Use Authority Record PDA If present the program Assumes a delegated use authority")]
    /// #[account(10, optional, name="burner", desc="Program As Signer (Burner)")]
    utilize: struct {
        number_of_uses: u64,
    },
    /// Approve another account to call [utilize] on this NFT.
    ///
    /// #[account(0, writable, name="use_authority_record", desc="Use Authority Record PDA")]
    /// #[account(1, signer, name="owner", desc="Owner")]
    /// #[account(2, signer, name="payer", desc="Payer")]
    /// #[account(3, name="user", desc="A Use Authority")]
    /// #[account(4, writable, name="owner_token_account", desc="Owned Token Account Of Mint")]
    /// #[account(5, name="metadata", desc="Metadata account")]
    /// #[account(6, name="mint", desc="Mint of Metadata")]
    /// #[account(7, name="burner", desc="Program As Signer (Burner)")]
    /// #[account(8, name="token_program", desc="Token program")]
    /// #[account(9, name="system_program", desc="System program")]
    /// #[account(10, name="rent", desc="Rent info")]
    approve_use_authority: struct {
        number_of_uses: u64,
    },
    /// Revoke account to call [utilize] on this NFT.
    ///
    /// #[account(0, writable, name="use_authority_record", desc="Use Authority Record PDA")]
    /// #[account(1, signer, name="owner", desc="Owner")]
    /// #[account(2, name="user", desc="A Use Authority")]
    /// #[account(3, writable, name="owner_token_account", desc="Owned Token Account Of Mint")]
    /// #[account(4, name="mint", desc="Mint of Metadata")]
    /// #[account(5, name="metadata", desc="Metadata account")]
    /// #[account(6, name="token_program", desc="Token program")]
    /// #[account(7, name="system_program", desc="System program")]
    /// #[account(8, name="rent", desc="Rent info")]
    revoke_use_authority: void,
    /// If a MetadataAccount Has a Collection allow an Authority of the Collection to unverify an NFT in a Collection.
    ///
    /// #[account(0, writable, name="metadata", desc="Metadata account")]
    /// #[account(1, signer, name="collection_authority", desc="Collection Authority")]
    /// #[account(2, name="collection_mint", desc="Mint of the Collection")]
    /// #[account(3, name="collection", desc="Metadata Account of the Collection")]
    /// #[account(4, name="collection_master_edition_account", desc="MasterEdition2 Account of the Collection Token")]
    /// #[account(5, optional, name="collection_authority_record", desc="Collection Authority Record PDA")]
    unverify_collection: void,
    /// Approve another account to verify NFTs belonging to a collection, [verify_collection] on the collection NFT.
    ///
    /// #[account(0, writable, name="collection_authority_record", desc="Collection Authority Record PDA")]
    /// #[account(1, name="new_collection_authority", desc="A Collection Authority")]
    /// #[account(2, signer, name="update_authority", desc="Update Authority of Collection NFT")]
    /// #[account(3, signer, name="payer", desc="Payer")]
    /// #[account(4, name="metadata", desc="Collection Metadata account")]
    /// #[account(5, name="mint", desc="Mint of Collection Metadata")]
    /// #[account(6, name="system_program", desc="System program")]
    /// #[account(7, name="rent", desc="Rent info")]
    approve_collection_authority: void,
    /// Revoke account to call [verify_collection] on this NFT.
    ///
    /// #[account(0, writable, name="collection_authority_record", desc="Collection Authority Record PDA")]
    /// #[account(1, signer, name="update_authority", desc="Update Authority of Collection NFT")]
    /// #[account(2, name="metadata", desc="Metadata account")]
    /// #[account(3, name="mint", desc="Mint of Metadata")]
    revoke_collection_authority: void,
    /// Allows the same Update Authority (Or Delegated Authority) on an NFT and Collection to perform [update_metadata_accounts_v2]
    /// with collection and [verify_collection] on the NFT/Collection in one instruction.
    ///
    /// #[account(0, writable, name="metadata", desc="Metadata account")]
    /// #[account(1, signer, name="collection_authority", desc="Collection Update authority")]
    /// #[account(2, signer, name="payer", desc="Payer")]
    /// #[account(3, name="update_authority", desc="Update Authority of Collection NFT and NFT")]
    /// #[account(4, name="collection_mint", desc="Mint of the Collection")]
    /// #[account(5, name="collection", desc="Metadata Account of the Collection")]
    /// #[account(6, name="collection_master_edition_account", desc="MasterEdition2 Account of the Collection Token")]
    /// #[account(7, optional, name="collection_authority_record", desc="Collection Authority Record PDA")]
    set_and_verify_collection: void,
    /// Allow freezing of an NFT if this user is the delegate of the NFT.
    ///
    /// #[account(0, signer, name="delegate", desc="Delegate")]
    /// #[account(1, writable, name="token_account", desc="Token account to freeze")]
    /// #[account(2, name="edition", desc="Edition")]
    /// #[account(3, name="mint", desc="Token mint")]
    /// #[account(4, name="token_program", desc="Token Program")]
    freeze_delegated_account: void,
    /// Allow thawing of an NFT if this user is the delegate of the NFT.
    ///
    /// #[account(0, signer, name="delegate", desc="Delegate")]
    /// #[account(1, writable, name="token_account", desc="Token account to thaw")]
    /// #[account(2, name="edition", desc="Edition")]
    /// #[account(3, name="mint", desc="Token mint")]
    /// #[account(4, name="token_program", desc="Token Program")]
    thaw_delegated_account: void,
    /// Remove Creator Verificaton.
    ///
    /// #[account(0, writable, name="metadata", desc="Metadata (pda of ['metadata', program id, mint id])")]
    /// #[account(1, signer, name="creator", desc="Creator")]
    remove_creator_verification: void,

    /// Completely burn a NFT, including closing the metadata account.
    ///
    /// #[account(0, writable, name="metadata", desc="Metadata (pda of ['metadata', program id, mint id])")]
    /// #[account(1, signer, writable, name="owner", desc="NFT owner")]
    /// #[account(2, writable, name="mint", desc="Mint of the NFT")]
    /// #[account(3, writable, name="token_account", desc="Token account to close")]
    /// #[account(4, writable, name="master_edition_account", desc="MasterEdition2 of the NFT")]
    /// #[account(5, name="spl token program", desc="SPL Token Program")]
    /// #[account(6, optional, writable, name="collection_metadata", desc="Metadata of the Collection")]
    burn_nft,
};

pub const Entity = union(enum(u8)) {
    uninitialized,
    edition_v1: Edition,
    master_edition_v1: MasterEditionV1,
    reservation_list_v1: ReservationListV1,
    metadata_v1: Metadata,
    reservation_list_v2: ReservationListV2,
    master_edition_v2: MasterEditionV2,
    edition_marker: EditionMarker,
    use_authority_record: UseAuthorityRecord,
    collection_authority_record: CollectionAuthorityRecord,
};

pub const Data = struct {
    /// The name of the asset.
    name: []const u8,
    /// The symbol of the asset.
    symbol: []const u8,
    /// URI pointing to JSON representing the asset.
    uri: []const u8,
    /// Royalty basis points that goes to creators in secondary sales (0 - 10,000).
    seller_fee_basis_points: u16,
    /// Array of creators, optional.
    creators: ?[]Creator,
};

pub const DataV2 = struct {
    /// The name of the asset.
    name: []const u8,
    /// The symbol of the asset.
    symbol: []const u8,
    /// URI pointing to JSON representing the asset.
    uri: []const u8,
    /// Royalty basis points that goes to creators in secondary sales (0 - 10,000).
    seller_fee_basis_points: u16,
    /// Array of creators, optional.
    creators: ?[]const Creator,
    /// The collection that this asset belongs to.
    collection: ?Collection,
    /// Uses for this asset.
    uses: ?Uses,

    pub fn setName(self: *DataV2, new_name: []const u8) void {
        const ptr = @as([*]u8, @ptrFromInt(@intFromPtr(self.name.ptr)));
        for (new_name, 0..) |c, i| {
            ptr[i] = c;
        }
        if (new_name.len < self.name.len) {
            for (self.name[new_name.len..], 0..) |_, i| {
                ptr[new_name.len + i] = 0;
            }
        }
    }

    pub fn setSymbol(self: *DataV2, new_symbol: []const u8) void {
        const ptr = @as([*]u8, @ptrFromInt(@intFromPtr(self.symbol.ptr)));
        for (new_symbol, 0..) |c, i| {
            ptr[i] = c;
        }
        if (new_symbol.len < self.symbol.len) {
            for (self.symbol[new_symbol.len..], 0..) |_, i| {
                ptr[new_symbol.len + i] = 0;
            }
        }
    }

    pub fn setUri(self: *DataV2, new_uri: []const u8) void {
        const ptr = @as([*]u8, @ptrFromInt(@intFromPtr(self.uri.ptr)));
        for (new_uri, 0..) |c, i| {
            ptr[i] = c;
        }
        if (new_uri.len < self.uri.len) {
            for (self.uri[new_uri.len..], 0..) |_, i| {
                ptr[new_uri.len + i] = 0;
            }
        }
    }

    pub fn setCreators(self: *DataV2, new_creators: []const Creator) void {
        const ptr = @as([*]Creator, @ptrFromInt(@intFromPtr(self.creators.ptr)));
        for (new_creators, 0..) |c, i| ptr[i] = c;
    }

    pub fn toV1(self: DataV2) Data {
        return .{
            .name = self.name,
            .symbol = self.symbol,
            .uri = self.uri,
            .seller_fee_basis_points = self.seller_fee_basis_points,
            .creators = self.creators,
        };
    }
};

pub const UseMethod = enum {
    burn,
    multiple,
    single,
};

pub const Uses = struct {
    use_method: UseMethod,
    remaining: u64,
    total: u64,
};

pub const TokenStandard = enum {
    /// This is a master edition.
    non_fungible,
    /// A token with metadata that can also have attributes.
    fungible_asset,
    /// A token with simple metadata.
    fungible,
    /// This is a limited edition.
    non_fungible_edition,
};

pub const UseAuthorityRecord = struct {
    allowed_uses: u64,
    bump: u8,
};

pub const CollectionAuthorityRecord = struct {
    bump: u8,
};

pub const Collection = struct {
    verified: bool,
    id: sol.PublicKey,
};

pub const Metadata = struct {
    update_authority_id: sol.PublicKey,
    mint_id: sol.PublicKey,
    data: Data,
    /// Immutable. Once flipped, all sales of this metadata are considered secondary.
    primary_sale_happened: bool,
    /// Whether or not `data` is mutable, default is not.
    is_mutable: bool,
    /// Nonce for easy calculation of editions, if present.
    edition_nonce: ?u8,
    /// Since we cannot easily change Metadata, we add the new DataV2 fields here at the end.
    token_standard: ?TokenStandard,
    /// The collection this metadata belongs to.
    collection: ?Collection,
    /// Uses for this asset.
    uses: ?Uses,
};

pub const MasterEditionV2 = struct {
    supply: u64,
    max_supply: ?u64,
};

pub const MasterEditionV1 = struct {
    supply: u64,
    max_supply: ?u64,
    /// Can be used to mint tokens that give one-time permission to mint a single limited edition.
    printing_mint_id: sol.PublicKey,

    /// If you don't know how many printing tokens you are going to need, but you do know
    /// you are going to need some amount in the future, you can use a token from this mint.
    /// Coming back to the token metadata program with one of these tokens allows you to mint (one time)
    /// any number of printing tokens you want. This is used for instance by the Auction Manager with
    /// participation NFTs, where we don't know how many people will bid and need participation
    /// because when the auction begins we just don't know how many printing tokens we will need,
    /// but at the end we will. At the end it then burns this token with its token metadata to get
    /// the printing tokens it needs to give to bidders. Each bidder then redeems a printing token
    /// to get their limited editions.
    one_time_printing_authorization_mint_id: sol.PublicKey,
};

pub const Edition = struct {
    /// Points at the MasterEdition struct.
    parent_id: sol.PublicKey,
    /// Starting at 0 for the master record, this is incremented for each edition that is minted.
    edition: u64,
};

pub const Creator = struct {
    id: sol.PublicKey,
    verified: bool,
    /// In percentages, NOT basis points.
    share: u8,
};

pub const ReservationListV2 = struct {
    /// Present for reverse lookups.
    master_edition_id: sol.PublicKey,
    /// What supply counter was on MasterEdition when this reservation was created.
    supply_snapshot: ?u64,
    reservations: []const Reservation,
    /// How many reservations there are going to be, given on first set_reservation call.
    total_reservation_spots: u64,
    /// Cached count of reservation spots in the reservation vector to save on CPU.
    current_reservation_spots: u64,
};

pub const Reservation = struct {
    id: sol.PublicKey,
    spots_remaining: u64,
    total_spots: u64,
};

pub const ReservationListV1 = struct {
    /// Present for reverse lookups.
    master_edition_id: sol.PublicKey,
    supply_snapshot: ?u64,
    reservations: []const ReservationV1,
};

pub const ReservationV1 = struct {
    id: sol.PublicKey,
    spots_remaining: u8,
    total_spots: u8,
};

pub const EditionMarker = struct {
    ledger: [31]u8,
};
