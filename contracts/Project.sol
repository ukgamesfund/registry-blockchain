pragma solidity ^0.4.11;


import {Ownable} from '../zeppelin/contracts/ownership/Ownable.sol';
import {NameRegistry} from './NameRegistry.sol';


contract Project is Ownable {

	event LogProjectDeployed(address initiator, string project_name);
	event LogInitialConfirmation(uint8 member_index, Vote confirmation);

	event LogProjectConfirmed();
	event LogProjectPaused();
	event LogProjectRejected();
	event LogProjectTerminated();

	NameRegistry public registry = NameRegistry(0x0);

	bytes32 public constant ADMIN_ACCOUNT = "gold.account";
	uint8 public constant NOT_A_MEMBER = 0xff;

	enum ProjectStatus {
		None,
		Deployed,  // this is the initial status when contract is deployed
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

	ProjectStatus public project_status = ProjectStatus.Deployed;

	string  public project_name;
	address public project_initiator;
	address [] project_members;

	mapping (uint8 => Vote) member_confirmations;
	uint8 public member_confirmation_counter = 0;

	mapping (uint8 => uint32) silver_tokens;
	mapping (uint8 => uint32) copper_tokens;
	mapping (uint8 => uint32) sodium_tokens;

	function Project(address _registry, string _name, address[] _members, uint32 [] _silver, uint32 [] _copper) {

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
			silver_tokens[i] = _silver[i];
			copper_tokens[i] = _copper[i];
		}

		LogProjectDeployed(project_initiator, project_name);
	}

	//--------------------------------------- modifiers ---------------------------------------------------------------

	modifier only_project_initiator {
		require(msg.sender == project_initiator);
		_;
	}

	modifier only_in_deployed_status {
		require(project_status == ProjectStatus.Deployed);
		_;
	}

	modifier only_in_confirmed_status {
		require(project_status == ProjectStatus.Confirmed);
		_;
	}

	modifier only_gold_account {
		require(msg.sender == registry.get(ADMIN_ACCOUNT));
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

	function get_tokens(address _member, TokenType _token_type) internal constant returns (uint32 _tokens) {
		uint8 index = get_member_index(_member);
		require(index != NOT_A_MEMBER);

		if (_token_type == TokenType.Silver) {
			return silver_tokens[index];
		}

		if (_token_type == TokenType.Copper) {
			return copper_tokens[index];
		}

		if (_token_type == TokenType.Sodium) {
			return sodium_tokens[index];
		}

		return 0;
	}

	function get_silver_tokens(address _member) public constant returns (uint32 _tokens) {
		return get_tokens(_member, TokenType.Silver);
	}

	function get_copper_tokens(address _member) public constant returns (uint32 _tokens) {
		return get_tokens(_member, TokenType.Copper);
	}

	function get_sodium_tokens(address _member) public constant returns (uint32 _tokens) {
		return get_tokens(_member, TokenType.Sodium);
	}

	function get_project_status() public constant returns(uint8 _status) {
		return uint8(project_status);
	}

	//--------------------------------------- active functions --------------------------------------------------------

	// this can be used by the GOLD account to pause and un-pause the project
	function set_project_status(ProjectStatus status)
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
			project_status = ProjectStatus.Rejected;
			LogProjectRejected();
			return;
		}

		if (confirmation == Vote.Confirm) {
			member_confirmation_counter += 1;
			// if everybody accepted to be members we can proceed to activate the project
			if (member_confirmation_counter == project_members.length) {
				project_status = ProjectStatus.Confirmed;
				LogProjectConfirmed();
			}
		}
	}

}
