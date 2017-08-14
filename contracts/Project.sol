pragma solidity ^0.4.11;


import {Ownable} from '../zeppelin/contracts/ownership/Ownable.sol';
import {ReentrancyGuard} from '../zeppelin/contracts/ReentrancyGuard.sol';
import {NameRegistry} from './NameRegistry.sol';


contract Project is Ownable, ReentrancyGuard {

	event LogProjectCreated(address initiator, string project_name);
	event LogInitialConfirmation(uint8 member_index, Vote confirmation);

	event LogProjectConfirmed();
	event LogProjectSuspended();
	event LogProjectRejected();
	event LogProjectTerminated();

	event LogResolutionChange(uint32 id, ResStatus status);
	event LogResolutionVote(uint32 id, Vote vote);

	NameRegistry public registry = NameRegistry(0x0);

	bytes32 public constant GOLD_ACCOUNT = "gold.account";
	uint8 public constant NOT_A_MEMBER = 0xff;

	enum Status {
		None,
		Confirmed, // this is the main Active status
		Rejected,  // this is the terminal state when initially rejected
		Suspended, // this only happens when the gold account pauses the project
		Terminated // this happens by passing a resolution
	}

	enum ResStatus {
		None,

		Created,
		Committed,

		Suspended,
		Cancelled,
		Expired,

		Passed,
		Rejected,

		Executing, // in the middle of transaction execution
		Executed   // all transactions have already been executed
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
		uint8     initiator; // the member who initiated the resolution, or 0xFF in the case of the GOLD account
		uint32    created;
		uint32    expiry;
		ResStatus status;

		int32 silver_token_confirmations;
		int32 silver_token_rejections;
		int32 silver_token_total;

		uint8 majority_percentage;

		uint8 transaction_counter;
		mapping(uint8 => bytes) transactions;// an array of raw transactions that need to pass atomically as per the resolution
		mapping(uint8 => Vote) votes;
	}

	struct Checkpoint {
		uint32 timestamp;

		int32 silver;
		int32 copper;
		int32 sodium;
	}

	Status public project_status = Status.Confirmed;

	string  public project_name;
	address public project_initiator;
	address []     project_members;
	int32 public   project_allocation_cap = 1000000;

	int32 public  silver_token_counter = 0;
	int32 public  copper_token_counter = 0;
	int32 public  sodium_token_counter = 0;

	// the different token holdings
	mapping (uint8 => Checkpoint[]) token_balances;
	mapping (uint8 => bool) is_member_suspended;

	// data about resolutions
	uint8 public res_majority_percentage = 0;
	Resolution[] resolutions;

	function Project(
			address _registry,
			uint8 _res_majority_percentage,
			string _name,
			address[] _members,
			int32 [] _silver,
			int32 [] _copper) {

		// make sure we don't go over the hard limit of sizeof(byte) for the number of members
		require(_members.length < 0xff);
		require(_res_majority_percentage > 0 && _res_majority_percentage <= 100);

		project_name = _name;
		project_initiator = msg.sender;
		res_majority_percentage = _res_majority_percentage;

		// take note of the current NameRegistry address
		registry = NameRegistry(_registry);

		// transfer admin rights to the GOLD account
		registry = NameRegistry(_registry);
		address gold = registry.get(GOLD_ACCOUNT);
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

			silver_token_counter += _silver[i];
			copper_token_counter += _copper[i];
		}

		LogProjectCreated(project_initiator, project_name);
	}

	// block the direct ETH transfer to this contract
	function() {
		revert();
	}

	//--------------------------------------- modifiers ---------------------------------------------------------------

	modifier only_project_initiator {
		require(msg.sender == project_initiator);
		_;
	}

	modifier only_in_confirmed_status {
		require(project_status == Status.Confirmed);
		_;
	}

	modifier only_gold_account {
		require(msg.sender == registry.get(GOLD_ACCOUNT));
		_;
	}

	modifier only_silver_token_holders {
		require(get_silver_tokens(msg.sender)>0);
		_;
	}

	modifier only_silver_and_gold_accounts {
		require(
			msg.sender == registry.get(GOLD_ACCOUNT) ||
			get_silver_tokens(msg.sender)>0
		);
		_;
	}

	modifier only_active_members(uint8 member_index) {
		if(member_index == NOT_A_MEMBER) {
			require(msg.sender == registry.get(GOLD_ACCOUNT));
		} else {
			require(msg.sender == project_members[member_index]);
			require(is_member_suspended[member_index]==false);
		}
		_;
	}

	//--------------------------------------- constant methods --------------------------------------------------------

	function res_get_passed_or_rejected(uint32 res_id) public constant returns (ResStatus){

		Resolution storage res = resolutions[res_id];
		int32 quorum_token_count = res.majority_percentage * res.silver_token_total;

		if(res.silver_token_confirmations * 100 >= quorum_token_count) {
			return ResStatus.Passed;
		}

		if(res.silver_token_rejections * 100 >= quorum_token_count) {
			return ResStatus.Rejected;
		}

		return ResStatus.None;
	}

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

	function get_is_member_suspended(uint8 member_index) public constant returns(bool suspended) {
		return is_member_suspended[member_index];
	}

	function get_project_status() public constant returns(uint8 _status) {
		return uint8(project_status);
	}

	function get_silver_tokens_at(address _member, uint32 timestamp) public constant returns (int32 _tokens) {
		return get_tokens(_member, TokenType.Silver, timestamp);
	}

	function get_silver_tokens(address _member) public constant returns (int32 _tokens) {
		return get_tokens(_member, TokenType.Silver, uint32(now));
	}

	function get_copper_tokens(address _member) public constant returns (int32 _tokens) {
		return get_tokens(_member, TokenType.Copper, uint32(now));
	}

	function get_sodium_tokens(address _member) public constant returns (int32 _tokens) {
		return get_tokens(_member, TokenType.Sodium, uint32(now));
	}

	function get_tokens(address _member, TokenType _token_type, uint32 _timestamp)
	constant returns (int32) {
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

		if (_timestamp < checkpoints[0].timestamp) {
			return ret_cp;
		}

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

	function get_resolution_status(uint res_id) public constant returns(ResStatus status) {
		require(res_id < resolutions.length);
		return resolutions[res_id].status;
	}

	function get_checkpoint_idx(uint8 member_index, uint cp_index) constant
	returns (uint32 _timestamp, int32 _silver, int32 _copper, int32 _sodium){
		Checkpoint[] storage checkpoints = token_balances[member_index];
		Checkpoint storage cp = checkpoints[cp_index];
		_timestamp = cp.timestamp;
		_silver = cp.silver;
		_copper = cp.copper;
		_sodium = cp.sodium;
	}

	//--------------------------------------- gold  functions --------------------------------------------------------

	// this can be used by the GOLD account to pause and un-pause the project
	function gold_set_project_status(Status status)
	only_gold_account {
		project_status = status;
	}

	function gold_set_member_status(uint8 member_index, bool suspended) public
	only_in_confirmed_status
	only_gold_account {
		require(member_index < project_members.length);
		is_member_suspended[member_index] = suspended;
	}

	// TODO:  should we have this function ?
	function gold_set_resolution_status(uint32 res_id, ResStatus status) public
	only_in_confirmed_status
	only_gold_account {
		require(res_id < resolutions.length);
		resolutions[res_id].status = status;
	}

	//--------------------------------------- resolution functions -----------------------------------------------------

	function res_create_resolution(uint8 sender_index) public
	only_active_members(sender_index)
	only_silver_and_gold_accounts
	only_in_confirmed_status returns (uint32 res_id) {

		Resolution memory res = Resolution({
			initiator: sender_index,
			status: ResStatus.Created,
			created: uint32(now),
			expiry: 0,
			silver_token_total:0,
			silver_token_confirmations: 0,
			silver_token_rejections: 0,
			transaction_counter: 0,
			majority_percentage: res_majority_percentage
		});
		resolutions.push(res);
	
		LogResolutionChange(uint32(resolutions.length-1), ResStatus.Created);
		return uint32(resolutions.length-1);
	}

	// only the data part of the tx is needed, the 'to' part is 'this'
	function res_add_transaction(uint8 sender_index, uint32 res_id, bytes tx_data) public
	only_active_members(sender_index)
	only_silver_and_gold_accounts
	only_in_confirmed_status {

		require(res_id < resolutions.length);
		require(resolutions[res_id].status == ResStatus.Created);
		require(res.transaction_counter < 0xff-1);

		Resolution storage res = resolutions[res_id];
		res.transactions[res.transaction_counter++] = tx_data;
	}

	function res_commit_resolution(uint8 sender_index, uint32 res_id) public
	only_active_members(sender_index)
	only_silver_and_gold_accounts
	only_in_confirmed_status {

		require(res_id < resolutions.length);
		require(resolutions[res_id].status == ResStatus.Created);

		resolutions[res_id].expiry = uint32(now + 7 days);
		resolutions[res_id].status = ResStatus.Committed;

		LogResolutionChange(res_id, ResStatus.Committed);
	}

	function res_cancel_resolution(uint8 sender_index, uint32 res_id) public
	only_active_members(sender_index)
	only_silver_and_gold_accounts
	only_in_confirmed_status {

		require(res_id < resolutions.length);
		require(
			resolutions[res_id].expiry > 0 &&
			resolutions[res_id].expiry < now
		);

		resolutions[res_id].status = ResStatus.Cancelled;
		LogResolutionChange(res_id, ResStatus.Cancelled);
	}


	// only for the GOLD account to do
	function res_suspend_resolution(uint32 res_id) public
	only_in_confirmed_status
	only_gold_account {

		require(res_id < resolutions.length);
		require(resolutions[res_id].status == ResStatus.Committed);
		require(
			resolutions[res_id].expiry > 0 &&
			resolutions[res_id].expiry < now
		);

		resolutions[res_id].status = ResStatus.Suspended;
		resolutions[res_id].expiry = 0;

		LogResolutionChange(res_id, ResStatus.Suspended);
	}

	// only for the GOLD account to do
	function res_resume_resolution(uint32 res_id, uint32 timestamp) public
	only_in_confirmed_status
	only_gold_account {

		require(res_id < resolutions.length);
		require(resolutions[res_id].status == ResStatus.Suspended);
		require(resolutions[res_id].expiry == 0);

		resolutions[res_id].status = ResStatus.Committed;
		resolutions[res_id].expiry = timestamp;

		LogResolutionChange(res_id, ResStatus.Committed);
	}

	function res_vote_resolution(uint8 sender_index, uint32 res_id, Vote vote) public
	only_active_members(sender_index)
	only_in_confirmed_status
	only_silver_token_holders {

		require(res_id < resolutions.length);
		require(resolutions[res_id].status == ResStatus.Committed);
		require(
			resolutions[res_id].expiry > 0 &&
			resolutions[res_id].expiry < now
		);

		Resolution storage res = resolutions[res_id];

		require(msg.sender == project_members[sender_index]);
		require(res.votes[sender_index] == Vote.None);
		require(
			vote == Vote.Confirm ||
			vote == Vote.Reject
		);

		// record the vote
		res.votes[sender_index] = vote;

		Checkpoint memory cp = get_checkpoint_at(sender_index, res.created);
		if(vote == Vote.Confirm) {
			res.silver_token_confirmations += cp.silver;
		}

		if(vote == Vote.Reject) {
			res.silver_token_rejections += cp.silver;
		}

		ResStatus result = res_get_passed_or_rejected(res_id);

		if(result == ResStatus.Passed || result == ResStatus.Rejected) {
			res.status = result;
			LogResolutionChange(res_id, result);
		}
	}

	function res_execute_resolution(uint8 sender_index, uint32 res_id) public
	only_active_members(sender_index)
	only_silver_and_gold_accounts
	only_in_confirmed_status {

		require(res_id < uint32(resolutions.length));
		require(resolutions[res_id].status == ResStatus.Passed);

		Resolution storage res = resolutions[res_id];

		// this is a guard that can be checked by resolution transactions as a Green signal
		res.status = ResStatus.Executing;

		for(uint8 index=0; index < uint8(res.transaction_counter); index += 1) {
			require(
				this.call(res.transactions[index])
			);
		}

		res.status = ResStatus.Executed;
	}

	//--------------------------------------- Resolution executed functions -------------------------------------------

	modifier only_executing_resolution(uint32 res_id) {
		require(res_id < resolutions.length);
		require(resolutions[res_id].status == ResStatus.Executing);
		_;
	}

	function res_set_token_value(uint32 res_id, uint8 member_index, TokenType token_type, int32 tokens_number)
	only_in_confirmed_status
	nonReentrant
	only_executing_resolution(res_id) public { // this is only 'public' so we can get the data to add to the resolution

		require(member_index >= 0);
		require(member_index < project_members.length);
		require(tokens_number >= 0);

		Checkpoint[] storage checkpoints = token_balances[member_index];
		Checkpoint memory cp = Checkpoint(0,0,0,0);

		if (checkpoints.length > 0) {
			cp = checkpoints[checkpoints.length-1];
		}

		cp.timestamp = uint32(now);

		if(token_type == TokenType.Silver) {
			silver_token_counter += (tokens_number - cp.silver);
			cp.silver = tokens_number;
		}
		if(token_type == TokenType.Copper) {
			copper_token_counter += (tokens_number - cp.copper);
			cp.copper = tokens_number;
		}
		if(token_type == TokenType.Sodium) {
			sodium_token_counter += (tokens_number - cp.sodium);
			cp.sodium = tokens_number;
		}

		require(silver_token_counter + copper_token_counter <= project_allocation_cap);
		checkpoints.push(cp);
	}

	function res_convert_tokens(
		uint32 res_id,
		uint8 member_index,
		int32 tokens_number,
		TokenType from_type,
		TokenType to_type)
	only_in_confirmed_status
	nonReentrant
	only_executing_resolution(res_id) public {

		require(member_index != NOT_A_MEMBER);
		require(member_index >= 0);
		require(member_index < project_members.length);

		require(from_type == TokenType.Silver || from_type == TokenType.Copper);
		require(from_type != to_type);

		Checkpoint[] storage checkpoints = token_balances[member_index];
		require(checkpoints.length > 0);

		Checkpoint memory cp = checkpoints[checkpoints.length-1];
		cp.timestamp = uint32(now);

		if(from_type == TokenType.Silver) {
			silver_token_counter -= tokens_number;
			cp.silver -= tokens_number;
		}
		else {
			copper_token_counter -= tokens_number;
			cp.copper -= tokens_number;
		}


		if(to_type == TokenType.Silver) {
			silver_token_counter += tokens_number;
			cp.silver += tokens_number;
		}
		else if(to_type == TokenType.Copper) {
			copper_token_counter += tokens_number;
			cp.copper += tokens_number;
		}
		else {
			sodium_token_counter += tokens_number;
			cp.sodium += tokens_number;
		}

		require(silver_token_counter + copper_token_counter <= project_allocation_cap);
		checkpoints.push(cp);
	}

	function res_change_majority_percentage(uint32 res_id, uint8 new_majority_percentage)
	only_in_confirmed_status
	nonReentrant
	only_executing_resolution(res_id) public {
		require(new_majority_percentage > 0);
		require(new_majority_percentage <= 100);

		res_majority_percentage = new_majority_percentage;
	}
}
