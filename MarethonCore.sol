pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./SkipListBoard.sol";
import "./SafeMath.sol";

library MarethonCore {
    using SkipListBoard for SkipListBoard.SkipList;
    using SafeMath for uint256;    
	// Fees for registration of runners and reservation of a runner/tag name
	// You can reserve a tag name anytime and it will be yours forever
	// No other person can use it in any round/game.
	// Reserved name can also be used as affiliate name.
	// If you don't want to pay for a reservation fee, you can use your address as your affiliate name
	uint256 constant private REGISTRATION_FEE = 100 finney;
	uint256 constant private RESERVATION_FEE = 100 finney;
	
	// Since solidity doesn't support floats, we defined a precision of 18 digits for
	// distance, time, money and share units
	uint256 constant private PRECISION = 1 ether; 	
    
	// Each runner will have constant speed of half-meter(0.5)/sec
    // If you buy a spinach, you can boost your speed to 1 meter/sec
    // You can always eat a spinach, but when a banana peel or bomb is thrown on you, you go back to normal speed
    uint256 constant private BOOSTED_SPEED = 1 * PRECISION;		// 1 meter per sec
    uint256 constant private RUNNER_SPEED = BOOSTED_SPEED / 2;  // half-meter per sec
    uint256 constant private FULL_MARETHON = 3600 * PRECISION; // Marathon in meter units
	
	// Time in seconds to finish the marathon on normal speed						
	uint256 constant private MARETHON_TIME = FULL_MARETHON * PRECISION / RUNNER_SPEED; 


    // Users can buy two items to delay its opponents, a bomb, a banana peel
	// A bomb will put runners 50 meters back
	// A banana peel will put runners 5 meters back
    uint256 constant private BOMB_POWER = 50 * PRECISION;
    uint256 constant private PEEL_POWER = 5 * PRECISION;

	// Price of each weapon is based on the peel price.
	// Like bomb is 7X the price of a banana peel, but 10 times more powerful
	// Listed below are the prices
	// As the price of the pot increases, the price of the banana peel increases, and so as the other weapons.
    uint256 constant private PEEL_XP = 1;
    uint256 constant private BOMB_XP = 7;
    uint256 constant private SPINACH_XP = 15;
    uint256 constant private SHIELD_XP = 10;
	
    // Those who were not able to register, they can still participate in the marathon by supporting their favorite runners.
	// Supporters can also buy bombs and banana peels and use it to delay their favorite runner's opponents. They can also give shield
	// to their favorite runner. As a reward for supporting a runner, if the runner wins, supporters get a percentage of the winnings
    // of the runner they supported. It's based on the supporter's percentage set by the runner during the game.
    // Only runners themselves can buy and eat spinach. If you're already in spinach, you can no longer eat spinach. But if you were bombed or thrown a banana peel, you can again eat spinach. So be on guard, 

	// A bomber can only bomb somebody 20x at a time. If he wants to bomb the runner again he has throw him bombs again 
	// (i.e. transact again to bomb your opponent). A runner can also shield himslef from bombs, but he can only shield from bombs 30%
	// of the time. For example, if he was bombed 30 times, he can only shield himself 9 times. You can save your shields and put shields
	// on your self when needed. But you can also be unshielded by other runners.
	uint256 constant private BOMB_AT_A_TIME = 20 ether;
	uint256 constant private MAX_SHIELD_PERCENT = 30;
	
	
    // For all ETHs spent (except reservation) on the platform, they will be distributed as follows:
    //      50% gets added to the Current Pot
    //      38% goes to users' shares and distributed proportionally
    //      10% goes to user's affiliate,
    //          If user has no affiliate, 5% goes to the pot and 5% goes to the dev team
    //       2% goes to the dev team
    uint256 constant private POT_SHARE = 50;
    uint256 constant private USERS_SHARE = 38;
    uint256 constant private AFF_SHARE = 10;

    // Prize Pot Distribution for the winnner will be as follows:
    //      50% goes to the winner and its supporters
    //          (The runner can set the supporter's percentage share)
	//		35% goes to the users who participated in the game/round divided in equal shares.
    //      13% goes to the next Marethon's pot
    //       2% goes to the Dev team
    uint256 constant private WINNER_SHARE = 50;
	uint256 constant private PLAYERS_SHARE = 35;
    uint256 constant private NEXT_POT_SHARE = 13;
    uint256 constant private TEAM_SHARE = 2;

    // Status of rounds
	uint256 constant private NOT_YET_STARTED = 0; // Game/round registration
    uint256 constant private REGISTRATION = 1; // Game/round registration
    uint256 constant private GAME_ONGOING = 2; // Round started and next round registration opens
    uint256 constant private GAME_ENDED = 3; // Current round ended, winners identified
	uint256 constant private GAME_CLOSED = 4; // Current round closed, winnings distributed, Waiting for registration of next round to end
	uint256 constant private GAME_CLOSED_QUICK = 5; // Games was closed quickly because there was no runner who registered.

	// Weapons types
	uint256 constant private PEEL = 1;
	uint256 constant private BOMB = 2;
	uint256 constant private SPINACH = 3;
	uint256 constant private SHIELD = 4;
	
	// You can only register 5% of the runners in a game/round so that no one can monopolize the game.
    uint256 constant private MAX_REGISTER_PERCENT = 5;	
    uint256 constant private INIT_PEEL_PRICE = (REGISTRATION_FEE * POT_SHARE / 100) * PEEL_POWER / FULL_MARETHON;	
	// Return/Error Codes
	uint256 constant private INVALID_NAME = 1001;
	uint256 constant private INVALID_NAME_LENGTH = 1002;
	uint256 constant private INVALID_START_KEY = 1003;	
	uint256 constant private INVALID_INDEX = 1004;	
	uint256 constant private INVALID_SUPPORTER = 1005;
	uint256 constant private INVALID_ENEMY = 1006;	
	uint256 constant private INVALID_RUNNER = 1007;
	uint256 constant private INVALID_ROUND = 1008;	
	
	uint256 constant private NO_ROUND_ZER0 = 1101;
	uint256 constant private NO_RUNNER_ZERO = 1102;	
	uint256 constant private NO_RUNNERS = 1103;				
	uint256 constant private NO_SUPPORTERS = 1104;
	uint256 constant private NO_ENEMIES = 1105;	
	uint256 constant private NO_USER_ROUNDS = 1106;	
	uint256 constant private NO_RESERVED_NAMES = 1107;		
	
	uint256 constant private ROUND_NOT_ACTIVE = 1201;
	uint256 constant private ROUND_NOT_CLOSED = 1202;		
	uint256 constant private ROUND_NON_EXISTENT	= 1203;
	uint256 constant private ROUND_CLOSED_QUICK	= 1204;
	uint256 constant private ROUND_ON_REGISTRATION = 1205;		
	
	uint256 constant private MAX_ENTRIES_REACHED = 1301;
	
	uint256 constant private HAS_NO_RUNNERS = 1401;
	uint256 constant private HAS_WINNER = 1402; 	
	

	
	// Contains the data of the each game/round.
    struct GameData {
        uint256 status;				// Status of a game/round
        uint256 nRunners;			// How many runners are participating
		uint256 totEth;				// Stores the total ether spent on the game/round
        uint256 potWon;				// The pot to be given to winners
        uint256 start;				// time when the game/round starts
        uint256 end;				// time when a winner crosses the finish line
		uint256 nUsers;				// How many users participated in this round. User can have many runners in a round.
		Shares shares;				// Contains the breakdown of shares for this game/round		
		mapping (uint256 => RunnerData) runners; 	// Contains the data of each runner
													// Key=tagNumber
		mapping (bytes32 => bool) tagNameTaken; 	// Contains data to determine if a tag name has been taken for this game/round
													// Key=tagName
		uint256[] winners;			// The winners who crossed the finish line (there might be more than one winner when they crossed	
									// finish line at the same time

    }

    struct RunnerData {
        address owner;				// The addres who register this runner
        bytes32 tagName;           	// The tag name of this runner
        uint256 metersRan;			// The current distance this runner runs at checkpoint time	
        uint256 runnerSpeed;		// The runner speed, can be normal speed or boosted speed
        uint256 checkPoint;			// The time when the last finish time of this runner was calculated
        uint256 finishTime;			// The time the runner will finish if there are no delays
        uint256 supportersShare;	// Holds the percentage of the pot to be given by the runner to his supporters when he wins
        uint256 xSpinachAte;        // How many times this runner ate spinach
        uint256 xShielded;			// How many times this was shielded by himself and by his supporters
        uint256 xBombed;
        uint256 xPeeled;
        uint256 nShield;			// How many shield weapons this runner is using
        bool    onSpinach;          // Indicates when a runner is on boosted speed        
		EnemyData enemy;			// Holds the details of this runner's enemies (i.e. the runners who bombed/threw a peel on him)
		SupportData support;		// Holds the details of the users who gave their support to this runner and will be given a share
									// of the winning if this runner wins
    }

    struct EnemyData {
        uint256[] enemies;							// The runners who threw a bomb or peel on a particular runner
        mapping (uint256 => EnemyDetails) details;	// Details the number of bombs/peels thrown by each of the runner's enemies
    }
	
    struct EnemyDetails {
        uint256 bombThrown;			// Number of bombs thrown
        uint256 peelThrown;			// Number of peels thrown
    }		
	
    struct SupportData {
        address[] supporters;		// The address of the users who supported a particular runner
        mapping (address => SupportDetails) details; // Details what support given by the user and the corresponding number of shares 
		uint256 totShares;			// Total shares of all the runner's supporters
    }	
	
    struct SupportDetails {
        uint256 bombGiven;			// The bombs given by a particular supporter
        uint256 peelGiven;			// The peels given by a particular supporter
		uint256 shieldGiven;		// The shields given by a particular supporter
		uint256 nShares;			// The combined shares of a particular supporter
		bool     claimed;
    }
	
    struct Shares {
        uint256 potShares;			// The active pot
        uint256 usersShares;		// The ethers to be shared by Users who participated in the game/round
        uint256 teamShares;			// The portion that goes to the team
		uint256 totShares;			// The total shares
		uint256 potTransferred;		// The pot transferred from the previous round
    }
	
    struct UserData {
        uint256 ethBalance;							// The total ethers of a user in the system (this includes overflow payments, 
													// ethers claimed for withdrawal
		address affAddr;
        uint256[] rounds;							// The rounds participated in by a user
		mapping (uint256 => UserGameData) gameData; // Game specific data of a user for this game/round
													//key=roundNumber		
		bytes32[] resTagNames;						// The reserved tag names of a user
	}

	struct UserGameData {
		uint256 shares;					// THe total shares of a user for this game/round
		uint256 sharesClaimed;			// The total ethers claimed by a user fro this game/round
		uint256[] runners;				// The runners registered by a user for this game/round
		uint256[] supportedRunners;		// The runners supported by a user for this game/round
		Weapons weapons;				// Breakdown of weapons of a user for this game/round
	}
	
    struct Weapons {
        uint256 nBomb;		// The number of bombs of a user for this game/round
        uint256 nPeel;		// The number of peels of a user for this game/round
        uint256 nSpinach;	// The number of spinaches of a user for this game/round
		uint256 nShield;	// The number of shields of a user for this game/round
    }
	
	struct CoreVars {
		uint256 registerRound;	// Holds the current registration round
		uint256 activeRound;		// Holds the current active (i.e. race started) round
		uint256 teamBalance;		// The dev team's ETHs balance
		uint256 userCount;   	// Number of users who participated in the platform
		address defAffAddr;
		mapping (bytes32 => address) reservedNames; // Contains reserved names and its owners
	}
	
    struct PriceVars {
        uint256 xPrice;
        uint256 peelPrice;
        uint256 nWeapon;
    }
	    
    struct BuyArgs {
        uint256 round;
        uint256 w;
        uint256 amount;
        address affAddr;
        bool fromWallet;
    }

    struct ClaimVars {
        uint256 runnerTime;
        uint256 nWinners;
        uint256 potWon;
        uint256 supportShare;
        uint256 ethClaim;
    }
    
    struct RegVars {
        uint256 payment;
        bytes32 name;
        uint256 regShares;
        uint256 peelPrice;
        uint256 retCode;
        uint256 tagNumber;
    }
	
	/**
	**	@dev  	validates and makes a tag name valid.
	**    		tag names should be 1 to 32 characters.
	&&			tag names should only contain alphanumeric and spaces
	**			strips leading and trailing spaces
	**			reduces spaces in the middle to one (e.g. " this    is   an example  ", will be converted to "this is an example")
	**	@param  tagName - the tag name to be made valid
	**  @return  the validated and converted valid name
	**/
    function makeValid (string tagName) internal pure returns (uint256 retCode, bytes32 validName) {
		bytes memory tmpS = bytes(tagName);
		uint256 slen = tmpS.length;
		if (slen == 0 || slen > 32) {
			retCode = INVALID_NAME_LENGTH;
			return;
		}
		uint j;
		
		for (uint256 i=0;i < slen;i++) {
			if (!(tmpS[i] == 0x20 || (tmpS[i] > 0x60 && tmpS[i] < 0x7b) || (tmpS[i] > 0x2f && tmpS[i] < 0x3a) ||
			(tmpS[i] > 0x40 && tmpS[i] < 0x5b))) {
				retCode = INVALID_NAME;
				return;
				// require(false,"Name must only contain alphanumeric and space characters.");
			}
			if (j == 0) {
				if (tmpS[i] == 0x20) // ignores leading spaces
					continue;
			} else if (tmpS[i] == 0x20 && tmpS[i-1] == 0x20) // reduce middle spaces to one
				continue;
			tmpS[j++] = tmpS[i];
		}
		// removes trailing spaces
		if (tmpS[j-1] == 0x20)
			tmpS[j-1] = 0x0;	
		while (j < slen)
			tmpS[j++] = 0x0;
		// convert from bytes to bytes32
				
		assembly {
			validName := mload(add(tmpS, 32))
		}
    }	

	/**
	**	@dev  	updates a runner's finish time (i.e. the calculated time when a runner finishes the race) in the scoreboard
	**			the scoreboard (a skip list data structure) holds all the finish time of the runners. the one with the least
	**			finish time will be the winner once current time gets over the leading finish time.
	**	@param  round - the game's current round
	**  @param  tagNumber - the runner number 
	**/					
	function updateScore (GameData storage game, SkipListBoard.SkipList storage sboard, uint256 round, uint256 tagNumber) internal {		
		sboard.update(tagNumber,game.runners[tagNumber].finishTime);
		// We only log score updates during actual race, because everyone has the same finish time during registration
		emit onUpdateScore(
			round, tagNumber, game.runners[tagNumber].finishTime
		);		
	}	
	
	/**
	**	@dev  	registers a runner
	**	@param  tagName - the runner's tagName
	**	@param  affi - the affiliate name/address of the transaction
	**/							
	// TODO do we need to check msg.sender == 0?
    function register(
		GameData storage game, UserData storage user, UserData storage aff, SkipListBoard.SkipList storage sboard, 
		string tagName, address affAddr, CoreVars storage vars, bool fromWallet
	) public 
	{
	    RegVars memory rVars;

		if (fromWallet) {
			rVars.payment = msg.value;
			require(rVars.payment >= REGISTRATION_FEE);/*, "Payment should be equal or more than the registration fee.");*/			
		} else {
			rVars.payment = REGISTRATION_FEE;
			require(user.ethBalance >= rVars.payment);			
		}
		(rVars.retCode, rVars.name) = makeValid(tagName);
		require(rVars.retCode != INVALID_NAME);/*, "Invalid tag name.");*/
		require(rVars.retCode != INVALID_NAME_LENGTH);/*, "Invalid tag name length.");*/
		require (vars.reservedNames[rVars.name] == 0 || vars.reservedNames[rVars.name] == msg.sender);/*, "Tag name should not be reserved by any other.");*/	
        require (
            (user.gameData[vars.registerRound].runners.length + 1) * 100 <= game.nRunners * MAX_REGISTER_PERCENT ||
			user.gameData[vars.registerRound].runners.length == 0);/*,*/
//            "A user only maximally own 5% of the runners. Register again when more have registered."
        //);
        require (game.tagNameTaken[rVars.name] == false);/*, "Tag name should not have been taken by others.");*/

        rVars.tagNumber = game.nRunners + 1; // new tag number generated for runner. 
		
        if (user.rounds.length == 0) { // First time to participate
            user.rounds.push(vars.registerRound);
			game.nUsers++;			
			if (user.resTagNames.length == 0)
				vars.userCount++;			
        } else if (user.gameData[vars.registerRound].runners.length == 0 &&
				   user.gameData[vars.registerRound].shares == 0) { // First time to participate in this round
			user.rounds.push(vars.registerRound);
			game.nUsers++;
        }
		// store initial race details
        game.runners[rVars.tagNumber].tagName = rVars.name;
        game.runners[rVars.tagNumber].owner = msg.sender;
        game.runners[rVars.tagNumber].runnerSpeed = RUNNER_SPEED;
		game.runners[rVars.tagNumber].checkPoint = game.start;
		game.runners[rVars.tagNumber].finishTime = game.runners[rVars.tagNumber].checkPoint + MARETHON_TIME;
		updateScore(game, sboard, vars.registerRound, rVars.tagNumber); // store runner's default finish time in scoreboard
		user.gameData[vars.registerRound].runners.push(rVars.tagNumber); // update owner's runner list
        game.tagNameTaken[rVars.name] = true; // tag name is now taken
		if (rVars.payment > REGISTRATION_FEE && fromWallet)	// excess eth payments goes to user's account balance
			user.ethBalance = user.ethBalance.add(rVars.payment.sub(REGISTRATION_FEE));
		else if (!fromWallet)
			user.ethBalance = user.ethBalance.sub(REGISTRATION_FEE);
			
		// Update total shares and user's shares
		rVars.peelPrice = calcPeelPrice(game);
		if (rVars.peelPrice == 0)    
		    rVars.peelPrice = INIT_PEEL_PRICE;
	    rVars.regShares = REGISTRATION_FEE.mul(PRECISION).div(rVars.peelPrice);		
		game.shares.totShares = game.shares.totShares.add(rVars.regShares);
		user.gameData[vars.registerRound].shares = user.gameData[vars.registerRound].shares.add(rVars.regShares);
		game.nRunners++;	
        distributePayment(game, REGISTRATION_FEE, aff, affAddr, vars);	// distribute the payment among sharing entities

		if (fromWallet)
			emit onRegisterFromWal(
				vars.registerRound, rVars.tagNumber, msg.sender, rVars.payment, rVars.name, affAddr, game.runners[rVars.tagNumber].finishTime
			);		
		else
			emit onRegisterFromBal(
				vars.registerRound, rVars.tagNumber, msg.sender, rVars.payment, rVars.name, affAddr, game.runners[rVars.tagNumber].finishTime
			);			
    }
	
	function reserveName(
		UserData storage user, string tagName, UserData storage aff, 
		address affAddr, CoreVars storage vars, bool fromWallet
	) public 
	{
		uint256 payment;
		if (fromWallet) {
			payment = msg.value;
			require(payment >= RESERVATION_FEE);/*, "Payment should be equal or more than the registration fee.");*/			
		} else {
			payment = RESERVATION_FEE;
			require(user.ethBalance >= payment);			
		}

		bytes32 name;
		uint256 retCode;
		(retCode, name) = makeValid(tagName);
		require(retCode != INVALID_NAME);/*, "Invalid tag name.");*/
		require(retCode != INVALID_NAME_LENGTH);/*, "Invalid tag name length.");*/
		require (vars.reservedNames[name] == 0);/*, "Tag name should not be reserved by any other.");*/
		
		if (user.resTagNames.length == 0 && user.rounds.length == 0)
			vars.userCount++;			
		
		vars.reservedNames[name] = msg.sender; // reserve the name
		user.resTagNames.push(name); // update user's list of reserved name
		if (payment > RESERVATION_FEE && fromWallet)	// excess eth payments goes to user's account balance
			user.ethBalance = user.ethBalance.add(payment.sub(RESERVATION_FEE));
		else if (!fromWallet)
			user.ethBalance = user.ethBalance.sub(RESERVATION_FEE);

		if (affAddr != 0) { // if there's an affiliate, payment goes to affiliate and dev team
		    uint256 hAffShare = RESERVATION_FEE / 2;
			aff.ethBalance = aff.ethBalance.add(hAffShare);
			vars.teamBalance = vars.teamBalance.add(RESERVATION_FEE - hAffShare);			
		} else	// otherwise it all goes to dev team fund for marketing/development of platform
			vars.teamBalance = vars.teamBalance.add(RESERVATION_FEE);
		if (fromWallet)	
			emit onReserveNameFromWal(msg.sender, name, payment, affAddr);	
		else
			emit onReserveNameFromBal(msg.sender, name, payment, affAddr);			
	}
	
	/**
	**	@dev  	calculates the current banana peel price
	**	@param  round - the game's round
	**	@return  peelPrice- the latest peelPrice for this round
	**/					
    function calcPeelPrice(GameData storage game) internal view returns (uint256 peelPrice) {
		if (game.nRunners != 0)
			peelPrice = game.shares.potShares.mul(PEEL_POWER).div(FULL_MARETHON).div(game.nRunners);
		else
			peelPrice = 0;
    }
	
	/**
	**	@dev  	buy a weapon from user's account balance
	**	@param  round - the game's round
	**	@param  w - what type of weapon is being bought	
	**	@param  amount - payment amount
	**  @param  affi - affiliate name
	**/
	
	function buyWeapon(
		GameData storage game, UserData storage user, UserData storage aff, SkipListBoard.SkipList storage sboard, 
		BuyArgs memory  buyArgs, CoreVars storage vars
	) public returns (uint256)
	{
	    PriceVars memory tmpVars;
	    
		require(buyArgs.round != 0);/*, "There is no round zero.");*/
        require (game.status == REGISTRATION || game.status == GAME_ONGOING);/*,*/
  //      "Buying weapons is only allowed during registration and the race itself.");
        if (!buyArgs.fromWallet)
		    require(user.ethBalance >= buyArgs.amount);/*, "Buyer should have sufficient balance.");*/

		tmpVars.xPrice =  buyArgs.w == PEEL ? PEEL_XP : (buyArgs.w == BOMB ? BOMB_XP : (buyArgs.w == SPINACH ? SPINACH_XP :(buyArgs.w == SHIELD ? SHIELD_XP : 0)));
		require(tmpVars.xPrice != 0);/*, "Invalid weapon.");*/
		if (buyArgs.w == SPINACH)
			require(user.gameData[buyArgs.round].runners.length != 0);/*, "Only users with runners are allowed to buy spinaches.");*/
		
		tmpVars.peelPrice = calcPeelPrice(game);
		if (tmpVars.peelPrice != 0)
			require(buyArgs.amount >= tmpVars.peelPrice);/*, "Payment should be equal or greather than Banana Peel Price.");*/

		if (game.status == REGISTRATION)
			require(tmpVars.peelPrice != 0);/*, "Buying weapons is not allowed until there are registered runners.");*/
		// Race started without a runner, close the round quickly			
		if (game.status == GAME_ONGOING && tmpVars.peelPrice == 0) {
			if (buyArgs.fromWallet)
				user.ethBalance = user.ethBalance.add(msg.value);			
			return HAS_NO_RUNNERS;
		} else {
			// If there's a winner already, close the round, refund payment on user's balance.		
			if (game.status == GAME_ONGOING) {
				if (hasAWinner(game, sboard, vars.activeRound)) {
					if (buyArgs.fromWallet)
						user.ethBalance = user.ethBalance.add(msg.value);						
					return HAS_WINNER;
				}
			}
			tmpVars.nWeapon = buyArgs.amount.mul(PRECISION).div(tmpVars.peelPrice.mul(tmpVars.xPrice));
			// uint256 weaponShare = nWeapon.mul(xPrice); 
			// Update user's weapons			
			if (buyArgs.w == PEEL)
				user.gameData[buyArgs.round].weapons.nPeel = user.gameData[buyArgs.round].weapons.nPeel.add(tmpVars.nWeapon);
			else if (buyArgs.w == BOMB)
				user.gameData[buyArgs.round].weapons.nBomb = user.gameData[buyArgs.round].weapons.nBomb.add(tmpVars.nWeapon);
			else if (buyArgs.w == SPINACH)
				user.gameData[buyArgs.round].weapons.nSpinach = user.gameData[buyArgs.round].weapons.nSpinach.add(tmpVars.nWeapon);
			else if (buyArgs.w == SHIELD)
				user.gameData[buyArgs.round].weapons.nShield = user.gameData[buyArgs.round].weapons.nShield.add(tmpVars.nWeapon);			

			if (user.rounds.length == 0) { // First time to participate
				user.rounds.push(buyArgs.round);
				game.nUsers++;				
				if (user.resTagNames.length == 0)
					vars.userCount++;								
			} else if (user.gameData[buyArgs.round].shares == 0 &&
					   user.gameData[buyArgs.round].runners.length == 0) { // First time to participate in this round
				user.rounds.push(buyArgs.round);
				game.nUsers++;
			}
				
			// Update total shares and user's shares
			game.shares.totShares = game.shares.totShares.add(tmpVars.nWeapon.mul(tmpVars.xPrice));
			user.gameData[buyArgs.round].shares = user.gameData[buyArgs.round].shares.add(tmpVars.nWeapon.mul(tmpVars.xPrice));
			if (!buyArgs.fromWallet)
				user.ethBalance = user.ethBalance.sub(buyArgs.amount); 
				
			distributePayment(game, buyArgs.amount, aff, buyArgs.affAddr, vars);
            if (buyArgs.fromWallet)
				emit onBuyWeaponFromWal(
					buyArgs.round, buyArgs.w, msg.sender, msg.value, tmpVars.peelPrice, buyArgs.affAddr, tmpVars.nWeapon
				);						
			else
				emit onBuyWeaponFromBal(
					buyArgs.round, buyArgs.w, msg.sender, buyArgs.amount, tmpVars.peelPrice, buyArgs.affAddr, tmpVars.nWeapon
				);			

		}
		return 0;
    }	
	
   /**
	**	@dev  	distributes payment to pot, users shares, affiliate share and dev team share, 
	**	@param  round - the game's round
	**	@param  payment - the payment 
	**  @param  affAddr - affiliate's address
	**/							
    function distributePayment(GameData storage game, uint256 payment, UserData storage aff, address affAddr, CoreVars storage vars) internal {
        game.shares.potShares = game.shares.potShares.add(payment.mul(POT_SHARE).div(100));
        game.shares.usersShares = game.shares.usersShares.add(payment.mul(USERS_SHARE).div(100));
		
		uint256 affShare = payment.mul(AFF_SHARE).div(100);
		// If there's no affiliate, split the affiliate share to dev team and the users share
		if ((affAddr != 0) && (affAddr != vars.defAffAddr))
			aff.ethBalance = aff.ethBalance.add(affShare);
		else {
			uint256 hAffShare = affShare / 2;
			game.shares.teamShares = game.shares.teamShares.add(hAffShare);
			vars.teamBalance = vars.teamBalance.add(hAffShare);			
			game.shares.usersShares = game.shares.usersShares.add(affShare - hAffShare);
		}
		
		uint256 teamShare = payment.mul(TEAM_SHARE).div(100);
        game.shares.teamShares = game.shares.teamShares.add(teamShare);
		vars.teamBalance = vars.teamBalance.add(teamShare);
		// Update total eth spent on this round
		game.totEth = game.totEth.add(payment);
    }
	
	/**
	**	@dev  	sets the supporters shares and enemy details
	**	@param  fromRunner - the runner who sent the weapon
	**	@param  tagNumber - the runnner who receives the weapon
	**  @param  nWeapon - number of weapons used
	**  @param  w - type of weapon	
	**/								
	function setSupportersEnemies(
		GameData storage game, UserData storage user, uint256 round, uint256 fromRunner, 
		uint256 tagNumber, uint256 nWeapon, uint256 w
	) internal 
	{
		uint256 xPrice =  w == PEEL ? PEEL_XP : (w == BOMB ? BOMB_XP : (w == SHIELD ? SHIELD_XP : 0));	
		if (xPrice == 0) // do nothing if invalid weapon
			return;
		// Update supporters share
		if (game.runners[fromRunner].owner != msg.sender)  { // You cannot be your own supporter
			uint256 nShares = nWeapon.mul(xPrice);

			// User's supported runner update
			if (game.runners[fromRunner].support.details[msg.sender].nShares == 0) {
				game.runners[fromRunner].support.supporters.push(msg.sender);
				user.gameData[round].supportedRunners.push(fromRunner);							
			}
			// Update user's contribution/support
			if (w == PEEL)
				game.runners[fromRunner].support.details[msg.sender].peelGiven = game.runners[fromRunner].support.details[msg.sender].peelGiven.add(nWeapon);
			else if (w == BOMB)
				game.runners[fromRunner].support.details[msg.sender].bombGiven = game.runners[fromRunner].support.details[msg.sender].bombGiven.add(nWeapon);
			else if (w == SHIELD)
				game.runners[fromRunner].support.details[msg.sender].shieldGiven = game.runners[fromRunner].support.details[msg.sender].shieldGiven.add(nWeapon);		
			// Update user's share on the runner's support
			game.runners[fromRunner].support.details[msg.sender].nShares = game.runners[fromRunner].support.details[msg.sender].nShares.add(nShares);
			// Update support shares
			game.runners[fromRunner].support.totShares = game.runners[fromRunner].support.totShares.add(nShares);
		}

		// If weapon is shield, there's no damage/enemy just protection, just return
		if (w == SHIELD)
			return;

		// Update user's enemy details
		if (game.runners[tagNumber].enemy.details[fromRunner].bombThrown == 0 &&
			game.runners[tagNumber].enemy.details[fromRunner].peelThrown == 0) 
			game.runners[tagNumber].enemy.enemies.push(fromRunner);							
		
		if (w == BOMB)
			game.runners[tagNumber].enemy.details[fromRunner].bombThrown = game.runners[tagNumber].enemy.details[fromRunner].bombThrown.add(nWeapon);
		else if (w == PEEL)
			game.runners[tagNumber].enemy.details[fromRunner].peelThrown = game.runners[tagNumber].enemy.details[fromRunner].peelThrown.add(nWeapon);	
	}
	
	/**
	**	@dev  	updates the race data 
	**	@param  tagNumber - the runnner to update
	**  @param  nWeapon - number of weapons used
	**  @param  w - type of weapon	
	**/									
	function updateRaceData(
		GameData storage game, SkipListBoard.SkipList storage sboard, 
		uint256 round, uint256 tagNumber, uint256 nWeapon, uint256 w
	) internal 
	{
		uint256 wPower = w == BOMB ? BOMB_POWER : (w == PEEL ? PEEL_POWER : (w == SPINACH ? 1 : 0));
		if (wPower == 0) // no update if invalid weapon
			return;
			
		uint256 timeStamp = now.mul(PRECISION);
        uint256 checkPoint = game.runners[tagNumber].checkPoint;
        uint256 runnerSpeed = game.runners[tagNumber].runnerSpeed;
		
		// If checkpoint is zero, start time haven't been set. Set the start time as checkpoint
		if (checkPoint == 0)
			checkPoint = game.start;
		// Computes the distance the runner has run so far
		game.runners[tagNumber].metersRan = game.runners[tagNumber].metersRan.add(timeStamp.sub(checkPoint).mul(runnerSpeed).div(PRECISION));
		// If weapon is spinach, set onSpinach and boost speed
		if (w == SPINACH) {
			game.runners[tagNumber].onSpinach = true;
			game.runners[tagNumber].runnerSpeed = BOOSTED_SPEED;
		} else {
			// Calcuate meters to go back, if bomb/banana peel is thrown
			// if new position will be past the starting line, start at zero meters
			uint256 metersBack = nWeapon.mul(wPower).div(PRECISION);
			if (metersBack >= game.runners[tagNumber].metersRan)
				game.runners[tagNumber].metersRan = 0;
			else
				game.runners[tagNumber].metersRan = game.runners[tagNumber].metersRan.sub(metersBack);
			// Remove spinach power on this runner and bring back to noemal speed
			if (game.runners[tagNumber].onSpinach) {
				game.runners[tagNumber].onSpinach = false;
				game.runners[tagNumber].runnerSpeed = RUNNER_SPEED;
			}
		}
		// Update weapon stats
		if (w == PEEL)
			game.runners[tagNumber].xPeeled = game.runners[tagNumber].xPeeled.add(nWeapon);
		else if (w == BOMB)
			game.runners[tagNumber].xBombed = game.runners[tagNumber].xBombed.add(nWeapon);
		else
			game.runners[tagNumber].xSpinachAte = game.runners[tagNumber].xSpinachAte.add(nWeapon);		
        game.runners[tagNumber].finishTime = ((FULL_MARETHON - game.runners[tagNumber].metersRan) * PRECISION / game.runners[tagNumber].runnerSpeed) + timeStamp;
		updateScore(game, sboard, round, tagNumber);
        game.runners[tagNumber].checkPoint = timeStamp;
	}

	/**
	**	@dev  	throws bombs on a runner 
	**	@param  tagNumber - the runnner to be bombed
	**	@param  fromRunner - the runner (or supported runner) who is doing the bombing
	**  @param  nBomb - number of bombs to throw
	**/										
    function throwBomb(
		GameData storage game, UserData storage user, SkipListBoard.SkipList storage sboard, 
		uint256 round, uint256 tagNumber, uint256 fromRunner, uint256 nBomb
	) public returns (uint256 retCode)
	{
		require (game.status == GAME_ONGOING);/*, "Bombing is only allowed during the race.");		*/
        require(game.runners[tagNumber].owner != 0);/*,*/
 //           "Runner who will be bombed has to be registered."
//        );
        require(game.runners[fromRunner].owner != 0);/*,*/
//            "Bomber has to be registered."
//        );
        require(nBomb <= game.runners[tagNumber].nShield.add(BOMB_AT_A_TIME));/*, */
//			"Bomber can only bomb somebody 20 bombs at a time"
//		);		
        require(game.runners[tagNumber].owner != msg.sender);/*,*/
//            "Bomber cannot bomb his own runner"
//);
        require(nBomb <= user.gameData[round].weapons.nBomb);/*,*/
 //           "Bomber should have sufficient bombs."
 //       );		
		
		// If there's a winner already, close the round and return
        if (hasAWinner(game, sboard, round)) {
			retCode = HAS_WINNER;
            return;
		}
		// reduce the bomber's bomb
        user.gameData[round].weapons.nBomb = user.gameData[round].weapons.nBomb.sub(nBomb);
		// set the supporters of the bomber and enemies of the bombed runner
		setSupportersEnemies(game, user, round, fromRunner, tagNumber, nBomb, BOMB);
		// if there's bomb left after bombing the shields, update the bombed runner's position						
        if (game.runners[tagNumber].nShield < nBomb) {
			nBomb = nBomb.sub(game.runners[tagNumber].nShield);
			game.runners[tagNumber].nShield = 0;
			updateRaceData(game, sboard, round, tagNumber, nBomb, BOMB);			
        } 	// there are shields left, the bombed runner is unaffected, just reduce its shield.
		else
			game.runners[tagNumber].nShield = game.runners[tagNumber].nShield.sub(nBomb);
			
		emit onThrowBomb(
			round, tagNumber, msg.sender, fromRunner, nBomb, game.runners[tagNumber].nShield, 
			game.runners[tagNumber].finishTime
		);			
    }
	
	/**
	**	@dev  	removes the shields of a runner by bombing a correponding number of bombs 
	**	@param  tagNumber - the runnner to be bombed
	**	@param  fromRunner - the runner (or supported runner) who is doing the bombing
	**/											
    function unShield(
		GameData storage game, UserData storage user, SkipListBoard.SkipList storage sboard, 
		uint256 round, uint256 tagNumber, uint256 fromRunner
	) public returns (uint256 retCode)
	{
		require (game.status == GAME_ONGOING);/*, "Bombing/Unshielding is only allowed during the race.");		*/
        require(
            game.runners[tagNumber].owner != 0);/*,*/
 //           "Runner who will be bombed/unshielded has to be registered."
 //       );
        require(
            game.runners[fromRunner].owner != 0);/*,*/
  //          "Bomber has to be registered."
  //      );
        require(
            game.runners[tagNumber].owner != msg.sender);/*,*/
  //          "Bomber cannot bomb/unshield his own runner."
  //      );
        require(
            user.gameData[round].weapons.nBomb >= game.runners[tagNumber].nShield);/*,*/
 //           "Bomber should have sufficient bombs to unshield a runner."
//);		
		
		// If there's a winner already, close the round and return		
        if (hasAWinner(game, sboard, round)) {
			retCode = HAS_WINNER;		
            return;
		}
		// Get the required number of bombs to unshield the runner);/*, reduce the bomber's bomb and zero out the shields*/
		uint256 nBomb = game.runners[tagNumber].nShield;
        user.gameData[round].weapons.nBomb = user.gameData[round].weapons.nBomb.sub(nBomb);
		game.runners[tagNumber].nShield = 0;		
		// set the supporters of the bomber and enemies of the bombed runner
		setSupportersEnemies(game, user, round, fromRunner, tagNumber, nBomb, BOMB);		
		
		emit onUnShield(
			round, tagNumber, msg.sender, fromRunner, game.runners[tagNumber].nShield 
		);			
    }

	/**
	**	@dev  	throws banana peels on a runner 
	**	@param  tagNumber - the runnner to be thrown banana peels
	**	@param  fromRunner - the runner (or supported runner) who is doing the throwing
	**  @param  nPeel - number of banana peels to throw
	**/											
    function throwPeel(
		GameData storage game, UserData storage user, SkipListBoard.SkipList storage sboard, 
		uint256 round, uint256 tagNumber, uint256 fromRunner, uint256 nPeel
	) public returns (uint256 retCode)
	{
		require (
			game.status == GAME_ONGOING);/*, */
//"Throwing banana peels is only allowed during the race."
	//	);	
        require(
            game.runners[tagNumber].owner != 0);/*,*/
  //          "Runner who will be thrown a banana peel has to be registered."
  //      );
		require(
            game.runners[fromRunner].owner != 0);/*,*/
  //          "Banana peel thrower has to be registered."
  //      );
        require(
            game.runners[tagNumber].owner != msg.sender);/*,*/
//"Banana peel thrower cannot throw peels on his own runner."
  //      );
        require(
            nPeel <= user.gameData[round].weapons.nPeel);/*,*/
  //          "Banana peel thrower should have sufficient banana peels."
  //      );
        require(
			game.runners[tagNumber].nShield == 0);/*,*/
//			"Throwing a banana peel on a shielded runner has no effect."
	//	);
		// If there's a winner already, close the round and return		
        if (hasAWinner(game, sboard, round)) {
			retCode = HAS_WINNER;		
            return;
		}
		// reduce the thrower's banana peels
        user.gameData[round].weapons.nPeel = user.gameData[round].weapons.nPeel.sub(nPeel);
		// set the supporters of the thrower and enemies of the affected runner
		setSupportersEnemies(game, user, round, fromRunner, tagNumber, nPeel, PEEL);
		// update the affected runner's position
		updateRaceData(game, sboard, round, tagNumber, nPeel, PEEL);		
		
		emit onThrowPeel(
			round, tagNumber, msg.sender, fromRunner, nPeel, game.runners[tagNumber].finishTime
		);		
    }

	/**
	**	@dev  	eats a spinach and boost its runner's speed
	**	@param  tagNumber - the runnner who will eat a spinach
	**/											
    function eatSpinach (
		GameData storage game, UserData storage user, SkipListBoard.SkipList storage sboard, 
		uint256 round, uint256 tagNumber
	) public returns (uint256 retCode)
	{
		require (
			game.status == GAME_ONGOING);/*, */
	//		"Eating spinach is only allowed during the race."
//);
        require(
            game.runners[tagNumber].owner == msg.sender);/*,*/
//"Runner can only be given a spinach by himslef."
//);
        require(
            user.gameData[round].weapons.nSpinach >= 1 * PRECISION);/*,*/
       //     "Runner should have sufficient spinach to eat."
       // );
        require(
            !game.runners[tagNumber].onSpinach);/*,*/
//"Runner cannot eat another spinach if he is on spinach."
       // );
        require(
            game.runners[tagNumber].owner != 0);/*,*/
        //    "Runner has to be registered."
       // );
		
		// If there's a winner already, close the round and return		
        if (hasAWinner(game, sboard, round)) {
			retCode = HAS_WINNER;
            return;
        }

		// reduce the runner's spinach
		user.gameData[round].weapons.nSpinach = user.gameData[round].weapons.nSpinach.sub(1);
		// update the runner's position in the race
		updateRaceData(game, sboard, round, tagNumber, 1, SPINACH);		
		
		emit onEatSpinach(
			round, tagNumber, msg.sender, game.runners[tagNumber].finishTime
		);		
    }

	/**
	**	@dev  	puts shields on a runner
	**	@param  tagNumber - the runnner to be thrown banana peels
	**  @param  nShield - number of shield to put
	**/												
    function putShield (
		GameData storage game, UserData storage user, SkipListBoard.SkipList storage sboard, 
		uint256 round, uint256 tagNumber, uint256 nShield
	) public returns (uint256 retCode)	
	{
		require (
			game.status == GAME_ONGOING);/*, */
	//		"Putting shields is only allowed during the race."
//);
        require(
            game.runners[tagNumber].owner != 0);/*,*/
//"Runner who will be shielded has to be registered."
      //  );
        require(
            user.gameData[round].weapons.nShield >= nShield);/*,*/
//"Runner should have sufficient shields."
       // );
        require (
            game.runners[tagNumber].xShielded.add(nShield) * 100 <= game.runners[tagNumber].xBombed * MAX_SHIELD_PERCENT);/*,*/
          //  "Runner can only be shielded 25% of the time from bombs."
      //  );
		// If there's a winner already, close the round and return				
        if (hasAWinner(game, sboard, round)) {
			retCode = HAS_WINNER;
            return;
		}
		// set the supporter of the runner
		setSupportersEnemies(game, user, round, tagNumber, tagNumber, nShield, SHIELD);
		// reduce the shield supply of the shielder, update the number of shield of the runner
        user.gameData[round].weapons.nShield = user.gameData[round].weapons.nShield.sub(nShield);
        game.runners[tagNumber].xShielded = game.runners[tagNumber].xShielded.add(nShield);
        game.runners[tagNumber].nShield = game.runners[tagNumber].nShield.add(nShield);
		
		emit onPutShield(
			round, tagNumber, msg.sender, nShield
		);		
    }

	/**
	**	@dev  	updates the supporters share to be given by the runner when he wins
	**	@param  tagNumber - the runnner
	**	@param  share - the percentage of share to update
	**/												
    function setSupportersShare (
		GameData storage game, SkipListBoard.SkipList storage sboard, 
		uint256 round, uint256 tagNumber, uint256 share
	) public returns (uint256 retCode)	
	{
		require (game.status == GAME_ONGOING);/*, "Setting supporter share is only allowed during the race.");		*/
		require(
            game.runners[tagNumber].owner != 0);/*,*/
  //          "Runner should be registered."
 //       );
        require(
            game.runners[tagNumber].owner == msg.sender);/*,*/
//"Supporterers share can only be set by its owner."
//        );
        require(
            share > game.runners[tagNumber].supportersShare);/*,*/
//            "Support share percentage update should be greater than the current share percentage."
 //       );
		// If there's a winner already, close the round and return						
        if (hasAWinner(game, sboard, round)) {
			retCode = HAS_WINNER;
			return;
		}
		else
			game.runners[tagNumber].supportersShare = share;
			
		emit onSetSupportersShare(
			round, tagNumber, msg.sender, share
		);						
    }

	/**
	**	@dev  	claims winnings of a winner supporter
	**	@param  round - the game round
	**	@param  tagNumber - the winner's tag number	
	**/													
	function claimSupporterWinning(
		GameData storage game, UserData storage user, SkipListBoard.SkipList storage sboard, 
		uint256 round, uint256 tagNumber
	) public	
	{
	    ClaimVars memory cVars;
	    
		require(round != 0);/*, "There is no round zero.");	*/
		require(game.status == GAME_CLOSED);/*, "Round must be closed before claiming");*/
		require(tagNumber != 0);/*, "Zero runner does not exist.");			*/
		require(game.runners[tagNumber].owner != 0);/*, "Runner not registered.");*/
		cVars.runnerTime = sboard.playerMap[tagNumber]/10000000000000;
		if (cVars.runnerTime == MARETHON_TIME)
			cVars.runnerTime = game.start + MARETHON_TIME;					
		require(game.end == cVars.runnerTime);/*,"Runner not a winner");		*/
		require(game.runners[tagNumber].support.details[msg.sender].nShares != 0);/*, "You should be a supporter.");*/
		require(!game.runners[tagNumber].support.details[msg.sender].claimed);/*, "Supporter share claimed already.");*/
		
		// Calculate eth to claim
		cVars.nWinners = game.winners.length;		
		cVars.potWon = game.potWon.div(cVars.nWinners);
		cVars.supportShare = cVars.potWon.mul(game.runners[tagNumber].supportersShare).div(100);		
		cVars.ethClaim = cVars.supportShare.mul(game.runners[tagNumber].support.details[msg.sender].nShares).div(game.runners[tagNumber].support.totShares);
		
		// Transfer eth claim to user's account balance and set claimed to true
		user.ethBalance = user.ethBalance.add(cVars.ethClaim);
		game.runners[tagNumber].support.details[msg.sender].claimed = true;
		
		emit onClaimSupporterWinning(
			round, tagNumber, msg.sender, cVars.ethClaim, game.runners[tagNumber].support.details[msg.sender].nShares,
			game.runners[tagNumber].supportersShare, game.potWon, cVars.nWinners
		);				
	}
	
	/**
	**	@dev  	checks if there's already a winner, and sets the winning runner/s
	**	@return  indicates if there's already a winner
	**/													
    function hasAWinner(GameData storage game, SkipListBoard.SkipList storage sboard, uint round) internal returns(bool) {		
	
		require(game.status == GAME_ONGOING);/*, "To check a winner, race should be ongoing.");	*/

        uint256 timeNow = now.mul(PRECISION);
        uint256 top;
		uint256 topTime;
		
		// get the leader, the one with the earliest finish time 
		top = sboard.nodeMap[1][1];
		topTime = top / 10000000000000;
		// if the top is marathon time, start time was not set
		if (topTime == MARETHON_TIME)
			topTime = game.start + MARETHON_TIME;			
		// No winners yet
		if (topTime > timeNow)
			return false;
		else { // We have winner/s
			game.status = GAME_ENDED;
			game.end = topTime;
			game.potWon = game.shares.potShares.add(game.shares.potTransferred).mul(WINNER_SHARE).div(100); // Calculate the winning pot
			uint256 winner = (top / 10000) % 1000000000; // get the winning tag number
			game.winners.push(winner);	// store the winner		
			// find if there are other winners with the same finish time
			uint256 next = sboard.nodeMap[top][1]; 
			uint256 nextTime = next / 10000000000000;
			if (nextTime == MARETHON_TIME)
				nextTime = game.start + MARETHON_TIME;
			while (topTime == nextTime) {
				winner = (next / 10000) % 1000000000; // get the winning tag number
				game.winners.push(winner);	// store another winner			
				next = sboard.nodeMap[next][1];
				nextTime = next / 10000000000000;
				if (nextTime == MARETHON_TIME) // if the top is marathon time, start time was not set
					nextTime = game.start + MARETHON_TIME;				
			}
		}
		
		// TODO check if you can log array of uint in events
		emit onHasAWinner(
			round, game.end/PRECISION, game.potWon, game.winners, game.winners.length
		);		
        return true;
    }

	/**
	**	@dev  	gets the first N runners in the scoreboard
	**	@param  round - the game round
	**	@param  nRunners - number of runners to fetch
	**	@return  list of first N runners
	**/															
	function get1stLastPage(
	    GameData storage game, SkipListBoard.SkipList storage sboard, 
	    uint256 round, uint256 nRunners, bool lastPage) public view returns (
		uint256[] runners, uint256 retCode
	)
	{
		if (round == 0) retCode = NO_ROUND_ZER0;
		else if (game.status == NOT_YET_STARTED) retCode = ROUND_NON_EXISTENT;
		else if (game.status == GAME_CLOSED_QUICK) retCode = ROUND_CLOSED_QUICK;
		else if (nRunners > 50) retCode = MAX_ENTRIES_REACHED;
		else if (lastPage) return (sboard.getTopN(nRunners), retCode);
		else return (sboard.getBottomN(nRunners), retCode);
	}
	
	/**
	**	@dev  	gets the next N runners in the scoreboard starting from a particular runner
	**	@param  round - the game round
	**	@param  start from - fetch N runners starting from this runner
	**	@param  nRunners - number of runners to fetch
	**	@return  list of next N runners fetched
	**/																
	function getPrevNextPage(
		GameData storage game, SkipListBoard.SkipList storage sboard, uint256 round, 
		uint256 startFrom, uint256 nRunners, bool nextPage
	) public view returns (
		uint256[] runners, uint256 retCode
	)
	{
		if (round == 0) retCode = NO_ROUND_ZER0;
		else if (game.status == NOT_YET_STARTED) retCode = ROUND_NON_EXISTENT;
		else if (game.status == GAME_CLOSED_QUICK) retCode = ROUND_CLOSED_QUICK;
		else if (nRunners > 50) retCode = MAX_ENTRIES_REACHED;		
		else if (sboard.playerMap[startFrom] == 0) retCode = INVALID_START_KEY;				
		else if (nextPage)
		    return (sboard.getLeftN(startFrom, nRunners), retCode);
		else
            return (sboard.getRightN(startFrom, nRunners), retCode);		
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
	function getRunnerInfo(GameData storage game, uint256 round, uint256 tagNumber) public view returns (	
        address, bytes32, uint256[10] runData, bool, uint256 retCode
	)
	{
		if (round == 0) retCode = NO_ROUND_ZER0;
		else if (game.status == NOT_YET_STARTED) retCode = ROUND_NON_EXISTENT;
		else if (game.status == GAME_CLOSED_QUICK) retCode = ROUND_CLOSED_QUICK;
		else if (tagNumber == 0) retCode = NO_RUNNER_ZERO;
		else if (game.runners[tagNumber].owner == 0) retCode = INVALID_RUNNER;
		else {
		    uint256 checkPoint = game.runners[tagNumber].checkPoint;
            uint256 finishTime = game.runners[tagNumber].finishTime;
			if (checkPoint == 0) {
				checkPoint = game.start;
				finishTime = game.start.add(MARETHON_TIME);
			}
		    runData[0] = game.runners[tagNumber].metersRan;
		    runData[1] = game.runners[tagNumber].runnerSpeed;
		    runData[2] = checkPoint; 
		    runData[3] = finishTime;
		    runData[4] = game.runners[tagNumber].supportersShare;
		    runData[5] = game.runners[tagNumber].xSpinachAte;
		    runData[6] = game.runners[tagNumber].xShielded;
		    runData[7] = game.runners[tagNumber].xBombed;
		    runData[8] = game.runners[tagNumber].xPeeled;
		    runData[9] = game.runners[tagNumber].nShield;
		    return (
			    game.runners[tagNumber].owner,
			    game.runners[tagNumber].tagName,
			    runData,
			    game.runners[tagNumber].onSpinach,			    
			    retCode
	        );
		}
	}

	/**
	**	@dev  	gets the winners 5 at a time at particular index
	**	@param  round - the round
	**	@param  index - the starting index	of winners to fetch
	**  @return  winners - list of winners fetched
	**	@return  nWinners - number of winners in this round
	**/																
	function getWinners(GameData storage game, uint256 round, uint256 index) public view returns (
		uint256[5] winners, uint256 nWinners, uint256 retCode
	)
	{
		if (round == 0) retCode = NO_ROUND_ZER0;
		else if (game.status == NOT_YET_STARTED) retCode = ROUND_NON_EXISTENT;
		else if (game.status == GAME_CLOSED_QUICK) retCode = ROUND_CLOSED_QUICK;
		else if (game.status != GAME_CLOSED) retCode = ROUND_NOT_CLOSED;
		else {
			nWinners = game.winners.length;
			require(nWinners > index);/*, "Invalid index");			*/
            uint256 j;
			for (uint256 i = index; i < nWinners; i++) {
				winners[j++] = game.winners[i];
				if (i - index + 1 == 5)
					break;
			}
		}
	}
	
	/**
	**	@dev  	gets the shares of this round
	**	@param  round - the round
	**  @return  potShares - shares of the pot
	**	@return  usersShares - shares of the users
	**	@return  teamShares - shares of the dev team	
	**	@return  totShares - total shares in this round	
	**	@return  potTransferred - pot transferred from previous round	
	**/																	
	function getShares(GameData storage game, uint256 round) public view returns (
		uint256 potShares, uint256 usersShares, 
		uint256 teamShares, uint256 totShares, 
		uint256 potTransferred, uint256 retCode
	) 
	{
		if (round == 0) retCode = NO_ROUND_ZER0;
		else if (game.status == NOT_YET_STARTED) retCode = ROUND_NON_EXISTENT;
		else {
			potShares = game.shares.potShares;
			usersShares = game.shares.usersShares;
			teamShares = game.shares.teamShares;
			totShares = game.shares.totShares;
			potTransferred = game.shares.potTransferred;
		}
	}
	
	/**
	**	@dev  	gets the supporters of a particular runner in a round 10 at a time
	**	@param  round - the round 
	**	@param  tag number - runner's tag number 
	**  @return  supporters - runner's list of supporters fetched
	**	@return  nSupporters - runner's number of supporters 
	**	@return  totShares - total shares of supporters 	
	**/										
	function getSupporters(GameData storage game, uint256 round, uint256 tagNumber, uint256 index) public view returns (
		address[10] supporters, uint256 nSupporters, uint256 totShares, uint256 retCode
	) 
	{
		nSupporters = game.runners[tagNumber].support.supporters.length;
		if (nSupporters == 0) retCode = NO_SUPPORTERS;
		else if (index >= nSupporters) retCode = INVALID_INDEX;
		else if (round == 0) retCode = NO_ROUND_ZER0;
		else if (game.status == NOT_YET_STARTED) retCode = ROUND_NON_EXISTENT;
		else if (game.status == GAME_CLOSED_QUICK) retCode = ROUND_CLOSED_QUICK;
		else if (tagNumber == 0) retCode = NO_RUNNER_ZERO;
		else if (game.runners[tagNumber].owner == 0) retCode = INVALID_RUNNER;
		else if (game.status == REGISTRATION) retCode = ROUND_ON_REGISTRATION;
		else {
            uint256 j;
			for (uint256 i = index; i < nSupporters; i++) {
				supporters[j++] = game.runners[tagNumber].support.supporters[i];
				if (i - index + 1 == 10)
					break;
			}
			totShares = game.runners[tagNumber].support.totShares;
		}
	}
	
	/**
	**	@dev  	gets the details of a supporter of a particular runner in a round
	**	@param  round - the round 
	**	@param  tag number - runner's tag number 
	**	@param  supporter - runner's supporter
	**  @return  bombGiven - number of bombs given by supporter
	**	@return  peelGiven - number of peels given by supporter
	**	@return  shieldGiven - number of shields given by supporter
	**/										
/*	function getSupporterDetails(GameData storage game, uint256 round, uint256 tagNumber, address supporter) internal view returns (
		uint256 bombGiven, uint256 peelGiven, uint256 shieldGiven,
		uint256 nShares, bool claimed, uint256 retCode
	) 
	{
		if (round == 0) retCode = NO_ROUND_ZER0;
		else if (game.status == NOT_YET_STARTED) retCode = ROUND_NON_EXISTENT;
		else if (game.status == GAME_CLOSED_QUICK) retCode = ROUND_CLOSED_QUICK;
		else if (game.status == REGISTRATION) retCode = ROUND_ON_REGISTRATION;		
		else if (tagNumber == 0) retCode = NO_RUNNER_ZERO;
		else if (game.runners[tagNumber].owner == 0) retCode = INVALID_RUNNER;
		else if (game.runners[tagNumber].support.supporters.length == 0) retCode = NO_SUPPORTERS;		
		else if (game.runners[tagNumber].support.details[supporter].nShares == 0) retCode = INVALID_SUPPORTER;
		else {
			bombGiven = game.runners[tagNumber].support.details[supporter].bombGiven;
			peelGiven = game.runners[tagNumber].support.details[supporter].peelGiven;		
			shieldGiven = game.runners[tagNumber].support.details[supporter].shieldGiven;
			nShares = game.runners[tagNumber].support.details[supporter].nShares;
			claimed = game.runners[tagNumber].support.details[supporter].claimed;
		}
	}
*/
	/**
	**	@dev  	gets the enemies of a particular runner in a round 10 at a time
	**	@param  round - the round 
	**	@param  tag number - runner's tag number 
	**	@param  index - the starting index	of enemies to fetch
	**  @return  enemies - runner's list of enemies fetched
	**	@return  nEnemies - runner's number of enemies 
	**/										
	function getEnemies(GameData storage game, uint256 round, uint256 tagNumber, uint256 index) public view returns (
		uint256[3][10] enemies, uint256 nEnemies, uint256 retCode
	) 
	{
		nEnemies = game.runners[tagNumber].enemy.enemies.length;
		if (nEnemies == 0) retCode = NO_ENEMIES;
		else if (index >= nEnemies) retCode = INVALID_INDEX;
		else if (round == 0) retCode = NO_ROUND_ZER0;
		else if (game.status == NOT_YET_STARTED) retCode = ROUND_NON_EXISTENT;
		else if (game.status == GAME_CLOSED_QUICK) retCode = ROUND_CLOSED_QUICK;
		else if (game.status == REGISTRATION) retCode = ROUND_ON_REGISTRATION;		
		else if (tagNumber == 0) retCode = NO_RUNNER_ZERO;
		else if (game.runners[tagNumber].owner == 0) retCode = INVALID_RUNNER;
		else {	
            uint256 j;
			for (uint256 i = index; i < nEnemies; i++) {
				enemies[j][0] = game.runners[tagNumber].enemy.enemies[i];
				enemies[j][1] = game.runners[tagNumber].enemy.details[enemies[j][0]].bombThrown;
				enemies[j][2] = game.runners[tagNumber].enemy.details[enemies[j][0]].peelThrown;
				j++;
				if (i - index + 1 == 10)
					break;
			}
		}
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
	function getUserRoundInfo (UserData storage user, uint256 round, uint256 status) public view returns (
		uint256 shares, uint256 sharesClaimed,
		uint256 nBomb, uint256 nPeel, 
		uint256 nSpinach, uint256 nShield, uint256 retCode
	) 
	{
		if (round == 0) retCode = NO_ROUND_ZER0;
		else if (status == NOT_YET_STARTED) retCode = ROUND_NON_EXISTENT;
		else if (user.rounds.length == 0) retCode = NO_USER_ROUNDS;
		else if (user.gameData[round].runners.length == 0 && 
				 user.gameData[round].shares == 0) retCode = INVALID_ROUND;
		else {
			shares = user.gameData[round].shares;
			sharesClaimed = user.gameData[round].sharesClaimed;
			nBomb = user.gameData[round].weapons.nBomb;
			nPeel = user.gameData[round].weapons.nPeel;
			nSpinach = user.gameData[round].weapons.nSpinach;
			nShield = user.gameData[round].weapons.nShield;
		}
	}

	/**
	**	@dev  	gets the rounds participated by a user 10 at a time
	**	@param  user = user's address
	**	@param  index - the starting index	of rounds to fetch
	**  @return  names - user's list of rounds fetched
	**	@return  nNames - user's number of rounds 
	**/										
	function getReservedNames(UserData storage user, uint256 index) public view returns (
		bytes32[10] names, uint256 nNames, uint256 retCode
	) 
	{
		nNames = user.resTagNames.length;
		if (nNames == 0) retCode = NO_RESERVED_NAMES;
		else if (index >= nNames) retCode = INVALID_INDEX;
		else {
            uint256 j;
			for (uint256 i = index; i < nNames; i++) {
				names[j++] = user.resTagNames[i];
				if (i - index + 1 == 10)
					break;
			}
		}
	}

	/**
	**	@dev  	gets the rounds participated by a user 10 at a time
	**	@param  user = user's address
	**	@param  index - the starting index	of rounds to fetch
	**  @return  rounds - user's list of rounds fetched
	**	@return  nRounds - user's number of rounds 
	**/										
	function getRounds(UserData storage user, uint256 index) public view returns (
		uint256[10] rounds, uint256 nRounds, uint256 retCode
	) 
	{
		nRounds = user.rounds.length;
		if (nRounds == 0) retCode = NO_USER_ROUNDS;
		else if (index >= nRounds) retCode = INVALID_INDEX;
		else {
            uint256 j;
			for (uint256 i = index; i < nRounds; i++) {
				rounds[j++] = user.rounds[i];
				if (i - index + 1 == 10)
					break;
			}
		}
	}

	/**
	**	@dev  	gets the runners of a user for a particular round 10 at a time
	**	@param  round - the round
	**	@param  user = user's address
	**	@param  index - the starting index	of runners to fetch
	**  @return  runners - user's list of runners fetched
	**	@return  nRunners - user's number of runners 
	**/										
	function getRunners(UserData storage user, uint256 round, uint256 index) public view returns (
		uint256[10] runners, uint256 nRunners, uint256 retCode
	) 
	{
		nRunners = user.gameData[round].runners.length;
		if (nRunners == 0) retCode = NO_RUNNERS;
		else if (index >= nRunners) retCode = INVALID_INDEX;
		else if (round == 0) retCode = NO_ROUND_ZER0;
		else if (user.rounds.length == 0) retCode = NO_USER_ROUNDS;
		else {
            uint256 j;
			for (uint256 i = index; i < nRunners; i++) {
				runners[j++] = user.gameData[round].runners[i];
				if (i - index + 1 == 10)
					break;
			}
		}
	}

	/**
	**	@dev  	gets the runners supported by a user for a particular round 10 at a time
	**	@param  round - the round
	**	@param  user = user's address
	**	@param  index - the starting index	of supported runners to fetch
	**  @return  runners - user's list of supported runners fetched
	**	@return  nRunners - user's number of supported runners 
	**/										
	function getSupportedRunners(UserData storage user, uint256 round, uint256 index) public view returns (
		uint256[10] runners, uint256 nRunners, uint256 retCode
	) 
	{
		nRunners = user.gameData[round].supportedRunners.length;		
		if (round == 0) retCode = NO_ROUND_ZER0;
		else if (user.rounds.length == 0) retCode = NO_USER_ROUNDS;
		else if (nRunners == 0) retCode = NO_RUNNERS;
		else if (index >= nRunners) retCode = INVALID_INDEX;
		else {		
            uint256 j;
			for (uint256 i = index; i < nRunners; i++) {
				runners[j++] = user.gameData[round].supportedRunners[i];
				if (i - index + 1 == 10)
					break;
			}
		}
	}	
	
	/**
	**	@dev  	claim/convert shares to eth
	**	@param  round - the round where shares will be claimed
	** 	@param  shares2claim - the shares to claim
	**/														
    function claimShares(UserData storage user, GameData storage game, uint256 round, uint256 shares2Claim) public {
		require(round != 0);/*, "There is no round zero.");	*/
		require(game.status != NOT_YET_STARTED);/*, "Round not yet existing.");*/
		require(game.status != GAME_CLOSED_QUICK);/*, "Round closed, no runners registered.");							*/
		require(shares2Claim > 0);/*, "Shares to claim should be greater than zero.");*/
		uint256 totShares = user.gameData[round].shares;
		uint256 sharesClaimed = user.gameData[round].sharesClaimed;
		require(totShares.sub(sharesClaimed) >= shares2Claim);//, "User should have sufficient shares to claim.");
		
		// calculate the eth to claim
		uint256 eth2Claim = game.shares.usersShares.mul(shares2Claim).div(game.shares.totShares);
		// update the shares claimed and reduce the total shares with the shares claimed
		user.gameData[round].sharesClaimed = user.gameData[round].sharesClaimed.add(shares2Claim);
		game.shares.totShares = game.shares.totShares.sub(shares2Claim);		
		// add the eth to claim to account balance and reduce the total user shares with the eth claimed
		user.ethBalance = user.ethBalance.add(eth2Claim);
		game.shares.usersShares = game.shares.usersShares.sub(eth2Claim);

		emit onClaimShares(
			round, msg.sender, shares2Claim, eth2Claim, totShares, sharesClaimed				
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
