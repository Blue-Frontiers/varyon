pragma solidity ^0.4.23;

// ----------------------------------------------------------------------------
//
// VAR 'Varyon' token public sale contract
//
// For details, please visit: http://www.blue-frontiers.com
//
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
//
// SafeMath
//
// ----------------------------------------------------------------------------

library SafeMath {

  function add(uint a, uint b) internal pure returns (uint c) {
    c = a + b;
    require(c >= a);
  }

  function sub(uint a, uint b) internal pure returns (uint c) {
    require(b <= a);
    c = a - b;
  }

  function mul(uint a, uint b) internal pure returns (uint c) {
    c = a * b;
    require(a == 0 || c / a == b);
  }
  
}


// ----------------------------------------------------------------------------
//
// Utils
//
// ----------------------------------------------------------------------------

contract Utils {
  
  function atNow() public view returns (uint) {
    return now;
  }

}


// ----------------------------------------------------------------------------
//
// Owned
//
// ----------------------------------------------------------------------------

contract Owned {

  address public owner;
  address public newOwner;

  mapping(address => bool) public isAdmin;

  event OwnershipTransferProposed(address indexed _from, address indexed _to);
  event OwnershipTransferred(address indexed _from, address indexed _to);
  event AdminChange(address indexed _admin, bool _status);

  modifier onlyOwner { require(msg.sender == owner); _; }
  modifier onlyAdmin { require(isAdmin[msg.sender]); _; }

  constructor() public {
    owner = msg.sender;
    isAdmin[owner] = true;
  }

  function transferOwnership(address _newOwner) public onlyOwner {
    require(_newOwner != address(0x0));
    emit OwnershipTransferProposed(owner, _newOwner);
    newOwner = _newOwner;
  }

  function acceptOwnership() public {
    require(msg.sender == newOwner);
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

  function addAdmin(address _a) public onlyOwner {
    require(isAdmin[_a] == false);
    isAdmin[_a] = true;
    emit AdminChange(_a, true);
  }

  function removeAdmin(address _a) public onlyOwner {
    require(isAdmin[_a] == true);
    isAdmin[_a] = false;
    emit AdminChange(_a, false);
  }

}


// ----------------------------------------------------------------------------
//
// Wallet
//
// ----------------------------------------------------------------------------

contract Wallet is Owned {
  
  address public wallet;

  event WalletUpdated(address newWallet);

  constructor() public {
    wallet = owner;
  }

  function setWallet(address _wallet) public onlyOwner {
    require(_wallet != address(0x0));
    wallet = _wallet;
    emit WalletUpdated(_wallet);
  }

}


// ----------------------------------------------------------------------------
//
// ERC20Interface
//
// ----------------------------------------------------------------------------

contract ERC20Interface {

  event Transfer(address indexed _from, address indexed _to, uint _value);
  event Approval(address indexed _owner, address indexed _spender, uint _value);

  function totalSupply() public view returns (uint);
  function balanceOf(address _owner) public view returns (uint balance);
  function transfer(address _to, uint _value) public returns (bool success);
  function transferFrom(address _from, address _to, uint _value) public returns (bool success);
  function approve(address _spender, uint _value) public returns (bool success);
  function allowance(address _owner, address _spender) public view returns (uint remaining);

}


// ----------------------------------------------------------------------------
//
// ERC20Token
//
// ----------------------------------------------------------------------------

contract ERC20Token is ERC20Interface, Owned {
  
  using SafeMath for uint;

  uint public tokensIssuedTotal = 0;
  mapping(address => uint) balances;
  mapping(address => mapping (address => uint)) allowed;

  function totalSupply() public view returns (uint) {
    return tokensIssuedTotal;
  }

  function balanceOf(address _owner) public view returns (uint balance) {
    return balances[_owner];
  }

  function transfer(address _to, uint _amount) public returns (bool success) {
    require(balances[msg.sender] >= _amount);
    balances[msg.sender] = balances[msg.sender].sub(_amount);
    balances[_to] = balances[_to].add(_amount);
    emit Transfer(msg.sender, _to, _amount);
    return true;
  }

  function approve(address _spender, uint _amount) public returns (bool success) {
    require(balances[msg.sender] >= _amount);
    allowed[msg.sender][_spender] = _amount;
    emit Approval(msg.sender, _spender, _amount);
    return true;
  }

  function transferFrom(address _from, address _to, uint _amount) public returns (bool success) {
    require(balances[_from] >= _amount);
    require(allowed[_from][msg.sender] >= _amount);
    balances[_from] = balances[_from].sub(_amount);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
    balances[_to] = balances[_to].add(_amount);
    emit Transfer(_from, _to, _amount);
    return true;
  }

  function allowance(address _owner, address _spender) public view returns (uint remaining) {
    return allowed[_owner][_spender];
  }

}


// ----------------------------------------------------------------------------
//
// LockSlots
//
// ----------------------------------------------------------------------------

contract LockSlots is ERC20Token, Utils {
  
  using SafeMath for uint;

  uint8 public constant LOCK_SLOTS = 6;
  mapping(address => uint[LOCK_SLOTS]) public lockTerm;
  mapping(address => uint[LOCK_SLOTS]) public lockAmnt;

  event RegisteredLockedTokens(address indexed account, uint indexed idx, uint tokens, uint term);
  event IcoLockSet(address indexed account, uint term, uint tokens);
  event IcoLockChanged(address indexed account, uint oldTerm, uint newTerm);

  function registerLockedTokens(address _account, uint _tokens, uint _term) internal returns (uint idx) {
    require(_term > atNow(), "lock term must be in the future"); 

    // find a slot (clean up while doing this)
    // use either the existing slot with the exact same term,
    // of which there can be at most one, or the first empty slot
    idx = 9999;  
    uint[LOCK_SLOTS] storage term = lockTerm[_account];
    uint[LOCK_SLOTS] storage amnt = lockAmnt[_account];
    for (uint i = 1; i < LOCK_SLOTS; i++) {
      if (term[i] <= atNow()) {
        term[i] = 0;
        amnt[i] = 0;
        if (idx == 9999) idx = i;
      }
      if (term[i] == _term) idx = i;
    }

    // fail if no slot was found
    require(idx != 9999, "registerLockedTokens: no available slot found");

    // register locked tokens
    if (term[idx] == 0) term[idx] = _term;
    amnt[idx] = amnt[idx].add(_tokens);
    emit RegisteredLockedTokens(_account, idx, _tokens, _term);
  }

  function lockedTokens(address _account) public view returns (uint locked) {
    uint[LOCK_SLOTS] storage term = lockTerm[_account];
    uint[LOCK_SLOTS] storage amnt = lockAmnt[_account];
    for (uint i = 0; i < LOCK_SLOTS; i++) {
      if (term[i] > atNow()) locked = locked.add(amnt[i]);
    }
  }

  function unlockedTokens (address _account) public view returns (uint unlocked) {
    unlocked = balances[_account].sub(lockedTokens(_account));
  }

  // isAvailableLockSlot does not check slot 0 which is reserved for the ICO
  
  function isAvailableLockSlot(address _account, uint _term) public view returns (bool) {
    if (_term < atNow()) return true;
    uint[LOCK_SLOTS] storage term = lockTerm[_account];
    for (uint i = 1; i < LOCK_SLOTS; i++) {
      if (term[i] < atNow() || term[i] == _term) return true;
    }
    return false;
  }

  // Slot 0 is for the ICO only

  function setIcoLock(address _account, uint _term, uint _tokens) internal {
    lockTerm[_account][0] = _term;
    lockAmnt[_account][0] = _tokens;
    emit IcoLockSet(_account, _term, _tokens);
  }

  function modifyIcoLock(address _account, uint _unixts) public onlyAdmin {
    require(lockTerm[_account][0] > atNow(), "the ICO tokens are already unlocked");
    require(_unixts < lockTerm[_account][0], "locking period can only be shortened");
    uint term = lockTerm[_account][0];
    lockTerm[_account][0] = _unixts;
    emit IcoLockChanged(_account, term, _unixts);
  }

}


// ----------------------------------------------------------------------------
//
// WBList
//
// ----------------------------------------------------------------------------

contract WBList is Owned, Utils {

  using SafeMath for uint;

  uint public constant MAX_LOCKING_PERIOD = 1827 days; // max 5 years

  mapping(address => bool) public whitelist;
  mapping(address => uint) public whitelistLimit;
  mapping(address => uint) public whitelistThreshold;
  mapping(address => uint) public whitelistLockDate;

  mapping(address => bool) public blacklist;

  event Whitelisted(address indexed account, uint limit, uint threshold, uint term);
  event Blacklisted(address indexed account);

  function processWhitelisting(address _account) internal;
  function processBlacklisting(address _account) internal;


  function addToWhitelist(address _account) public onlyAdmin {
    pWhitelist(_account, 0, 0, 0);
  }
  
  function addToWhitelistParams(address _account, uint _limit, uint _threshold, uint _term) public onlyAdmin {
    pWhitelist(_account, _limit, _threshold, _term);
  }

  function addToWhitelistMultiple(address[] _accounts) public onlyAdmin {
    for (uint i = 0; i < _accounts.length; i++) {
      pWhitelist(_accounts[i], 0, 0, 0);
    }
  }

  function addToWhitelistParamsMultiple(address[] _accounts, uint[] _limits, uint[] _thresholds, uint[] _terms) public onlyAdmin {
    require(_accounts.length == _limits.length);
    require(_accounts.length == _thresholds.length);
    require(_accounts.length == _terms.length);
    for (uint i = 0; i < _accounts.length; i++) {
      pWhitelist(_accounts[i], _limits[i], _thresholds[i], _terms[i]);
    }
  }  

  function pWhitelist(address _account, uint _limit, uint _threshold, uint _term) private {
    require(!whitelist[_account], "account is already whitelisted");
    require(!blacklist[_account], "account is blacklisted");

    // whitelisting parameter checks
    if (_threshold > 0 ) require(_threshold > _limit, "threshold not above limit");
    if (_term > 0) {
      require(_term > atNow(), "the locking period cannot be in the past");
      require(_term < atNow() + MAX_LOCKING_PERIOD, "the locking period cannot exceed 720 days");
    }

    // add to whitelist
    whitelist[_account] = true;
    whitelistLimit[_account] = _limit;
    whitelistThreshold[_account] = _threshold;
    whitelistLockDate[_account] = _term;
    emit Whitelisted(_account, _limit, _threshold, _term);

    // actions linked to whitelisting
    processWhitelisting(_account);
  } 


  function addToBlacklist(address _account) public onlyAdmin {
    pBlacklist(_account);
  }

  function addToBlacklistMultiple(address[] _accounts) public onlyAdmin {
    for (uint i = 0; i < _accounts.length; i++) {
      pBlacklist(_accounts[i]);
    }
  }

  function pBlacklist(address _account) private {
    require(!whitelist[_account], "account is whitelisted");
    require(!blacklist[_account], "account is already blacklisted");

    // add to blacklist
    blacklist[_account] = true;
    emit Blacklisted(_account);

    // actions linked to blacklisting
    processBlacklisting(_account);
  }

}


// ----------------------------------------------------------------------------
//
// Varyon ICO dates
//
// ----------------------------------------------------------------------------

contract VaryonIcoDates is Owned, Utils {  

  uint public dateIcoPresale  = 1526392800; // 15-MAY-2018 14:00 UTC
  uint public dateIcoMain     = 1527861600; // 01-JUN-2018 14:00 UTC
  uint public dateIcoEnd      = 1530367200; // 30-JUN-2018 14:00 UTC
  uint public dateIcoDeadline = 1533045600; // 31-JUL-2018 14:00 UTC

  uint public constant DATE_LIMIT = 1538316000; // 30-SEP-2018 14:00 UTC

  event IcoDateUpdated(uint8 id, uint unixts);

  constructor() public {
    require(atNow() < dateIcoPresale);
    require(dateIcoPresale < dateIcoMain);
    require(dateIcoMain < dateIcoEnd);
    require(dateIcoEnd < dateIcoDeadline);
    require(dateIcoDeadline < DATE_LIMIT);
  }

  function setDateIcoPresale(uint _unixts) public onlyOwner {
    require(atNow() < _unixts);
    require(atNow() < dateIcoPresale);
    require(_unixts < dateIcoMain);
    dateIcoPresale = _unixts;
    emit IcoDateUpdated(1, _unixts);
  }

  function setDateIcoMain(uint _unixts) public onlyOwner {
    require(atNow() < _unixts);
    require(atNow() < dateIcoMain);
    require(_unixts > dateIcoPresale);
    require(_unixts < dateIcoEnd);
    dateIcoMain = _unixts;
    emit IcoDateUpdated(2, _unixts);
  }

  function setDateIcoEnd(uint _unixts) public onlyOwner {
    require(atNow() < _unixts);
    require(atNow() < dateIcoEnd);
    require(_unixts > dateIcoMain);
    require(_unixts < dateIcoDeadline);
    dateIcoEnd = _unixts;
    emit IcoDateUpdated(3, _unixts);
  }

  function setDateIcoDeadline(uint _unixts) public onlyOwner {
    require(atNow() < _unixts);
    require(atNow() < dateIcoDeadline);
    require(_unixts > dateIcoEnd);
    require(_unixts < DATE_LIMIT);
    dateIcoDeadline = _unixts;
    emit IcoDateUpdated(4, _unixts);
  }

}


// ----------------------------------------------------------------------------
//
// VAR public token sale
//
// ----------------------------------------------------------------------------

contract VaryonToken is ERC20Token, Wallet, LockSlots, WBList, VaryonIcoDates {

  // Utility variable

  uint constant E6  = 10**6;

  // Basic token data

  string public constant name     = "Varyon Token";
  string public constant symbol   = "VAR";
  uint8  public constant decimals = 6;

  // Crowdsale parameters : token price, supply, caps and bonus  

  uint public constant TOKENS_PER_ETH = 10000; // test value, will be reset to 14750 before deployment

  uint public constant TOKEN_TOTAL_SUPPLY = 1000000000 * E6; // VAR 1,000,000,000
  uint public constant TOKEN_THRESHOLD   =  4000 * TOKENS_PER_ETH * E6; // ETH  4,000 = VAR  59,000,000
  uint public constant TOKEN_PRESALE_CAP =  4400 * TOKENS_PER_ETH * E6; // ETH  4,400 = VAR  64,000,000
  uint public constant TOKEN_ICO_CAP     = 24200 * TOKENS_PER_ETH * E6; // ETH 24,200 = VAR 356,950,000

  uint public constant BONUS = 15;

  uint public constant MAX_BONUS_TOKENS = TOKEN_PRESALE_CAP * BONUS / 100; // 9,735,000 tokens

  // Crowdsale parameters : minimum purchase amounts expressed in tokens    

  uint public constant MIN_PURCHASE_PRESALE = 40 * TOKENS_PER_ETH * E6; // ETH 40 = VAR 590,000
  uint public constant MIN_PURCHASE_MAIN    =  1 * TOKENS_PER_ETH * E6; // ETH  1 = VAR  14,750

  // Crowdsale parameters : minimum contribution in ether

  uint public constant MINIMUM_ETH_CONTRIBUTION = 0.01 ether;

  // Tokens from off-chain contributions (no eth returns for these tokens)

  mapping(address => uint) public balancesOffline;

  // Tokens - pending

  mapping(address => uint) public balancesPending;
  mapping(address => uint) public balancesPendingOffline;

  uint public tokensIcoPending  = 0;

  // Tokens - issued

  // mapping(address => uint) balances; // in ERC20Token
  mapping(address => uint) public balancesMinted;

  // uint public tokensIssuedTotal = 0; // in ERC20Token
  // tokensIssuedTotal = tokensIcoIssued + tokensIcoBonus + tokensMinted 

  uint public tokensIcoIssued  = 0; // = tokensIcoCrowd + tokensIcoOffline 
  uint public tokensIcoCrowd   = 0;
  uint public tokensIcoOffline = 0;
  uint public tokensIcoBonus   = 0;
  uint public tokensMinted     = 0;

  mapping(address => uint) public balancesBonus;

  // Ether - tokens pending

  mapping(address => uint) public ethPending;
  uint public totalEthPending  = 0;

  // Ether - tokens issued

  mapping(address => uint) public ethContributed;
  uint public totalEthContributed = 0;

  // Keep track of refunds in case of failed ICO

  mapping(address => bool) public refundClaimed;

  // Events ---------------------------

  event TokensMinted(address indexed account, uint tokens, uint term);
  event RegisterOfflineContribution(address indexed account, uint tokens, uint tokensBonus);
  event RegisterOfflinePending(address indexed account, uint tokens);
  event RegisterContribution(address indexed account, uint tokens, uint tokensBonus, uint ethContributed, uint ethReturned);
  event RegisterPending(address indexed account, uint tokens, uint ethContributed, uint ethReturned);
  event WhitelistingEvent(address indexed account, uint tokens, uint tokensBonus, uint tokensReturned, uint ethContributed, uint ethReturned);
  event OfflineTokenReturn(address indexed account, uint tokensReturned);
  event RevertPending(address indexed account, uint tokensCancelled, uint ethReturned, uint tokensIcoPending, uint totalEthPending);
  event RefundFailedIco(address indexed account, uint ethReturned);

  // Basic Functions ----------------------------

  constructor() public {}

  function () public payable {
    buyTokens();
  }

  // Information Functions --------------------------------

  function tradeable() public view returns (bool) {
    if (thresholdReached() && atNow() > dateIcoEnd) return true;
    return false;
  }

  function thresholdReached() public view returns (bool) {
    if (tokensIcoIssued >= TOKEN_THRESHOLD) return true;
    return false;
  }

  function availableToMint() public view returns (uint available) {
    if (atNow() <= dateIcoEnd) {
      available = TOKEN_TOTAL_SUPPLY.sub(TOKEN_ICO_CAP).sub(MAX_BONUS_TOKENS).sub(tokensMinted);
    } else if (atNow() <= dateIcoDeadline) {
      available = TOKEN_TOTAL_SUPPLY.sub(tokensIssuedTotal).sub(tokensIcoPending);
    } else {
      available = TOKEN_TOTAL_SUPPLY.sub(tokensIssuedTotal);
    }
  }

  function tokensAvailableIco() public view returns (uint) {
    if (atNow() <= dateIcoMain) {
      return TOKEN_PRESALE_CAP.sub(tokensIcoIssued).sub(tokensIcoPending);
    } else {
      return TOKEN_ICO_CAP.sub(tokensIcoIssued).sub(tokensIcoPending);
    }
  }

  function minimumInvestment() private view returns (uint) {
    if (atNow() <= dateIcoMain) return MIN_PURCHASE_PRESALE;
    return MIN_PURCHASE_MAIN;
  }

  function ethToTokens(uint _eth) public pure returns (uint tokens) {
    tokens = _eth.mul(TOKENS_PER_ETH).mul(E6) / 1 ether;
  }

  function tokensToEth(uint _tokens) public pure returns (uint eth) {
    eth = _tokens.mul(1 ether) / TOKENS_PER_ETH.mul(E6);
  }

  function getBonus(uint _tokens) private view returns (uint) {
    if (atNow() <= dateIcoMain) return _tokens.mul(BONUS)/100;
    return 0;
  }

  // Minting of tokens by owner ---------------------------
  
  // Minting of unrestricted tokens

  function mintTokens(address _account, uint _tokens) public onlyOwner {
    pMintTokens(_account, _tokens);
  }

  function mintTokensMultiple(address[] _accounts, uint[] _tokens) public onlyOwner {
    require(_accounts.length == _tokens.length);
    for (uint i = 0; i < _accounts.length; i++) {
      pMintTokens(_accounts[i], _tokens[i]);
    }
  }

  function pMintTokens(address _account, uint _tokens) private {
    // checks
    require(_account != 0x0);
    require(_tokens > 0);
    require(_tokens <= availableToMint(), "not enough tokens available to mint");

    // update
    balances[_account] = balances[_account].add(_tokens);
    balancesMinted[_account] = balances[_account].add(_tokens);
    tokensMinted = tokensMinted.add(_tokens);
    tokensIssuedTotal = tokensIssuedTotal.add(_tokens);

    // log event
    emit Transfer(0x0, _account, _tokens);
    emit TokensMinted(_account, _tokens, 0);
  }

  // Minting of locked tokens

  function mintTokensLocked(address _account, uint _tokens, uint _term) public onlyOwner {
    pMintTokensLocked(_account, _tokens, _term);
  }

  function mintTokensLockedMultiple(address[] _accounts, uint[] _tokens, uint[] _terms) public onlyOwner {
    require(_accounts.length == _tokens.length);
    require(_accounts.length == _terms.length);
    for (uint i = 0; i < _accounts.length; i++) {
      pMintTokensLocked(_accounts[i], _tokens[i], _terms[i]);
    }
  }

  function pMintTokensLocked(address _account, uint _tokens, uint _term) private {
    // checks
    require(_account != 0x0);
    require(_tokens > 0);
    require(_tokens <= availableToMint(), "not enough tokens available to mint");

    // term has to be in the future
    require(_term > atNow(), "lock term must be in the future");

    // register locked tokens (will throw if no slot is found)
    registerLockedTokens(_account, _tokens, _term);

    // update
    balances[_account] = balances[_account].add(_tokens);
    balancesMinted[_account] = balancesMinted[_account].add(_tokens);
    tokensMinted = tokensMinted.add(_tokens);
    tokensIssuedTotal = tokensIssuedTotal.add(_tokens);

    // log event
    emit Transfer(0x0, _account, _tokens);
    emit TokensMinted(_account, _tokens, _term);
  }

  // Offline contributions --------------------------------

  function buyOffline(address _account, uint _tokens) public onlyAdmin {
    require(!blacklist[_account]);
    require(atNow() <= dateIcoEnd);
    require(_tokens <= tokensAvailableIco());

    // buy tokens
    if (whitelist[_account]) {
      buyOfflineWhitelist(_account, _tokens);
    } else {
      buyOfflinePending(_account, _tokens);
    }
  }

  function buyOfflineWhitelist(address _account, uint _tokens) private {

    // adjust based on limit and threshold, update total offline contributions
    uint tokens;
    uint tokens_bonus;
    (tokens, tokens_bonus) = processTokenIssue(_account, _tokens);
    balancesOffline[_account] = balancesOffline[_account].add(tokens);
    tokensIcoOffline = tokensIcoOffline.add(tokens);

    // throw if no tokens can be issued
    require(tokens > 0, "no tokens can be issued");
    
    // log
    emit Transfer(0x0, _account, tokens.add(tokens_bonus));
    emit RegisterOfflineContribution(_account, tokens, tokens_bonus);  
  }

  function buyOfflinePending(address _account, uint _tokens) private {
    balancesPending[_account] = balancesPending[_account].add(_tokens);
    balancesPendingOffline[_account] = balancesPendingOffline[_account].add(_tokens);
    tokensIcoPending = tokensIcoPending.add(_tokens);
    emit RegisterOfflinePending(_account, _tokens);
  }

  // Crowdsale ETH contributions --------------------------

  function buyTokens() private {

    // checks
    require(atNow() > dateIcoPresale && atNow() <= dateIcoEnd, "outside of ICO period");
    require(msg.value >= MINIMUM_ETH_CONTRIBUTION, "fail minimum contribution");
    require(!blacklist[msg.sender], "blacklisted sending address");
    require(tokensAvailableIco() > 0, "no more tokens available");
    
    // buy tokens
    if (whitelist[msg.sender]) {
      buyTokensWhitelist();
    } else {
      buyTokensPending();
    }

  }

  // contributions from pending (non-whitelisted) addresses

  function buyTokensPending() private {
    
    // the maximum number of tokens is a function of ether sent
    // the actual maximum depends on tokens available
    uint tokens_max = ethToTokens(msg.value);
    uint tokens = tokens_max;
    if (tokens_max > tokensAvailableIco()) {
      tokens = tokensAvailableIco();
    }

    // check minimum purchase amount
    uint tokens_total = balancesPending[msg.sender].add(tokens);
    require(tokens_total >= minimumInvestment(), "minimum purchase amount");

    // eth returned, if any
    uint eth_contributed = msg.value;
    uint eth_returned = 0;
    if (tokens < tokens_max) {
      eth_contributed = tokensToEth(tokens);
      eth_returned = msg.value.sub(eth_contributed);
    }

    // tokens
    balancesPending[msg.sender] = balancesPending[msg.sender].add(tokens);
    tokensIcoPending = tokensIcoPending.add(tokens);
    // eth
    ethPending[msg.sender] = ethPending[msg.sender].add(eth_contributed);
    totalEthPending = totalEthPending.add(eth_contributed);
    // return any unused ether
    if (eth_returned > 0) msg.sender.transfer(eth_returned);
    // log
    emit RegisterPending(msg.sender, tokens, eth_contributed, eth_returned);
  }

  // contributions from whitelisted addresses

  function buyTokensWhitelist() private {

    // to process as contributions:
    uint tokens;
    uint tokens_bonus;
    uint eth_to_contribute;

    // to return:
    uint eth_to_return;
    
    // helper variable
    uint tokens_max;

    // the maximum number of tokens is a function of ether sent
    // the actual maximum depends on tokens available
    tokens_max = ethToTokens(msg.value);
    tokens = tokens_max;
    if (tokens_max > tokensAvailableIco()) {
      tokens = tokensAvailableIco();
    }

    // adjust based on limit and threshold, update total crowd contribution
    (tokens, tokens_bonus) = processTokenIssue(msg.sender, tokens);
    tokensIcoCrowd = tokensIcoCrowd.add(tokens);

    // throw if no tokens can be allocated, or if below min purchase amount
    require(tokens > 0, "no tokens can be issued");
    require(balances[msg.sender].sub(balancesBonus[msg.sender]) >= minimumInvestment(), "minimum purchase amount");

    // register eth contribution and return any unused ether if necessary
    eth_to_contribute = msg.value;
    eth_to_return = 0;
    if (tokens < tokens_max) {
      eth_to_contribute = tokensToEth(tokens);
      eth_to_return = msg.value.sub(eth_to_contribute);
    }
    ethContributed[msg.sender] = ethContributed[msg.sender].add(eth_to_contribute);
    totalEthContributed = totalEthContributed.add(eth_to_contribute);
    if (eth_to_return > 0) { msg.sender.transfer(eth_to_return); }

    // send ether to wallet if threshold reached
    sendEtherToWallet();

    // log
    emit Transfer(0x0, msg.sender, tokens.add(tokens_bonus));
    emit RegisterContribution(msg.sender, tokens, tokens_bonus, eth_to_contribute, eth_to_return);
  }

  // whitelisting of an address

  function processWhitelisting(address _account) internal {
    require(atNow() <= dateIcoDeadline);
    if (balancesPending[_account] == 0) return; 

    // to process as contributions:
    uint tokens;
    uint tokens_bonus;
    uint eth_to_contribute;

    // to return:
    uint tokens_to_return;
    uint eth_to_return;

    // helper variable
    uint tokens_max;

    // the maximum number of tokens equals pending tokens for the account
    // the actual maximum depends on tokens available
    tokens_max = balancesPending[_account];
    tokens = tokens_max;
    if (tokens_max > tokensAvailableIco()) {
      tokens = tokensAvailableIco();
    }

    // adjust based on limit and threshold, update total crowd contribution
    (tokens, tokens_bonus) = processTokenIssue(_account, tokens);

    // split tokens to be issued between online and offline for better accounting
    // (pending tokens that cannot be issued are tekan from the online portion first)
    if (tokens >= balancesPendingOffline[_account]) {
      balancesOffline[_account] = balancesOffline[_account];
      tokensIcoOffline = tokensIcoOffline.add(balancesPendingOffline[_account]);
      tokensIcoCrowd = tokensIcoCrowd.add(tokens).sub(balancesPendingOffline[_account]);
    } else {
      balancesOffline[_account] = balancesOffline[_account].add(tokens);
      tokensIcoOffline = tokensIcoOffline.add(tokens);
      emit OfflineTokenReturn(_account, balancesPendingOffline[_account].sub(tokens));
    }

    // tokens to return
    tokens_to_return = tokens_max.sub(tokens);

    // ether to return (there may be an "offline" portion)
    if (tokens_to_return > 0) {
      eth_to_return = tokensToEth(tokens_to_return);
      if (eth_to_return > ethPending[_account]) { eth_to_return = ethPending[_account]; }
    }
    eth_to_contribute = ethPending[_account].sub(eth_to_return);

    // process tokens pending
    balancesPending[_account] = 0;
    balancesPendingOffline[_account] = 0;
    tokensIcoPending = tokensIcoPending.sub(tokens_max);

    // process eth pending
    totalEthPending = totalEthPending.sub(ethPending[_account]);
    ethPending[_account] = 0;

    // process eth issued
    ethContributed[_account] = eth_to_contribute;
    totalEthContributed = totalEthContributed.add(eth_to_contribute);

    // return any unused ether
    if (eth_to_return > 0) { _account.transfer(eth_to_return); }

    // send ether to wallet if threshold reached
    sendEtherToWallet();

    // log
    emit Transfer(0x0, _account, tokens.add(tokens_bonus));
    emit WhitelistingEvent(_account, tokens, tokens_bonus, tokens_to_return, eth_to_contribute, eth_to_return);
  }
  
  // Send ether to wallet if threshold reached

  function sendEtherToWallet() private {
    address thisAddress = this;
    if (thresholdReached() && thisAddress.balance > totalEthPending) {
      wallet.transfer(thisAddress.balance.sub(totalEthPending));
    }
  }

  // Adjust tokens that can be issued, based on limit and threshold, and update balances

  function processTokenIssue(address _account, uint _tokens_to_add) private returns (uint tokens, uint tokens_bonus) {

    tokens = _tokens_to_add;
    uint balance = balances[msg.sender].sub(balancesBonus[msg.sender]).sub(balancesMinted[msg.sender]);
    uint balance_exp = balance.add(tokens);
    uint limit = whitelistLimit[_account];
    uint threshold = whitelistThreshold[_account];

    // if limit and/or threshold are not 0, adjustments may be necessary

    if (limit > 0 && threshold == 0) {
      if (balance >= limit) {
        // no contribution possible
        tokens = 0;
      } else {
        // reduce tokens if necessary
        if (tokens > limit.sub(balance)) tokens = limit.sub(balance);
      }      
    } else if (limit == 0 && threshold > 0) {
      // not possible if ending balance is below the threshold
      if (balance_exp < threshold) tokens = 0;
    } else if (limit > 0 && threshold > 0) {
      if (balance_exp >= threshold) {
        // nothing to adjust
      } else {
        if (balance >= limit) {
          // no contribution possible
          tokens = 0;
        } else {
          // reduce tokens if necessary
          if (tokens > limit.sub(balance)) tokens = limit.sub(balance);
        }
      }
    }

    // update balances and lock tokens if necessary

    if (tokens > 0) {
      // bonus tokens
      tokens_bonus = getBonus(tokens);
      uint tokens_issued = tokens.add(tokens_bonus);
      
      // update balances and totals
      balances[_account]        = balances[_account].add(tokens_issued);
      balancesBonus[_account]   = balancesBonus[_account].add(tokens_bonus);
      tokensIssuedTotal         = tokensIssuedTotal.add(tokens_issued);
      tokensIcoIssued           = tokensIcoIssued.add(tokens);
      tokensIcoBonus            = tokensIcoBonus.add(tokens_bonus);

      // token locking
      uint tokens_crowdsale = balances[_account].sub(balancesMinted[_account]);
      if (threshold > 0 && tokens_crowdsale >= threshold) {
        setIcoLock(_account, whitelistLockDate[_account], tokens_crowdsale);
      }
    }
  }  

  // Cancel or Reclaim pending contributions -------------

  // blacklisting results in returning pending contributions

  function processBlacklisting(address _account) internal {
    require(atNow() <= dateIcoDeadline);
    pRevertPending(_account);
  }

  // Admin can cancel pending contributions anytime

  function cancelPending(address _account) public onlyAdmin {
    pRevertPending(_account);
  }

  function cancelPendingMultiple(address[] _accounts) public onlyAdmin {
    for (uint i = 0; i < _accounts.length; i++) {
      pRevertPending(_accounts[i]);
    }
  }

  // Contributor reclaims pending contribution after deadline (successful ICO)

  function reclaimPending() public {
    require(thresholdReached() && atNow() > dateIcoDeadline);
    pRevertPending(msg.sender);
  }

  // private revert function for pending

  function pRevertPending(address _account) private {
    // nothing to do if there are no pending tokens
    if (balancesPending[_account] == 0) return;

    // tokens
    uint tokens_to_cancel = balancesPending[_account];
    balancesPending[_account] = 0;
    balancesPendingOffline[_account] = 0;
    tokensIcoPending = tokensIcoPending.sub(tokens_to_cancel);

    //eth
    uint eth_to_return = ethPending[_account];
    ethPending[_account] = 0;
    totalEthPending = totalEthPending.sub(eth_to_return);
    if (eth_to_return > 0) { _account.transfer(eth_to_return); }

    // log
    emit RevertPending(_account, tokens_to_cancel, eth_to_return, tokensIcoPending, totalEthPending);
  }

  // Refunds in case of failed ICO ------------------------

  function reclaimEth() public {
    pReclaimEth(msg.sender);
  }

  function reclaimEthAdmin(address _account) public onlyAdmin {
    pReclaimEth(_account);
  }

  function reclaimEthAdminMultiple(address[] _accounts) public onlyAdmin {
    for (uint i = 0; i < _accounts.length; i++) {
      pReclaimEth(_accounts[i]);
    }
  }

  function pReclaimEth(address _account) private {
    require(!thresholdReached() && atNow() > dateIcoDeadline, "too early");
    require(ethPending[_account] > 0 || ethContributed[_account] > 0, "nothing to return");
    require(!refundClaimed[_account], "refund already claimed");

    // return eth (no balances are modified)
    uint eth_to_return = ethPending[_account].add(ethContributed[_account]);
    refundClaimed[_account] = true;
    if (eth_to_return > 0) { _account.transfer(eth_to_return); }
    emit RefundFailedIco(_account, eth_to_return);
  }

  // ERC20 functions --------------------------------------

  // Transfer out any accidentally sent ERC20 tokens

  function transferAnyERC20Token(address tokenAddress, uint amount) public onlyOwner returns (bool success) {
      return ERC20Interface(tokenAddress).transfer(owner, amount);
  }

  // Override "transfer"

  function transfer(address _to, uint _amount) public returns (bool success) {
    require(tradeable());
    require(_amount <= unlockedTokens(msg.sender));
    return super.transfer(_to, _amount);
  }

  // Override "transferFrom"

  function transferFrom(address _from, address _to, uint _amount) public returns (bool success) {
    require(tradeable());
    require(_amount <= unlockedTokens(_from)); 
    return super.transferFrom(_from, _to, _amount);
  }

  // Multiple token transfers from one address to save gas

  function transferMultiple(address[] _addresses, uint[] _amounts) external {
    require(tradeable());
    require(_addresses.length <= 100);
    require(_addresses.length == _amounts.length);

    // check token amounts
    uint tokens_to_transfer = 0;
    for (uint i = 0; i < _addresses.length; i++) {
      tokens_to_transfer = tokens_to_transfer.add(_amounts[i]);
    }
    require(tokens_to_transfer <= unlockedTokens(msg.sender));

    // do the transfers
    for (i = 0; i < _addresses.length; i++) {
      super.transfer(_addresses[i], _amounts[i]);
    }
  }

}