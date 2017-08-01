
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

const ProjectStatus = {
	None : 0,
	Deployed : 1,
	Confirmed : 2,
	Rejected : 3,
	Paused: 4,
	Terminated : 5
}

const Vote = {
	None : 0,
	Confirm : 1,
	Reject : 2
}

let CONST = {

	NOT_A_MEMBER: 0xff,

	SECONDS_1D: 86400,
	SECONDS_1M: 86400*28,

	GOLD_ACCOUNT: "gold.account",
}


module.exports = {
	CONST: CONST,

	accounts: accounts,
	log: log,

	ProjectStatus: ProjectStatus,
	Vote: Vote
};