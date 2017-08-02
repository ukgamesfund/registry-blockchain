pragma solidity ^0.4.11;


import {Ownable} from '../zeppelin/contracts/ownership/Ownable.sol';
import {NameRegistry} from './NameRegistry.sol';


contract Project is Ownable {

	event LogProjectCreated(address initiator, string project_name);
	event LogInitialConfirmation(uint8 member_index, Vote confirmation);

	event LogProjectConfirmed();
	event LogProjectPaused();
	event LogProjectRejected();
	event LogProjectTerminated();

	NameRegistry public registry = NameRegistry(0x0);

	bytes32 public constant ADMIN_ACCOUNT = "gold.account";
	uint8 public constant NOT_A_MEMBER = 0xff;

	enum Status {
		None,
		Created,  // this is the initial status when created
		Confirmed, // this is the main Active status
		Rejected,  // this is the terminal state when initially rejected
		Paused,    // this only happens when the gold account pauses the project
		Terminated // this happens by passing a resolution
	}

	enum TokenType {
		None,
		Silver,
		Copper,
		Sodium
	}

	enum Vote {
		None,
		Confirm,
		Reject
	}

	struct Resolution {
		uint8  creator;        // the member who initiated the resolution, or 0xFF in the case of the GOLD account
		uint32 expiry;

		bytes []  transactions; // an array of raw transactions that need to pass atomically as per the resolution
	}

	struct Checkpoint {
		uint32 timestamp;

		uint32 silver;
		uint32 copper;
		uint32 sodium;
	}

	Status public project_status = Status.Created;

	string  public project_name;
	address public project_initiator;
	address [] project_members;

	// the initial project confirmations
	mapping (uint8 => Vote) member_confirmations;
	uint8 public member_confirmation_counter = 0;

	// the different token holdings
	mapping (uint8 => Checkpoint[]) token_balances;

	function Project(address _registry, string _name, address[] _members, uint32 [] _silver, uint32 [] _copper) {

		// make sure we don't go over the hard limit of sizeof(byte) for the number of members
		require(_members.length < 0xff);

		project_name = _name;
		project_initiator = msg.sender;

		// take note of the current NameRegistry address
		registry = NameRegistry(_registry);

		// transfer admin rights to the GOLD account
		registry = NameRegistry(_registry);
		address gold = registry.get(ADMIN_ACCOUNT);
		transferOwnership(gold);

		// store the membership details
		for (uint8 i = 0; i < _members.length; i += 1) {
			project_members.push(_members[i]);

			Checkpoint memory cp = Checkpoint({
				timestamp: uint32(now),
				silver: _silver[i],
				copper: _copper[i],
				sodium:0
			});
			token_balances[i].push(cp);
		}

		LogProjectCreated(project_initiator, project_name);
	}

	//--------------------------------------- modifiers ---------------------------------------------------------------

	modifier only_project_initiator {
		require(msg.sender == project_initiator);
		_;
	}

	modifier only_in_deployed_status {
		require(project_status == Status.Created);
		_;
	}

	modifier only_in_confirmed_status {
		require(project_status == Status.Confirmed);
		_;
	}

	modifier only_gold_account {
		require(msg.sender == registry.get(ADMIN_ACCOUNT));
		_;
	}

	modifier only_silver_token_holders {
		require(get_silver_tokens(msg.sender)>0);
		_;
	}

	//--------------------------------------- constant methods --------------------------------------------------------

	function get_project_members_count() public constant returns (uint8 _counter) {
		return uint8(project_members.length);
	}

	function get_member_index(address _member) public constant returns (uint8 _index) {
		for(uint8 i=0; i<project_members.length; i += 1) {
			if (project_members[i] == _member) {
				return i;
			}
		}

		return uint8(NOT_A_MEMBER);
	}

	function get_project_status() public constant returns(uint8 _status) {
		return uint8(project_status);
	}

	function get_silver_tokens(address _member) public constant returns (uint32 _tokens) {
		return get_tokens(_member, TokenType.Silver, uint32(now));
	}

	function get_copper_tokens(address _member) public constant returns (uint32 _tokens) {
		return get_tokens(_member, TokenType.Copper, uint32(now));
	}

	function get_sodium_tokens(address _member) public constant returns (uint32 _tokens) {
		return get_tokens(_member, TokenType.Sodium, uint32(now));
	}

	function get_tokens(address _member, TokenType _token_type, uint32 _timestamp)
	constant returns (uint32) {
		uint8 index = get_member_index(_member);
		require(index != NOT_A_MEMBER);

		Checkpoint memory cp = get_checkpoint_at(index, _timestamp);

		if (_token_type == TokenType.Silver) {
			return cp.silver;
		}

		if (_token_type == TokenType.Copper) {
			return cp.copper;
		}

		if (_token_type == TokenType.Sodium) {
			return cp.sodium;
		}

		return 0;
	}

	function get_checkpoint_at(uint8 member_index, uint32 _timestamp)
	constant internal returns (Checkpoint) {
		require(member_index != NOT_A_MEMBER);
		Checkpoint[] storage checkpoints = token_balances[member_index];

		Checkpoint memory ret_cp = Checkpoint(0,0,0,0);

		if (checkpoints.length == 0)
			return ret_cp;

		// Shortcut for the actual value
		if (_timestamp >= checkpoints[checkpoints.length-1].timestamp) {
			ret_cp = checkpoints[checkpoints.length-1];
			return ret_cp;
		}

		if (_timestamp < checkpoints[0].timestamp)
			return ret_cp;

		// Binary search of the value in the array
		uint min = 0;
		uint max = checkpoints.length-1;
		while (max > min) {
			uint mid = (max + min + 1)/ 2;
			if (checkpoints[mid].timestamp <= _timestamp) {
				min = mid;
			} else {
				max = mid-1;
			}
		}
		return checkpoints[min];
	}

	//--------------------------------------- active functions --------------------------------------------------------

	// TODO: resolution security
	function set_token_value_now(uint8 member_index, TokenType token_type, uint32 _value) internal {
		require(member_index != NOT_A_MEMBER);
		Checkpoint[] storage checkpoints = token_balances[member_index];

		if ((checkpoints.length == 0) || (checkpoints[checkpoints.length -1].timestamp < now)) {

			Checkpoint memory mem_cp = Checkpoint(0,0,0,0);
			mem_cp.timestamp = uint32(now);
			if(token_type == TokenType.Silver) mem_cp.silver = _value;
			if(token_type == TokenType.Copper) mem_cp.copper = _value;
			if(token_type == TokenType.Sodium) mem_cp.sodium = _value;

			checkpoints[checkpoints.length++] = mem_cp;
		} else {

			Checkpoint storage storage_cp = checkpoints[checkpoints.length-1];
			if(token_type == TokenType.Silver) storage_cp.silver = _value;
			if(token_type == TokenType.Copper) storage_cp.copper = _value;
			if(token_type == TokenType.Sodium) storage_cp.sodium = _value;
		}
	}

	// this can be used by the GOLD account to pause and un-pause the project
	function set_project_status(Status status)
	only_gold_account {
		project_status = status;
	}

	function member_initial_response(uint8 member_index, Vote confirmation)
	only_in_deployed_status
	public {
		require(msg.sender == project_members[member_index]);
		require(member_confirmations[member_index] == Vote.None);
		require(
			confirmation == Vote.Confirm ||
			confirmation == Vote.Reject
		);

		member_confirmations[member_index] = confirmation;
		LogInitialConfirmation(member_index, confirmation);

		if (confirmation == Vote.Reject) {
			project_status = Status.Rejected;
			LogProjectRejected();
			return;
		}

		if (confirmation == Vote.Confirm) {
			member_confirmation_counter += 1;
			// if everybody accepted to be members we can proceed to activate the project
			if (member_confirmation_counter == project_members.length) {
				project_status = Status.Confirmed;
				LogProjectConfirmed();
			}
		}
	}

	/*

	function create_resolution(bytes transactions) public
	only_silver_token_holders {

	}

	function convert_tokens(uint8 member_index, uint32 token_number, TokenType type_from, TokenType type_to) {
		// TODO figure out security of resolution transactions


	}
	*/

	//--------------------------------------- TEST functions --------------------------------------------------------

	function test_get_checkpoint_idx(uint8 member_index, uint cp_index) constant
	returns (uint32 _timestamp, uint32 _silver, uint32 _copper, uint32 _sodium){
		Checkpoint[] storage checkpoints = token_balances[member_index];
		Checkpoint storage cp = checkpoints[cp_index];
		_timestamp = cp.timestamp;
		_silver = cp.silver;
		_copper = cp.copper;
		_sodium = cp.sodium;
	}

	function test_set_token_value_now(uint8 member_index, TokenType token_type, uint32 _value) {
		set_token_value_now(member_index, token_type, _value);
	}

}
