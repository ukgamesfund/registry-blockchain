
function accounts(rpc_accounts) {
	return {
		admin: rpc_accounts[0],
		gold: rpc_accounts[1],
	};
}

function log(_obj) {
	console.log(JSON.stringify(_obj, null, 2));
}

let CONST = {

	SECONDS_1D: 86400,
	SECONDS_1M: 86400*28,

	GOLD_ACCOUNT: "account.gold",
}


module.exports = {
	CONST: CONST,

	accounts: accounts,
	log: log,
};