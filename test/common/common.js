
function accounts(rpc_accounts) {
	return {
		admin:   rpc_accounts[0],
		gold:    rpc_accounts[1],
		member1: rpc_accounts[2],
		member2: rpc_accounts[3],
		member3: rpc_accounts[4],
		member4: rpc_accounts[5],
		member5: rpc_accounts[6],
		member6: rpc_accounts[7],
		member7: rpc_accounts[8],
		member8: rpc_accounts[9],
	};
}

function log(_obj) {
	console.log(JSON.stringify(_obj, null, 2));
}

const Status = {
	None : 0,
	Confirmed : 1,
	Rejected : 2,
	Suspended: 3,
	Terminated : 4
}

const ResStatus = {
	None: 0,
	Created: 1,
	Committed: 2,
	Suspended: 3,
	Cancelled: 4,
	Expired: 5,
	Passed: 6,
	Rejected: 7,
	Executing: 8,
	Executed: 9
}

const TokenType = {
	None : 0,
	Silver : 1,
	Copper : 2,
	Sodium : 3
}

const Vote = {
	None : 0,
	Confirm : 1,
	Reject : 2
}

let CONST = {

	NOT_A_MEMBER: 0xff,

	SECONDS_1D: 86400,
	SECONDS_7D: 86400*7,
	SECONDS_1M: 86400*28,

	GOLD_ACCOUNT: "ac.gold",
}


module.exports = {
	CONST: CONST,

	accounts: accounts,
	log: log,

	Status: Status,
	ResStatus: ResStatus,
	TokenType: TokenType,
	Vote: Vote,
};