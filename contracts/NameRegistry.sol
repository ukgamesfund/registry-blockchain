pragma solidity ^0.4.11;


import {Ownable} from '../zeppelin/contracts/ownership/Ownable.sol';


// simple contract to keep track of the moving pieces in a large project
contract NameRegistry is Ownable {

	mapping (bytes32 => address) name2address;

	mapping (address => bytes32) address2name;

	function NameRegistry() {
	}

	function get_address_by_name(bytes32 _name) constant returns (address _address) {
		_address = name2address[_name];
	}

	function get_name_by_address(address _address) constant returns (bytes32 _name) {
		_name = address2name[_address];
	}

	function get(bytes32 _name) constant returns (address _address) {
		return get_address_by_name(_name);
	}

	function set(bytes32 _name, address _address)
	onlyOwner {
		name2address[_name] = _address;
		address2name[_address] = _name;
	}
}
