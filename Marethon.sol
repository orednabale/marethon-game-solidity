pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;


import "./Ownable.sol";
import "./SafeMath.sol";
import "./SkipListBoard.sol";
import "./MarethonCore.sol";

// The main contract for the Marethon Race
contract Marethon is Ownable {

    using SkipListBoard for SkipListBoard.SkipList;
    using SafeMath for uint256;
	using MarethonCore for MarethonCore.GameData;
	using MarethonCore for MarethonCore.UserData;
    // Public Variables

	uint256 constant private PLAYERS_SHARE = 35;
    uint256 constant private NEXT_POT_SHARE = 13;
    uint256 constant private TEAM_SHARE = 2;
    uint256 constant private AFF_SHARE = 10;
	
    // Status of rounds
    uint256 constant private REGISTRATION = 1; // Game/round registration
    uint256 constant private GAME_ONGOING = 2; // Round started and next round registration opens
    uint256 constant private GAME_ENDED = 3; // Current round ended, winners identified
	uint256 constant private GAME_CLOSED = 4; // Current round closed, winnings distributed, Waiting for registration of next round to end
	uint256 constant private GAME_CLOSED_QUICK = 5; // Games was closed quickly because there was no runner who registered.

	uint256 constant private HAS_NO_RUNNERS = 1401;
	uint256 constant private HAS_WINNER = 1402; 	

	uint256 constant private PRECISION = 1 ether; 	    
	uint256 constant private FIRST_START = 1543375800 * PRECISION; // The time of the first Marethon, in unix time format, save the date
	
	MarethonCore.CoreVars private vars;
	// Contains the data of each game/round, round number => GameData
    mapping (uint256 => MarethonCore.GameData) private games; 
    
	// Contains the user specific data of the games/rounds
	mapping (address => MarethonCore.UserData) private users;
	mapping (uint256 => SkipListBoard.SkipList) private scoreBoards;

	//TODO decide on scoreboard init values
	// TODO difference between private and internal
	// TODO diff between pure and view
	// Set the first registration round, first marathon start time, and initialize the 
	// first round's score board
    constructor () public {
		vars.registerRound = 1;
		games[vars.registerRound].status = REGISTRATION;
		games[vars.registerRound].start = FIRST_START;
		scoreBoards[vars.registerRound].init(8,50000000000,false);
		vars.defAffAddr = owner();
    }

    function getUserInfo(address user) public view returns (
        uint256 ethBalance, address affAddr, uint256 nRounds, uint256 nResTags
    )
    {
        ethBalance = users[user].ethBalance;
        affAddr = users[user].affAddr;
        nRounds = users[user].rounds.length;
        nResTags = users[user].resTagNames.length;
    }
	function getGameInfo(uint256 round) public view returns (uint256[20] gameInfo) {
		gameInfo[0] = games[round].status;
		gameInfo[1] = games[round].nRunners;		
		gameInfo[2] = games[round].totEth;
		gameInfo[3] = games[round].potWon;
		gameInfo[4] = games[round].start/PRECISION;
		gameInfo[5] = games[round].end/PRECISION;
		gameInfo[6] = games[round].nUsers;
		gameInfo[7] = games[round].winners.length;
		gameInfo[8] = games[round].shares.potShares;
		gameInfo[9] = games[round].shares.usersShares;		
		gameInfo[10] = games[round].shares.teamShares;		
		gameInfo[11] = games[round].shares.totShares;		
		gameInfo[12] = games[round].shares.potTransferred;
		gameInfo[13] = scoreBoards[round].level;
		gameInfo[14] = scoreBoards[round].nodeCount;		
		gameInfo[15] = vars.registerRound;
		gameInfo[16] = vars.activeRound;
		gameInfo[17] = vars.teamBalance;
		gameInfo[18] = vars.userCount;
		gameInfo[19] = uint256(vars.defAffAddr);
	}
	/**
	**	@dev  	gets the affiliate address of the current transaction
	**	@param  affi - the affiliate name/address of the transaction
	**  @return  the affiliate's address
	**/						
	function getAffAddr(string affi, address affAddr) internal returns (address newAffAddr) {
	    if (users[msg.sender].affAddr != 0) // The first affiliate address will always be the aff address
	        return users[msg.sender].affAddr;
	        
		if (bytes(affi).length != 0) { // affiliate is not null
			bytes32 affName;
			uint256 retCode;
			(retCode, affName) = MarethonCore.makeValid(affi);
			if (retCode != 0)
				newAffAddr = 0;
			else
				newAffAddr = vars.reservedNames[affName]; 			
		}
		if (newAffAddr == 0)  // New affiliate address not set or affiliate name is invalid
	        newAffAddr = affAddr; // Use the affiliate address supplied		    
	    if (newAffAddr == msg.sender)
	        newAffAddr = 0;
	    if (newAffAddr != 0)
	        users[msg.sender].affAddr = newAffAddr;
	    else {
	        users[msg.sender].affAddr = vars.defAffAddr;
	        newAffAddr = vars.defAffAddr;
	    }
	}
	
	/**
	**	@dev  	registers a runner
	**	@param  tagName - the runner's tagName
	**	@param  affi - the affiliate name/address of the transaction
	**/							
	// TODO do we need to check msg.sender == 0?
    function registerFromWal(string tagName, string affName, address affAddr) public payable {
	    affAddr = getAffAddr(affName,affAddr); // Get the affiliate address
		checkGameStart();		
		games[vars.registerRound].register(users[msg.sender], users[affAddr], scoreBoards[vars.registerRound], tagName, affAddr, vars, true);
	}

    function registerFromBal(string tagName, string affName, address affAddr) public {
		affAddr = getAffAddr(affName,affAddr); // Get the affiliate address
		checkGameStart();		
		games[vars.registerRound].register(users[msg.sender], users[affAddr], scoreBoards[vars.registerRound], tagName, affAddr, vars,false);
	}
	
	/**
	**	@dev  	reserves a name
	**	@param  tagName - the name to be reserved
	**	@param  affi - the affiliate name/address of the transaction
	**/				
    function reserveNameFromWal(string tagName, string affName, address affAddr) public payable {
	    affAddr = getAffAddr(affName,affAddr); // Get the affiliate address		
		users[msg.sender].reserveName(tagName, users[affAddr], affAddr, vars, true);		
    }

	/**
	**	@dev  	reserves a name
	**	@param  tagName - the name to be reserved
	**	@param  affi - the affiliate name/address of the transaction
	**/				
    function reserveNameFromBal(string tagName, string affName, address affAddr) public {
	    affAddr = getAffAddr(affName,affAddr); // Get the affiliate address		
		users[msg.sender].reserveName(tagName, users[affAddr], affAddr, vars, false);		
    }
	
	/**
	**	@dev  	buy a weapon from eth wallet
	**	@param  round - the game's round
	**	@param  w - what type of weapon is being bought
	**  @param  affi - affiliate name
	**/							
	function buyWeaponFromWal(uint256 round, uint256 w, string affName, address affAddr) public payable {
	    affAddr = getAffAddr(affName, affAddr); // Get the affiliate address			
		checkGameStart();				
	    MarethonCore.BuyArgs memory buyArgs = MarethonCore.BuyArgs(round, w, msg.value, affAddr, true);		
		uint256 retCode = games[round].buyWeapon(
		    users[msg.sender], users[affAddr], scoreBoards[vars.registerRound], 
		    buyArgs, vars
		);
		if (retCode == HAS_NO_RUNNERS)
			quickCloseRound();
		else if (retCode == HAS_WINNER)
			closeRound();	
	}

	/**
	**	@dev  	buy a weapon from user's account balance
	**	@param  round - the game's round
	**	@param  w - what type of weapon is being bought	
	**	@param  amount - payment amount
	**  @param  affi - affiliate name
	**/	
	function buyWeaponFromBal(uint256 round, uint256 w, uint256 payment, string affName, address affAddr) public {
	    affAddr = getAffAddr(affName, affAddr); // Get the affiliate address
		// Checks if race has started		
		checkGameStart();				
	    MarethonCore.BuyArgs memory buyArgs = MarethonCore.BuyArgs(round, w, payment, affAddr, false);				
		uint256 retCode = games[round].buyWeapon(
		    users[msg.sender], users[affAddr], scoreBoards[vars.registerRound],
		    buyArgs, vars
		);
		if (retCode == HAS_NO_RUNNERS)
			quickCloseRound();
		else if (retCode == HAS_WINNER)
			closeRound();	
	}
	
	/**
	**	@dev  	throws bombs on a runner 
	**	@param  tagNumber - the runnner to be bombed
	**	@param  fromRunner - the runner (or supported runner) who is doing the bombing
	**  @param  nBomb - number of bombs to throw
	**/										
    function throwBomb(uint256 tagNumber, uint256 fromRunner, uint256 nBomb) public {
		require(tagNumber != 0 && fromRunner != 0);/*, "Zero runners does not exist.");*/
		require (nBomb >= 1 * PRECISION);/*, "Number of bombs to throw should at least be one.");*/
        require(fromRunner != tagNumber);/*, "Bomber cannot bomb himself.");	*/
		// Checks if race has started						
		checkGameStart();
		uint256 retCode = games[vars.activeRound].throwBomb(
			users[msg.sender], scoreBoards[vars.activeRound], 
			vars.activeRound, tagNumber, fromRunner, nBomb
		);
		if (retCode == HAS_WINNER)
			closeRound();
    }

	/**
	**	@dev  	removes the shields of a runner by bombing a correponding number of bombs 
	**	@param  tagNumber - the runnner to be bombed
	**	@param  fromRunner - the runner (or supported runner) who is doing the bombing
	**/											
    function unShield(uint256 tagNumber, uint256 fromRunner) public {
		require(tagNumber != 0 && fromRunner != 0);/*, "Zero runners does not exist.");	*/
        require(
            fromRunner != tagNumber);/*,*/
  //          "Bomber cannot bomb/unshield himself."
  //      );				
		// Checks if race has started								
		checkGameStart();
		uint256 retCode = games[vars.activeRound].unShield(
			users[msg.sender], scoreBoards[vars.activeRound],
			vars.activeRound, tagNumber, fromRunner
		);
		if (retCode == HAS_WINNER)
			closeRound();		
    }
	
	/**
	**	@dev  	throws banana peels on a runner 
	**	@param  tagNumber - the runnner to be thrown banana peels
	**	@param  fromRunner - the runner (or supported runner) who is doing the throwing
	**  @param  nPeel - number of banana peels to throw
	**/											
    function throwPeel (uint256 tagNumber, uint256 fromRunner, uint256 nPeel) public {
		require(tagNumber != 0 && fromRunner != 0);/*, "Zero runners does not exist.");	*/
        require(nPeel >= 1 * PRECISION);/*, "Number of banana peels to throw should at least be one.");*/
		require(
            fromRunner != tagNumber);/*,*/
  //          "Banana peel thrower cannot throw peels on himself."
  //      );	
		// Checks if race has started								
		checkGameStart();
		uint256 retCode = games[vars.activeRound].throwPeel(
			users[msg.sender], scoreBoards[vars.activeRound], 
			vars.activeRound, tagNumber, fromRunner, nPeel
		);
		if (retCode == HAS_WINNER)
			closeRound();
    }

	/**
	**	@dev  	eats a spinach and boost its runner's speed
	**	@param  tagNumber - the runnner who will eat a spinach
	**/											
    function eatSpinach (uint256 tagNumber) public {
		require(tagNumber != 0);/*, "Zero runner does not exist.");	*/
		// Checks if race has started								
		checkGameStart();
		uint256 retCode = games[vars.activeRound].eatSpinach(
			users[msg.sender], scoreBoards[vars.activeRound], 
			vars.activeRound, tagNumber
		);
		if (retCode == HAS_WINNER)
			closeRound();		
    }

	/**
	**	@dev  	puts shields on a runner
	**	@param  tagNumber - the runnner to be thrown banana peels
	**  @param  nShield - number of shield to put
	**/												
    function putShield (uint256 tagNumber, uint256 nShield) public {
		require(tagNumber != 0);/*, "Zero runner does not exist.");	*/
		require(nShield >= 1 * PRECISION);/*, "Number of shields to put should at least be one.");*/
		// Checks if race has started										
		checkGameStart();
		uint256 retCode = games[vars.activeRound].putShield(
			users[msg.sender], scoreBoards[vars.activeRound], 
			vars.activeRound, tagNumber, nShield
		);
		if (retCode == HAS_WINNER)
			closeRound();				
    }

	/**
	**	@dev  	updates the supporters share to be given by the runner when he wins
	**	@param  tagNumber - the runnner
	**	@param  share - the percentage of share to update
	**/												
    function setSupportersShare (uint256 tagNumber, uint256 share) public {
		require(tagNumber != 0);/*, "Zero runner does not exist.");	*/
	    require(share >= 1 && share <= 99);/*, "Share should be within 1 to 99 percent");*/
		
		// Checks if race has started										
		checkGameStart();
		uint256 retCode = games[vars.activeRound].setSupportersShare(
			scoreBoards[vars.activeRound], 
			vars.activeRound, tagNumber, share
		);
		if (retCode == HAS_WINNER)
			closeRound();						
    }
	
	/**
	**	@dev  	distributes the winnings to winner/s and its supporters and the share of all the users in the system and closes the round
	**/													
    function closeRound () internal {
		require(games[vars.activeRound].status == GAME_ENDED);/*, "To close, the round should be ended first.");			*/

		uint256 nWinners = games[vars.activeRound].winners.length;
		// divide the pot won among winners
		uint256 potWon = games[vars.activeRound].potWon.div(nWinners);
		// distribute pot won to winners and its supporters
		for (uint256 i = 0;i < nWinners; i++) {
				uint256 winner = games[vars.activeRound].winners[i];
				// get the winner's share and credit the owner's account balance
				// Winner share will be credited automatically but supporters winnings will have to be claimed manually by
				// each supporters.
				uint256 winnerShare = potWon.mul(100 - games[vars.activeRound].runners[winner].supportersShare).div(100);
                uint256 affShare = winnerShare.mul(AFF_SHARE).div(100);
				winnerShare = winnerShare.sub(affShare);
				address winOwner = games[vars.activeRound].runners[winner].owner;
				users[winOwner].ethBalance = users[winOwner].ethBalance.add(winnerShare);
				address affAddr = users[winOwner].affAddr;
				if ((affAddr == 0) || (affAddr == vars.defAffAddr)) {
				    uint256 hAffShare = affShare / 2;
		            games[vars.activeRound].shares.teamShares = games[vars.activeRound].shares.teamShares.add(hAffShare);
		            vars.teamBalance = vars.teamBalance.add(hAffShare);
		            games[vars.registerRound].shares.potTransferred = games[vars.registerRound].shares.potTransferred.add(affShare - hAffShare);
				} else
				    users[affAddr].ethBalance = users[affAddr].ethBalance.add(affShare);
		}
		// distribute players/users shares
		games[vars.activeRound].shares.usersShares = games[vars.activeRound].shares.usersShares.add(games[vars.activeRound].shares.potShares.mul(PLAYERS_SHARE).div(100));
		// distribute dev team's shares		
		uint256 teamShare = games[vars.activeRound].shares.potShares.mul(TEAM_SHARE).div(100);
		games[vars.activeRound].shares.teamShares = games[vars.activeRound].shares.teamShares.add(teamShare);
		vars.teamBalance = vars.teamBalance.add(teamShare);
		// transfer next pot share to next round's pot
		games[vars.registerRound].shares.potTransferred = games[vars.registerRound].shares.potTransferred.add(games[vars.activeRound].shares.potShares.mul(NEXT_POT_SHARE).div(100));
		games[vars.activeRound].status = GAME_CLOSED;
		// set the next race to 1 week after
		games[vars.registerRound].start = (now + 1 weeks) * PRECISION;
		
		emit onCloseRound(
			vars.activeRound, games[vars.activeRound].potWon, games[vars.registerRound].shares.potTransferred, 
			games[vars.registerRound].start/PRECISION
		);		
		
		vars.activeRound = 0;		
    }

	/**
	**	@dev  	checks if the race has started and sets the active round and the next registration round and scoreboard
	**/													
	function checkGameStart() internal {
		// if game started, set active and next registration round
		if ((vars.activeRound == 0) && (games[vars.registerRound].start/PRECISION <= now)) {
			vars.activeRound = vars.registerRound++;
			games[vars.activeRound].status = GAME_ONGOING;
			games[vars.registerRound].status = REGISTRATION;
			scoreBoards[vars.registerRound].init(5,50000000000,false);			
			emit onGameStart(
				vars.activeRound, vars.registerRound
			);			
		}
	}

	/**
	**	@dev  	close the round as there are no runners who registered and sets the start date of the next race
	**/													
	function quickCloseRound() internal {
		games[vars.activeRound].end = now * PRECISION;
		games[vars.activeRound].status = GAME_CLOSED_QUICK;
		games[vars.registerRound].start = (now + 1 weeks) * PRECISION;
		// since no one registered, put the current round pot transfer to the next round's pot transfer
		games[vars.registerRound].shares.potTransferred = games[vars.activeRound].shares.potTransferred;	
		
		emit onQuickCloseRound(
			vars.activeRound, games[vars.activeRound].shares.potTransferred, games[vars.registerRound].start/PRECISION		
		);
		
		vars.activeRound = 0;
	}
    
	/**
	**	@dev  	claims winnings of a winner supporter
	**	@param  round - the game round
	**	@param  tagNumber - the winner's tag number	
	**/													
	function claimSupporterWinning(uint256 round, uint256 tagNumber) public {
		games[round].claimSupporterWinning(users[msg.sender], scoreBoards[round], round, tagNumber);
	}
	// Getter functions
	
	/**
	**	@dev  	gets the first N runners in the scoreboard
	**	@param  round - the game round
	**	@param  nRunners - number of runners to fetch
	**	@return  list of first N runners
	**/															
	function get1stLastPage(uint256 round, uint256 nRunners, bool lastPage) public view returns (
		uint256[] runners, uint256 retCode
	)
	{
		return games[round].get1stLastPage(scoreBoards[round], round, nRunners, lastPage);
	}
	
	/**
	**	@dev  	gets the next N runners in the scoreboard starting from a particular runner
	**	@param  round - the game round
	**	@param  start from - fetch N runners starting from this runner
	**	@param  nRunners - number of runners to fetch
	**	@return  list of next N runners fetched
	**/																
	function getPrevNextPage(uint256 round, uint256 startFrom, uint256 nRunners, bool nextPage) public view returns (
		uint256[] runners, uint256 retCode
	)
	{
		return games[round].getPrevNextPage(scoreBoards[round], round, startFrom, nRunners, nextPage);	
	}

	/**
	**	@dev  	gets the info of a runner in a particular round
	**	@param  round - the round
	**	@param  tag number = the runner's tag number
	**	@return  owner - round status
	**	@return  tag name - number of runners
	**	@return  meters ran - total eth spent on this round
	**	@return  runner speed - pot won on this round
	**	@return  checkpoint - start time of this round
	**	@return  finish time - end time of this round
	**	@return  supportersShare - number of users in this round
	**	@return  xSpinachAte - number of winners of this round	
	**	@return  xShielded - number of winners of this round	
	**	@return  onSpinach - number of winners of this round	
	**	@return  nShield - number of winners of this round	
	**/															
	function getRunnerInfo(uint256 round, uint256 tagNumber) public view returns (	
        address owner , bytes32 tagName , uint256[10] runData, bool onSpinach, uint256 retCode
	)
	{
		return games[round].getRunnerInfo(round, tagNumber);
	}
			
	/**
	**	@dev  	gets the winners 5 at a time at particular index
	**	@param  round - the round
	**	@param  index - the starting index	of winners to fetch
	**  @return  winners - list of winners fetched
	**	@return  nWinners - number of winners in this round
	**/																
	function getWinners(uint256 round, uint256 index) public view returns (
		uint256[5] winners, uint256 nWinners, uint256 retCode
	)
	{
		return games[round].getWinners(round, index);
	}

	/**
	**	@dev  	gets the supporters of a particular runner in a round 10 at a time
	**	@param  round - the round 
	**	@param  tag number - runner's tag number 
	**  @return  supporters - runner's list of supporters fetched
	**	@return  nSupporters - runner's number of supporters 
	**	@return  totShares - total shares of supporters 	
	**/										
	function getSupporters(uint256 round, uint256 tagNumber, uint256 index) public view returns (
		address[10] supporters, uint256 nSupporters, uint256 totShares, uint256 retCode
	) 
	{
		return games[round].getSupporters(round, tagNumber, index);
	}

	/**
	**	@dev  	gets the enemies of a particular runner in a round 10 at a time
	**	@param  round - the round 
	**	@param  tag number - runner's tag number 
	**	@param  index - the starting index	of enemies to fetch
	**  @return  enemies - runner's list of enemies fetched
	**	@return  nEnemies - runner's number of enemies 
	**/										
	function getEnemies(uint256 round, uint256 tagNumber, uint256 index) public view returns (
		uint256[3][10] enemies, uint256 nEnemies, uint256 retCode
	) 
	{
		return games[round].getEnemies(round, tagNumber, index);
	}

	/**
	**	@dev  	gets the round info on a particular user
	**	@param  user - the user's address
	**	@param  round - the round
	**	@return  shares - user's shares for this round
	**	@return  sharesClaimed - user's shares that was claimed
	**	@return  nBomb - number of user's bombs bought in this round
	**	@return  nPeel - number of user's banana peels bought in this round
	**	@return  nSpinach - number of user's spinach bought in this round
	**	@return  nShield - number of user's shield bought in this round
	**/																
	function getUserRoundInfo (address user, uint256 round) public view returns (
		uint256 shares, uint256 sharesClaimed,
		uint256 nBomb, uint256 nPeel, 
		uint256 nSpinach, uint256 nShield, uint256 retCode
	) 
	{
		return users[user].getUserRoundInfo(round, games[round].status);
	}

	/**
	**	@dev  	gets the rounds participated by a user 10 at a time
	**	@param  user = user's address
	**	@param  index - the starting index	of rounds to fetch
	**  @return  names - user's list of rounds fetched
	**	@return  nNames - user's number of rounds 
	**/										
	function getReservedNames(address user, uint256 index) public view returns (
		bytes32[10] names, uint256 nNames, uint256 retCode
	) 
	{
		return users[user].getReservedNames(index);
	}
	
	/**
	**	@dev  	gets the rounds participated by a user 10 at a time
	**	@param  user = user's address
	**	@param  index - the starting index	of rounds to fetch
	**  @return  rounds - user's list of rounds fetched
	**	@return  nRounds - user's number of rounds 
	**/										
	function getRounds(address user, uint256 index) public view returns (
		uint256[10] rounds, uint256 nRounds, uint256 retCode
	) 
	{
		return users[user].getRounds(index);
	}
	
	/**
	**	@dev  	gets the runners of a user for a particular round 10 at a time
	**	@param  round - the round
	**	@param  user = user's address
	**	@param  index - the starting index	of runners to fetch
	**  @return  runners - user's list of runners fetched
	**	@return  nRunners - user's number of runners 
	**/										
	function getRunners(uint256 round, address user, uint256 index) public view returns (
		uint256[10] runners, uint256 nRunners, uint256 retCode
	) 
	{
		return users[user].getRunners(round, index);
	}

	/**
	**	@dev  	gets the runners supported by a user for a particular round 10 at a time
	**	@param  round - the round
	**	@param  user = user's address
	**	@param  index - the starting index	of supported runners to fetch
	**  @return  runners - user's list of supported runners fetched
	**	@return  nRunners - user's number of supported runners 
	**/										
	function getSupportedRunners(uint256 round, address user, uint256 index) public view returns (
		uint256[10] runners, uint256 nRunners, uint256 retCode
	) 
	{
		return users[user].getSupportedRunners(round, index);
	}
		
	/**
	**	@dev  	withdraws amount from user's account balance
	**	@param  amount - the amount to withdraw
	**/													
    function withdraw(uint256 amount, bool all) public {
        if (all)
            amount = users[msg.sender].ethBalance;
		require(amount != 0);/*, "Amount to withdraw should not be zero.");*/
		require(users[msg.sender].ethBalance >= amount);/*, "User should have sufficient balance to withdraw.");*/
		
		// updates the account balance
		users[msg.sender].ethBalance = users[msg.sender].ethBalance.sub(amount);
		// transfers the amount to eth wallet
		msg.sender.transfer(amount);	
		
		emit onWithdraw(
			msg.sender, amount
		);		
    }

	/**
	**	@dev  	claim/convert shares to eth
	**	@param  round - the round where shares will be claimed
	** 	@param  shares2claim - the shares to claim
	**/														
    function claimShares(uint256 round, uint256 shares2Claim, bool all) public {
        if (all)
            shares2Claim = users[msg.sender].gameData[round].shares.sub(users[msg.sender].gameData[round].sharesClaimed);
		users[msg.sender].claimShares(games[round], round, shares2Claim);
	}

	/**
	**	@dev  	withdraws eth from dev team's account balance 
	**	@param  amount - the amount to withdraw
	**/														
    function adminWithdraw(uint amount, bool all) public onlyOwner {
        if (all)
            amount = vars.teamBalance;
		require(vars.teamBalance != 0);/*, "Team has no more funds to withdraw.");*/
		require(amount != 0);/*, "Amount to withdraw should not be zero.");*/
		require(vars.teamBalance >= amount);/*, "Team should have sufficient balance to withdraw.");*/
		// Should specify specific address or should be trasferable ownership.??
		// transfers amount to owner address
		msg.sender.transfer(amount);		
		// update dev team's account balance
		vars.teamBalance = vars.teamBalance.sub(amount);		
		emit onAdminWithdraw(
			msg.sender, amount
		);		
    }

	event onRegisterFromWal (
		uint256 indexed round,
		uint256 indexed tagNumber,
		address indexed user,	
		uint256 payment,
		bytes32 tagName,
		address affAddr,
		uint256 finishTime
	);

	event onRegisterFromBal (
		uint256 indexed round,
		uint256 indexed tagNumber,
		address indexed user,	
		uint256 payment,
		bytes32 tagName,
		address affAddr,
		uint256 finishTime
	);

	event onUpdateScore (
		uint256 indexed round,
		uint256 indexed tagNumber,
		uint256 indexed finishTime			
	);
	
	event onReserveNameFromWal(
		address indexed user,		
		bytes32 indexed name,
		uint256 payment,
		address affAddr
	);

	event onReserveNameFromBal(
		address indexed user,		
		bytes32 indexed name,
		uint256 payment,
		address affAddr
	);
	
	event onBuyWeaponFromWal (
		uint256 indexed round,
		uint256 indexed weapon,
		address indexed user,		
		uint256 payment,
		uint256 peelPrice,
		address affAddr,		
		uint256 nWeapon
	);
	
	event onBuyWeaponFromBal (
		uint256 indexed round,
		uint256 indexed weapon,
		address indexed user,		
		uint256 payment,
		uint256 peelPrice,
		address affAddr,
		uint256 nWeapon	
	);
	
	event onThrowBomb (
		uint256 indexed round,
		uint256 indexed tagNumber,
		address indexed user,
		uint256 fromRunner,
		uint256 nBomb,
		uint256 nShield,
		uint256 finishTime
	);

	event onUnShield (
		uint256 indexed round,
		uint256 indexed tagNumber,
		address indexed user,	
		uint256 fromRunner,
		uint256 nShield
	);
		
	event onThrowPeel (
		uint256 indexed round,
		uint256 indexed tagNumber,
		address indexed user,
		uint256 fromRunner,
		uint256 nPeel,
		uint256 finishTime
	);
	
	event onEatSpinach (
		uint256 indexed round,
		uint256 indexed tagNumber,
		address indexed user,
		uint256 finishTime	
	);
	
	event onPutShield (
		uint256 indexed round,
		uint256 indexed tagNumber,
		address indexed user,
		uint256 nShield	
	);
	
	event onSetSupportersShare (
		uint256 indexed round,
		uint256 indexed tagNumber,
		address indexed user,	
		uint256 share			
	);
	
	event onHasAWinner (
		uint256 indexed round,
		uint256 end,
		uint256 potWon,
		uint256[] winners,
		uint256 nWinners
	);
	
	event onGameStart (
		uint256 activeRound,
		uint256 newRegisterRound
	);
	
	event onCloseRound (
		uint256 indexed round,
		uint256 potWon,
		uint256 potTransferred,
		uint256 nextStart	
	);
	
	event onQuickCloseRound (
		uint256 indexed round,
		uint256 potTransferred,				
		uint256 nextStart			
	);
	
	event onClaimSupporterWinning (
		uint256 round,
		uint256 winner,
		address supporter,
		uint256 ethClaim,
		uint256 nShares,
	    uint256 supportersShare,
		uint256 potWon,
		uint256 nWinners
	);
	
	event onWithdraw (
		address indexed user,
		uint256 amount		
	);

	event onClaimShares (
		uint256 indexed round,	
		address indexed user,
		uint256 shares2Claim,
		uint256 ethClaimed,
		uint256 totShares,
		uint256 sharesClaimed
	);
	
	event onAdminWithdraw (
		address indexed user,
		uint256 amount			
	);		
	
}




