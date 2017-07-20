pragma solidity ^0.4.11;


contract Forwarder {

    event LogForwardedEther(address sender, address receiver, uint amount);

    function Forwarder() {
    }

    function forward(address receiver) payable {
        var amount = msg.value;
        receiver.transfer(amount);
        LogForwardedEther(msg.sender, receiver, amount);
    }
}