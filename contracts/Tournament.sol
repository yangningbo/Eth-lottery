contract Tournament {

	address public owner;
	uint public playerCount;
	uint public tournamentPot;
	address[] public winners;
	Match current;
	Match[] matches;

	struct Match {
		Player leftPlayer;
		Player rightPlayer;
		uint bit;
	}

	struct Player {
		address account;
		bytes32 commitment;
		bool hasRevealed;
		bytes32 choice;
		bool eliminated;
	}

	mapping (address => Player) public players;

	/*
		Tournament constructor creates a new empty match and initializes starting values
	*/
	function Tournament() {
		resetMatch();
		owner = msg.sender;
		playerCount = 0;
		tournamentPot = 0;
	}

	/*
		Utility function for resetting the state of the current match for adding new
		players into the tournament.
	*/
	function resetMatch() {
		current = Match({
			leftPlayer: Player(address(0x0), bytes32(0x0), false, bytes32(0x0), false), 
			rightPlayer: Player(address(0x0), bytes32(0x0), false, bytes32(0x0), false), 
			bit: 0
		});
	}

	/*
		Adds a new player into the tournament lottery and inserts them into the
		first open match as a left or right player depending on the status of a
		current match.
	*/
	function addPlayer(bytes32 commit) {
		// Add new player to current match and send any excess Wei back to player
		if (msg.value >= 1000) {
			if (msg.value - 1000 > 0) {
				msg.sender.send(msg.value - 1000);
			}

			tournamentPot += 1000;

			Player p = players[msg.sender];
			p.account = msg.sender
			p.commitment = commit;
			p.hasRevealed = false;
			p.choice = bytes32(0x0);
			p.eliminated = false;

			playerCount += 1;
			populateMatch(msg.sender);
		}
	}

	/*
		Utility function for populating the current unfilled match
	*/
	function populateMatch(address sender) {
		if (current.bit == 0) {
			current.leftPlayer = players[sender];
			current.bit = 1;
		} else {
			current.rightPlayer = players[sender];
			current.bit = 0;
			matches.push(current);
		}
	}

	/*
		Secret revealing stage of protocol for each round of matches
	*/
	function open(bytes32 choice, uint nonce) {
		if (!players[msg.sender].hasRevealed && sha3(sha3(msg.sender, choice, nonce)) == players[msg.sender].commitment) {
			players[msg.sender].hasRevealed = true;
			players[msg.sender].choice = choice;
		}
	}

	/*
		Evaluates the winners of each match in a given round. We compute the sum of
		each player's hashed commitment modulo 2, add 1, and determine the winner
		by selecting the left player if value = 1 and the right player if value = 2
	*/
	function checkRound() return (uint remaining) {
		for (uint i = 0; i < matches.length; i++) {
			uint value = addmod(bytesToUInt(matches[i].leftPlayer.commitment), bytesToUInt(matches[i].rightPlayer.commitment), 2) + 1;
			if (value == 1) {
				winners.push(matches[i].leftPlayer.account);
				matches[i].rightPlayer.eliminated = true;
			} else {
				winners.push(matches[i].rightPlayer.account);
				matches[i].leftPlayer.eliminated = true;
			}
			playerCount--;
		}
		// All winners are chosen, generate new set of matches
		delete matches;

		// Check for lottery winner: when 1 player remains
		if (winners.length == 1) {
			winners[0].send(tournamentPot);
		} else {
			return 
		}
	}

	/*
		Generate new commitments for players still in the lottery
	*/
	function resetCommitment(bytes32 commit) {
		if (players[msg.sender].eliminated) {
			return;
		} else {
			players[msg.sender] = Player(msg.sender, commit, false, bytes32(0x0), false);
			populateMatch(msg.sender);
		}
	}

	/*
		Utility function to check that all players have revealed their secret
		in the current round of matches.
	*/
	function haveRevealed() constant returns (bool success) {
		for (uint i = 0; i < matches.length; i++) {
			Match temp = matches[i];
			if (!temp.leftPlayer.hasRevealed || !temp.rightPlayer.hasRevealed) {
				return false;
			}
		}
		return true;
	}

	/*
		Utility function for converting bytes to integer for deciding match winners
	*/
	function bytesToUInt(bytes32 v) constant returns (uint ret) {
        if (v == 0x0) {
            throw;
        }

        uint digit;

        for (uint i = 0; i < 32; i++) {
            digit = uint((uint(v) / (2 ** (8 * (31 - i)))) & 0xff);
            if (digit == 0) {
                break;
            }
            else if (digit < 48 || digit > 57) {
                throw;
            }
            ret *= 10;
            ret += (digit - 48);
        }
        return ret;
    }

    /*
		Suicide function
    */
	function kill() {
		if (msg.sender == owner) {
			suicide(owner);
		}
	}
}