pragma solidity ^0.4.11;

import "./MiniMeToken.sol";
import "./ClimateContribution.sol";
import "./SafeMath.sol";
import "./Owned.sol";
import "./ERC20Token.sol";


contract ClimatePlaceHolder is TokenController, Owned {
    using SafeMath for uint256;

    MiniMeToken public climate;
    ClimateContribution public contribution;
    uint256 public activationTime;

    /// @notice Constructor
    /// @param _owner Trusted owner for this contract.
    /// @param _climate CO2 token contract address
    /// @param _contribution ClimateContribution contract address
    ///  only this exchanger will be able to move tokens)
    function ClimatePlaceHolder(address _owner, address _climate, address _contribution) {
        owner = _owner;
        climate = MiniMeToken(_climate);
        contribution = ClimateContribution(_contribution);
    }

    /// @notice The owner of this contract can change the controller of the DEKA token
    ///  Please, be sure that the owner is a trusted agent or 0x0 address.
    /// @param _newController The address of the new controller

    function changeController(address _newController) public onlyOwner {
        climate.changeController(_newController);
        ControllerChanged(_newController);
    }


    //////////
    // MiniMe Controller Interface functions
    //////////

    // In between the offering and the network. Default settings for allowing token transfers.
    function proxyPayment(address) public payable returns (bool) {
        return false;
    }

    function onTransfer(address _from, address, uint256) public returns (bool) {
        return transferable(_from);
    }

    function onApprove(address _from, address, uint256) public returns (bool) {
        return transferable(_from);
    }

    function transferable(address _from) internal returns (bool) {
        // Allow the exchanger to work from the beginning
        if (activationTime == 0) {
            uint256 f = contribution.finalizedTime();
            if (f > 0) {
                activationTime = f.add(1 weeks);
            } else {
                return false;
            }
        }
        return (getTime() > activationTime);
    }


    //////////
    // Testing specific methods
    //////////

    /// @notice This function is overrided by the test Mocks.
    function getTime() internal returns (uint256) {
        return now;
    }


    //////////
    // Safety Methods
    //////////

    /// @notice This method can be used by the controller to extract mistakenly
    ///  sent tokens to this contract.
    /// @param _token The address of the token contract that you want to recover
    ///  set to 0 in case you want to extract ether.
    function claimTokens(address _token) public onlyOwner {
        if (climate.controller() == address(this)) {
            climate.claimTokens(_token);
        }
        if (_token == 0x0) {
            owner.transfer(this.balance);
            return;
        }

        ERC20Token token = ERC20Token(_token);
        uint256 balance = token.balanceOf(this);
        token.transfer(owner, balance);
        ClaimedTokens(_token, owner, balance);
    }

    event ClaimedTokens(address indexed _token, address indexed _controller, uint256 _amount);
    event ControllerChanged(address indexed _newController);
}
