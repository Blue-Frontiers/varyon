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
    require( c >= a );
  }

  function sub(uint a, uint b) internal pure returns (uint c) {
    require( b <= a );
    c = a - b;
  }

  function mul(uint a, uint b) internal pure returns (uint c) {
    c = a * b;
    require( a == 0 || c / a == b );
  }

}


// ----------------------------------------------------------------------------
//
// Owned contract
//
// ----------------------------------------------------------------------------

contract Owned {

  address public owner;
  address public newOwner;

  mapping(address => bool) public isAdmin;

  // Events ---------------------------

  event OwnershipTransferProposed(address indexed _from, address indexed _to);
  event OwnershipTransferred(address indexed _from, address indexed _to);
  event AdminChange(address indexed _admin, bool _status);

  // Modifiers ------------------------

  modifier onlyOwner { require( msg.sender == owner ); _; }
  modifier onlyAdmin { require( isAdmin[msg.sender] ); _; }

  // Functions ------------------------

  constructor() public {
    owner = msg.sender;
    isAdmin[owner] = true;
  }

  function transferOwnership(address _newOwner) public onlyOwner {
    require( _newOwner != address(0x0) );
    emit OwnershipTransferProposed(owner, _newOwner);
    newOwner = _newOwner;
  }

  function acceptOwnership() public {
    require( msg.sender == newOwner );
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }
  
  function addAdmin(address _a) public onlyOwner {
    require( isAdmin[_a] == false );
    isAdmin[_a] = true;
    emit AdminChange(_a, true);
  }

  function removeAdmin(address _a) public onlyOwner {
    require( isAdmin[_a] == true );
    isAdmin[_a] = false;
    emit AdminChange(_a, false);
  }
  
}


// ----------------------------------------------------------------------------
//
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
//
// ----------------------------------------------------------------------------

contract ERC20Interface {

  // Events ---------------------------

  event Transfer(address indexed _from, address indexed _to, uint _value);
  event Approval(address indexed _owner, address indexed _spender, uint _value);

  // Functions ------------------------

  function totalSupply() public view returns (uint);
  function balanceOf(address _owner) public view returns (uint balance);
  function transfer(address _to, uint _value) public returns (bool success);
  function transferFrom(address _from, address _to, uint _value) public returns (bool success);
  function approve(address _spender, uint _value) public returns (bool success);
  function allowance(address _owner, address _spender) public view returns (uint remaining);

}


// ----------------------------------------------------------------------------
//
// ERC Token Standard #20
//
// ----------------------------------------------------------------------------

contract ERC20Token is ERC20Interface, Owned {
  
  using SafeMath for uint;

  uint public tokensIssuedTotal = 0;
  mapping(address => uint) balances;
  mapping(address => mapping (address => uint)) allowed;

  // Functions ------------------------

  /* Total token supply */

  function totalSupply() public view returns (uint) {
    return tokensIssuedTotal;
  }

  /* Get the account balance for an address */

  function balanceOf(address _owner) public view returns (uint balance) {
    return balances[_owner];
  }

  /* Transfer the balance from owner's account to another account */

  function transfer(address _to, uint _amount) public returns (bool success) {
    // amount sent cannot exceed balance
    require( balances[msg.sender] >= _amount );

    // update balances
    balances[msg.sender] = balances[msg.sender].sub(_amount);
    balances[_to]        = balances[_to].add(_amount);

    // log event
    emit Transfer(msg.sender, _to, _amount);
    return true;
  }

  /* Allow _spender to withdraw from your account up to _amount */

  function approve(address _spender, uint _amount) public returns (bool success) {
    // approval amount cannot exceed the balance
    require( balances[msg.sender] >= _amount );
      
    // update allowed amount
    allowed[msg.sender][_spender] = _amount;
    
    // log event
    emit Approval(msg.sender, _spender, _amount);
    return true;
  }

  /* Spender of tokens transfers tokens from the owner's balance */
  /* Must be pre-approved by owner */

  function transferFrom(address _from, address _to, uint _amount) public returns (bool success) {
    // balance checks
    require( balances[_from] >= _amount );
    require( allowed[_from][msg.sender] >= _amount );

    // update balances and allowed amount
    balances[_from]            = balances[_from].sub(_amount);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
    balances[_to]              = balances[_to].add(_amount);

    // log event
    emit Transfer(_from, _to, _amount);
    return true;
  }

  /* Returns the amount of tokens approved by the owner */
  /* that can be transferred by spender */

  function allowance(address _owner, address _spender) public view returns (uint remaining) {
    return allowed[_owner][_spender];
  }

}


// ----------------------------------------------------------------------------
//
// VAR public token sale
//
// ----------------------------------------------------------------------------

contract VaryonToken is ERC20Token {

  /* Utility variable */
  
  uint constant E6  = 10**6;

  /* Basic token data */

  string public constant name     = "Varyon Token";
  string public constant symbol   = "VAR";
  uint8  public constant decimals = 6;

  /* Wallets */
  
  address public wallet;

  /* Crowdsale parameters : dates */

  uint public date_ico_presale    = 1526392800; // 15-MAY-2018 14:00 UTC
  uint public date_ico_main       = 1527861600; // 01-JUN-2018 14:00 UTC
  uint public date_ico_end        = 1530367200; // 30-JUN-2018 14:00 UTC
  uint public date_ico_deadline   = 1533045600; // 31-JUL-2018 14:00 UTC
  
  uint public constant DATE_LIMIT = 1538316000; // 30-SEP-2018 14:00 UTC

  /* Crowdsale parameters : token price, supply, caps and bonus */  
  
  uint public constant TOKENS_PER_ETH = 14750;

  uint public constant TOKEN_TOTAL_SUPPLY = 1000000000 * E6; // VAR 1,000,000,000
  uint public constant TOKEN_THRESHOLD    =   4000 * TOKENS_PER_ETH * E6; // ETH  4,000 = VAR  59,000,000
  uint public constant TOKEN_PRESALE_CAP  =   4400 * TOKENS_PER_ETH * E6; // ETH  4,400 = VAR  64,000,000
  uint public constant TOKEN_ICO_CAP      =  24200 * TOKENS_PER_ETH * E6; // ETH 24,200 = VAR 356,950,000
  
  uint public constant BONUS = 15;
  
  uint public constant MAX_BONUS_TOKENS = TOKEN_PRESALE_CAP * BONUS / 100; // 9,735,000 tokens
  
  /* Crowdsale parameters : minimum purchase amounts expressed in tokens */    
  
  uint public constant MIN_PURCHASE_PRESALE = 40 * TOKENS_PER_ETH * E6; // ETH 40 = VAR 590,000
  uint public constant MIN_PURCHASE_MAIN    =  1 * TOKENS_PER_ETH * E6; // ETH  1 = VAR  14,750

  /* Crowdsale parameters : minimum contribution in ether */

  uint public constant MINIMUM_ETH_CONTRIBUTION  = 0.01 ether;
  
  /* Tokens from off-chain contributions (no eth returns for these tokens) */
  
  mapping(address => uint) public balancesOffline;
  
  /* Tokens - pending */
  
  mapping(address => uint) public balancesPending;

  uint public tokensIcoPending  = 0;

  /* Tokens - issued */

  // mapping(address => uint) balances; // in ERC20Token
    
  // uint public tokensIssuedTotal = 0; // in ERC20Token
  // tokensIssuedTotal = tokensIcoIssued + tokensIcoBonus + tokensMinted 
    
  uint public tokensIcoIssued  = 0; // = tokensIcoCrowd + tokensIcoOffline 
  uint public tokensIcoCrowd   = 0;
  uint public tokensIcoOffline = 0;
  uint public tokensIcoBonus   = 0;
  uint public tokensMinted     = 0;
    
  mapping(address => uint) public balancesBonus;
  
  /* Ether - tokens pending */
    
  mapping(address => uint) public ethPending;
  uint public totalEthPending  = 0;

  /* Ether - tokens issued */

  mapping(address => uint) public ethContributed;
  uint public totalEthContributed = 0;
  
  /* Keep track of refunds in case of failed ICO */
  
  mapping(address => bool) public refundClaimed;
  
  /* Whitelist and blacklist */

  mapping(address => bool) public whitelist;
  mapping(address => uint) public whitelistLimit;
  mapping(address => uint) public whitelistThreshold;
  mapping(address => uint) public whitelistLockDate;

  mapping(address => bool) public blacklist;

  /* Locking information :
    index 0 is reserved for the ICO,
    remaining indices are used for other locking */
  
  uint8 public constant LOCK_SLOTS = 6;
  
  mapping(address => uint[LOCK_SLOTS]) public lockTerm;
  mapping(address => uint[LOCK_SLOTS]) public lockAmnt;
  
  /* Other parameters */

  uint public constant MAX_LOCKING_PERIOD = 1827 days; // max 5 years

  // Events ---------------------------
  
  event WalletUpdated(address newWallet);
  event IcoDateUpdated(uint8 id, uint unixts);
  event Whitelisted(address indexed account, uint limit, uint threshold, uint term);
  event Blacklisted(address indexed account);
  event TokensMinted(address indexed account, uint tokens, uint term);
  event RegisterPending(address indexed account, uint tokens, uint ethContributed, uint ethReturned);
  event WhitelistingEvent(address indexed account, uint tokens, uint tokensBonus, uint tokensReturned, uint ethContributed, uint ethReturned);
  event RegisterContribution(address indexed account, uint tokens, uint tokens_bonus, uint ethContributed, uint ethReturned);
  event OfflinePending(address indexed _account, uint _tokens);
  event RegisterOfflineContribution(address indexed account, uint tokens, uint tokens_bonus);  
  event RefundBlacklistedTokens(address indexed account, uint tokens);
  event RefundBlacklistedEth(address indexed account, uint eth);
  event RefundFailedIco(address indexed account, uint ethReturned);
  event ReturnedPending(address indexed account, uint tokensCancelled, uint ethReturned, uint tokensIcoPending, uint totalEthPending);
  event IcoLockChanged(address indexed account, uint oldTerm, uint newTerm);
  event TransferLocked(address indexed from, address indexed to, uint tokens, uint term);

  // Basic Functions ------------------

  /* Initialize */

  constructor() public {
    // check dates
    require( atNow()           < date_ico_presale );
    require( date_ico_presale  < date_ico_main );
    require( date_ico_main     < date_ico_end );
    require( date_ico_end      < date_ico_deadline );
    require( date_ico_deadline < DATE_LIMIT );

    // set owner wallet
    wallet = owner;
  }

  /* Fallback */
  
  function () public payable {
    buyTokens();
  }

  //
  // Information Functions ====================================================
  //
  
  /* What time is it? */
  
  function atNow() public view returns (uint) {
    return now;
  }

  /* Are tokens tradeable */
  
  function tradeable() public view returns (bool) {
    if (thresholdReached() && atNow() > date_ico_end) return true;
    return false;
  }
  
  /* Has soft cap been reached */
  
  function thresholdReached() public view returns (bool) {
    if (tokensIcoIssued >= TOKEN_THRESHOLD) return true;
    return false;
  }
  
  /* Tokens available to mint by owner */
  
  function availableToMint() public view returns (uint available) {
    if (atNow() <= date_ico_end) {
      available = TOKEN_TOTAL_SUPPLY.sub(TOKEN_ICO_CAP).sub(MAX_BONUS_TOKENS);
    } else if (atNow() <= date_ico_deadline) {
      available = TOKEN_TOTAL_SUPPLY.sub(tokensIssuedTotal).sub(tokensIcoPending);
    } else {
      available = TOKEN_TOTAL_SUPPLY.sub(tokensIssuedTotal);
    }
  }
  
  /* Currently available tokens for sale */

  function tokensAvailableIco() private view returns (uint) {
    if (atNow() <= date_ico_main) {
      return TOKEN_PRESALE_CAP.sub(tokensIcoIssued).sub(tokensIcoPending);
    } else {
      return TOKEN_ICO_CAP.sub(tokensIcoIssued).sub(tokensIcoPending);
    }
  }
  
  /* Minimum number of tokens per contributor */

  function minimumInvestment() private view returns (uint) {
    if (atNow() <= date_ico_main) return MIN_PURCHASE_PRESALE;
    return MIN_PURCHASE_MAIN;
  }
  
  /* Convert ether to tokens */

  function ethToTokens(uint _eth) public pure returns (uint tokens) {
    tokens = _eth.mul(TOKENS_PER_ETH).mul(E6) / 1 ether;
  }
  
  /* Convert tokens to ether */
  
  function tokensToEth(uint _tokens) public pure returns (uint eth) {
    eth = _tokens.mul(1 ether) / TOKENS_PER_ETH.mul(E6);
  }
  
  /* Compute bonus tokens */
  
  function getBonus(uint _tokens) private view returns (uint) {
    if (atNow() <= date_ico_main) return _tokens.mul(BONUS)/100;
    return 0;
  }

  //
  // Token locking functions ==================================================
  //
  
  /* Register locked tokens (we do not use slot 0, which is reserved for the ICO)  */
  
  function registerLockedTokens(address _account, uint _tokens, uint _term) private returns (uint idx) {
    // the term must be in the future
    require( _term > atNow(), "lock term must be in the future" ); 

    // find a slot (clean up while doing this)
    //
    // we use either the existing slot with the exact same term,
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
    require( idx != 9999, "registerLockedTokens: no available slot found" );
    
    // register locked tokens
    if (term[idx] == 0) term[idx] = _term;
    amnt[idx] = amnt[idx].add(_tokens);
  }

  /* Unlocked tokens in an account */
  
  function unlockedTokens(address _account) public view returns (uint _unlockedTokens) {
    uint locked_tokens = 0;
    uint[LOCK_SLOTS] storage term = lockTerm[_account];
    uint[LOCK_SLOTS] storage amnt = lockAmnt[_account];
    for (uint i = 0; i < LOCK_SLOTS; i++) {
      if (term[i] > atNow()) locked_tokens = locked_tokens.add(amnt[i]);
    }
    _unlockedTokens = balances[_account].sub(locked_tokens);
  }

  /* Checks if a Lock Slot is available for an account */ 
  /* (does not check slot 0 which is reserved for the ICO) */
  
  function isAvailableLockSlot(address _account, uint _term) public view returns (bool) {
    // true if locking term has already passed
    if (_term < atNow()) return true;
    // case of term in the future
    uint[LOCK_SLOTS] storage term = lockTerm[_account];
    for (uint i = 1; i < LOCK_SLOTS; i++) {
      if (term[i] < atNow() || term[i] == _term) return true;
    }
    return false;
  }

  //
  // Set Wallet and Dates =====================================================
  //
  
  /* Change the crowdsale wallet address */

  function setWallet(address _wallet) public onlyOwner {
    require( _wallet != address(0x0) );
    wallet = _wallet;
    emit WalletUpdated(_wallet);
  }

  /* Change the ICO dates - no changes possible after a date has passed */
  
  function setDateIcoPresale(uint _unixts) public onlyOwner {
    require( atNow() < _unixts );
    require( atNow() < date_ico_presale );
    require( _unixts < date_ico_main );
    date_ico_presale = _unixts;
    emit IcoDateUpdated(1, _unixts);
  }

  function setDateIcoMain(uint _unixts) public onlyOwner {
    require( atNow() < _unixts );
    require( atNow() < date_ico_main );
    require( _unixts > date_ico_presale );
    require( _unixts < date_ico_end );
    date_ico_main = _unixts;
    emit IcoDateUpdated(2, _unixts);
  }

  function setDateIcoEnd(uint _unixts) public onlyOwner {
    require( atNow() < _unixts );
    require( atNow() < date_ico_end );
    require( _unixts > date_ico_main );
    require( _unixts < date_ico_deadline );
    date_ico_end = _unixts;
    emit IcoDateUpdated(3, _unixts);
  }

  function setDateIcoDeadline(uint _unixts) public onlyOwner {
    require( atNow() < _unixts );
    require( atNow() < date_ico_deadline );
    require( _unixts > date_ico_end );
    require( _unixts < DATE_LIMIT );
    date_ico_deadline = _unixts;
    emit IcoDateUpdated(4, _unixts);
  }

  //
  // Whitelisting and blacklisting --------------------------------------------
  //
  
  /* Whitelisting */
  
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
    require( _accounts.length == _limits.length );
    require( _accounts.length == _thresholds.length );
    require( _accounts.length == _terms.length );
    for (uint i = 0; i < _accounts.length; i++) {
      pWhitelist(_accounts[i], _limits[i], _thresholds[i], _terms[i]);
    }
  }  
  
  function pWhitelist(address _account, uint _limit, uint _threshold, uint _term) private {
    // checks
    require( atNow() < date_ico_deadline );
    require( !whitelist[_account], "account is already whitelisted" );
    require( !blacklist[_account], "account is blacklisted" );
    
    // whitelisting parameter checks
    if (_threshold > 0 ) require ( _threshold > _limit, "threshold not above limit" );
    if (_term > 0) {
      require( _term > atNow(), "the locking period cannot be in the past");
      require( _term < atNow() + MAX_LOCKING_PERIOD, "the locking period cannot exceed 720 days" );
    }

    // add to whitelist
    whitelist[_account]          = true;
    whitelistLimit[_account]     = _limit;
    whitelistThreshold[_account] = _threshold;
    whitelistLockDate[_account]  = _term;
    emit Whitelisted(_account, _limit, _threshold, _term);
    
    // process contributions, if any
    if (balancesPending[_account] > 0) processWhitelisting(_account);
  }  
  
  
  /* Blacklisting */
  
  function addToBlacklist(address _account) public onlyAdmin {
    pBlacklist(_account);
  }
  
  function addToBlacklistMultiple(address[] _accounts) public onlyAdmin {
    for (uint i = 0; i < _accounts.length; i++) {
      pBlacklist(_accounts[i]);
    }
  }
  
  function pBlacklist(address _account) private {
    // checks
    require( atNow() < date_ico_deadline, "no sense blacklisting after deadline");
    require( !whitelist[_account], "account is whitelisted" );
    require( !blacklist[_account], "account is already blacklisted" );

    // add to blacklist
    blacklist[_account] = true;
    emit Blacklisted(_account);

    // reverse contributions, if any
    if (balancesPending[_account] > 0) {
    
      // tokens
      uint tokens = balancesPending[_account];
      tokensIcoPending = tokensIcoPending.sub(tokens);
      balancesPending[_account] = 0;
      emit RefundBlacklistedTokens(_account, tokens);

      // ether
      uint eth = ethPending[_account];
      if (eth > 0) {
        totalEthPending = totalEthPending.sub(eth);
        ethPending[_account] = 0;
        _account.transfer(eth);
        emit RefundBlacklistedEth(_account, eth);
      }
    }
  }
  
  //
  // Minting of tokens by owner -----------------------------------------------
  //
  
  /* Minting of unrestricted tokens */

  function mintTokens(address _account, uint _tokens) public onlyOwner {
    pMintTokens(_account, _tokens);
  }
  
  function mintTokensMultiple(address[] _accounts, uint[] _tokens) public onlyOwner {
    require( _accounts.length == _tokens.length );
    for (uint i = 0; i < _accounts.length; i++) {
      pMintTokens(_accounts[i], _tokens[i]);
    }    
  }
  
  function pMintTokens(address _account, uint _tokens) private {
    // checks
    require( _account != 0x0 );
    require( _tokens > 0 );
    require( _tokens <= availableToMint(), "not enough tokens available to mint" );
    
    // update
    balances[_account] = balances[_account].add(_tokens);
    tokensMinted       = tokensMinted.add(_tokens);
    tokensIssuedTotal  = tokensIssuedTotal.add(_tokens);
    
    // log event
    emit Transfer(0x0, _account, _tokens);
    emit TokensMinted(_account, _tokens, 0);
  }

  /* Minting of locked tokens */

  function mintTokensLocked(address _account, uint _tokens, uint _term) public onlyOwner {
    pMintTokensLocked(_account, _tokens, _term);
  }
  
  function mintTokensLockedMultiple(address[] _accounts, uint[] _tokens, uint[] _terms) public onlyOwner {
    require( _accounts.length == _tokens.length );
    require( _accounts.length == _terms.length );
    for (uint i = 0; i < _accounts.length; i++) {
      pMintTokensLocked(_accounts[i], _tokens[i], _terms[i]);
    }    
  }
  
  function pMintTokensLocked(address _account, uint _tokens, uint _term) private {
    // checks
    require( _account != 0x0 );
    require( _tokens > 0 );
    require( _tokens <= availableToMint(), "not enough tokens available to mint" );
    
    // term has to be in the future
    require( _term > atNow(), "lock term must be in the future" );
    
    // register locked tokens (will throw if no slot is found)
    registerLockedTokens(_account, _tokens, _term);
    
    // update
    balances[_account] = balances[_account].add(_tokens);
    tokensMinted       = tokensMinted.add(_tokens);
    tokensIssuedTotal  = tokensIssuedTotal.add(_tokens);
    
    // log event
    emit Transfer(0x0, _account, _tokens);
    emit TokensMinted(_account, _tokens, _term);
  }

  /* Change lock date of ICO tokens */

  function modifyIcoLock(address _account, uint _unixts) public onlyAdmin {
    // checks
    require( lockAmnt[_account][0] > 0,       "no ICO tokens for this account");
    require( lockTerm[_account][0] > atNow(), "the ICO tokens are already unlocked");
    require( _unixts < lockTerm[_account][0], "locking period can only be shortened");
    
    // modify term
    uint term = lockTerm[_account][0];
    lockTerm[_account][0] = _unixts;
    
    // log
    emit IcoLockChanged(_account, term, _unixts);
  }

  //
  // Processing Offline contributions =============================================
  //
  
  function offlineContribution(address _account, uint _tokens) public onlyAdmin {
    require( atNow() < date_ico_end );
    require( _tokens <= tokensAvailableIco() );

    // buy tokens
    if (whitelist[_account]) {
      offlineTokensWhitelist(_account, _tokens);
    } else {
      offlineTokensPending(_account, _tokens);
    }    
  }
  
  function offlineTokensWhitelist(address _account, uint _tokens) private {

    // adjust based on limit and threshold, update total offline contributions
    uint tokens;
    uint tokens_bonus;
    (tokens, tokens_bonus) = processTokenIssue(_account, _tokens);
    balancesOffline[_account] = balancesOffline[_account].add(tokens);
    tokensIcoOffline          = tokensIcoOffline.add(tokens);

    // throw if no tokens can be issued
    require( tokens > 0, "no tokens can be issued" );
    
    // log
    emit Transfer(0x0, _account, tokens.add(tokens_bonus));
    emit RegisterOfflineContribution(_account, tokens, tokens_bonus);  
  }

  function offlineTokensPending(address _account, uint _tokens) private {
    balancesPending[_account] = balancesPending[_account].add(_tokens);
    balancesOffline[_account] = balancesOffline[_account].add(_tokens);
    tokensIcoPending = tokensIcoPending.add(_tokens);
    emit OfflinePending(_account, _tokens);
  }
  

  //
  // Processing ICO contributions =============================================
  //

  /* main function */ 

  function buyTokens() private {
    
    // checks
    require( atNow() > date_ico_presale && atNow() < date_ico_end, "outside of ICO period" );
    require( msg.value >= MINIMUM_ETH_CONTRIBUTION, "fail minimum contribution" );
    require( !blacklist[msg.sender], "blacklisted sending address" );
    require( tokensAvailableIco() > 0, "no more tokens available" );
    
    // buy tokens
    if (whitelist[msg.sender]) {
      buyTokensWhitelist();
    } else {
      buyTokensPending();
    }

  }
  
  /* contributions from non-whitelisted addresses */

  function buyTokensPending() private {
    
    // the maximum number of tokens is a function of ether sent
    // the actual maximum depends on tokens available
    uint tokens_max = ethToTokens(msg.value);
    uint tokens = tokens_max;
    if ( tokens_max > tokensAvailableIco() ) tokens = tokensAvailableIco();
    
    // check minimum purchase amount
    uint tokens_total = balancesPending[msg.sender].add(tokens);
    require( tokens_total >= minimumInvestment(), "minimum purchase amount" );

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

  /* contributions from whitelisted addresses */

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
    if ( tokens_max > tokensAvailableIco() ) tokens = tokensAvailableIco();

    // adjust based on limit and threshold, update total crowd contribution
    (tokens, tokens_bonus) = processTokenIssue(msg.sender, tokens);
    tokensIcoCrowd = tokensIcoCrowd.add(tokens);
    
    // throw if no tokens can be allocated, or if below min purchase amount
    require( tokens > 0, "no tokens can be issued" );
    require( balances[msg.sender].sub(balancesBonus[msg.sender]) >= minimumInvestment(), "minimum purchase amount" );

    // register eth contribution and return any unused ether if necessary
    eth_to_contribute = msg.value;
    eth_to_return = 0;
    if (tokens < tokens_max) {
      eth_to_contribute = tokensToEth(tokens);
      eth_to_return = msg.value.sub(eth_to_contribute);
    }
    ethContributed[msg.sender] = ethContributed[msg.sender].add(eth_to_contribute);
    totalEthContributed = totalEthContributed.add(eth_to_contribute);
    if (eth_to_return > 0) msg.sender.transfer(eth_to_return);

    // send ether to wallet if threshold reached
    sendEtherToWallet();
    
    // log
    emit Transfer(0x0, msg.sender, tokens.add(tokens_bonus));
    emit RegisterContribution(msg.sender, tokens, tokens_bonus, eth_to_contribute, eth_to_return);
  }

  /* whitelisting of an address */
  
  function processWhitelisting(address _account) private {
    
    // to process as contributions:
    uint tokens;
    uint tokens_bonus;
    uint eth_to_contribute;

    // to return:
    uint tokens_to_return;
    uint eth_to_return;
    
    // helper variable
    uint tokens_max;
    
    // the maximum number of tokens is a function of ether sent
    // the actual maximum depends on tokens available
    tokens_max = balancesPending[_account];
    tokens = tokens_max;
    if ( tokens_max > tokensAvailableIco() ) tokens = tokensAvailableIco();

    // adjust based on limit and threshold, update total crowd contribution
    (tokens, tokens_bonus) = processTokenIssue(_account, tokens);
    tokensIcoCrowd = tokensIcoCrowd.add(tokens);
      
    // tokens to return
    tokens_to_return = tokens_max.sub(tokens);
    
    // ether to return (there may be an "offline" portion)
    if (tokens_to_return > 0) {
      eth_to_return = tokensToEth(tokens_to_return);
      if (eth_to_return > ethPending[_account]) eth_to_return = ethPending[_account];
    }
    eth_to_contribute = ethPending[_account].sub(eth_to_return);

    // process tokens pending
    balancesPending[_account] = 0;
    tokensIcoPending = tokensIcoPending.sub(tokens);
 
    // process eth pending
    totalEthPending = totalEthPending.sub(ethPending[_account]);
    ethPending[_account] = 0;

    // process eth issued
    ethContributed[_account] = eth_to_contribute;
    totalEthContributed = totalEthContributed.add(eth_to_contribute);

    // return any unused ether
    if (eth_to_return > 0) _account.transfer(eth_to_return);

    // send ether to wallet if threshold reached
    sendEtherToWallet();
  
    // log
    emit Transfer(0x0, _account, tokens.add(tokens_bonus));
    emit WhitelistingEvent(_account, tokens, tokens_bonus, tokens_to_return, eth_to_contribute, eth_to_return);

  }
  
  /* Send ether to wallet if threshold reached */
  
  function sendEtherToWallet() private {
    address thisAddress = this;
    if ( thresholdReached() && thisAddress.balance > totalEthPending ) {
      wallet.transfer(thisAddress.balance.sub(totalEthPending));
    }
  }
  
  /* Adjust tokens that can be issued, based on limit and threshold, and update balances */
  
  function processTokenIssue(address _account, uint _tokens_to_add) private returns (uint tokens, uint tokens_bonus) {

    tokens = _tokens_to_add;
    uint balance = balances[msg.sender]; // will be 0 unless whitelisted & contributed
    uint balance_exp = balance.add(tokens);
    uint limit = whitelistLimit[_account];
    uint threshold = whitelistThreshold[_account];
    uint available;
    
    // adjust tokens amount if necessary

    if ( limit == 0 && threshold == 0) {
      // nothing to adjust
    }
    else if (limit > 0 && threshold == 0) {
      if (balance >= limit) {
        // no contribution possible
        tokens = 0;
      } else {
        // reduce tokens if necessary
        available = limit.sub(balance);
        if (tokens > available) tokens = available;
      }      
    }
    else if (limit == 0 && threshold > 0) {
      // not possible if ending balance is below the threshold
      if (balance_exp < threshold) tokens = 0;
    }
    else if (limit > 0 && threshold > 0) {
      if (balance_exp >= threshold) {
        // nothing to adjust
      }
      else {
        if (balance >= limit) {
          // no contribution possible
          tokens = 0;
        } else {
          // reduce tokens if necessary
          available = limit.sub(balance);
          if (tokens > available) tokens = available;
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
      if (threshold > 0 && balances[_account] >= threshold) {
        lockTerm[_account][0] = whitelistLockDate[_account];
        lockAmnt[_account][0] = balances[_account];
      }      
    }  
  }  
  
  //
  // Cancel or Reclaim pending contributions ==================================
  //
  
  /* Admin cancels pending contribution during ICO */

  function cancelPending(address _account) public onlyAdmin {
    require( atNow() < date_ico_end );
    pRevertPending(_account);
  }

  function cancelPendingMultiple(address[] _accounts) public onlyAdmin {
    require( atNow() < date_ico_end );
    for (uint i = 0; i < _accounts.length; i++) {
      pRevertPending(_accounts[i]);
    }
  }
  
  /* Contributor reclaims pending contribution after deadline */
  /* (case of successful ICO) */ 
  
  function reclaimPending() public {
    require( thresholdReached() && atNow() > date_ico_deadline );
    pRevertPending(msg.sender);
  }
  
  /* private revert function for pending */
  
  function pRevertPending(address _account) private {
    // nothing to do if there are no pending tokens
    if (balancesPending[_account] == 0) return;
      
    // tokens
    uint tokens_to_cancel = balancesPending[_account];
    balancesPending[_account] = 0;
    tokensIcoPending = tokensIcoPending.sub(tokens_to_cancel);
    
    //eth
    uint eth_to_return = ethPending[_account];
    ethPending[_account] = 0;
    totalEthPending = totalEthPending.sub(eth_to_return);
    if (eth_to_return > 0) _account.transfer(eth_to_return);
      
    // log
    emit ReturnedPending(_account, tokens_to_cancel, eth_to_return, tokensIcoPending, totalEthPending);
  }

  //
  // Refunds in case of failed ICO ============================================
  //

  function reclaimEth() public {
    pReclaimEth(msg.sender, false);
  }

  function reclaimEthAdmin(address _account) public onlyAdmin {
    pReclaimEth(_account, false);
  }
  
  function reclaimEthAdminMultiple(address[] _accounts) public onlyAdmin {
    for (uint i = 0; i < _accounts.length; i++) {
      pReclaimEth(_accounts[i], true);
    }
  }
  
  /* private reclaim function - note  we do not modify any balances */
  
  function pReclaimEth(address _account, bool _silent) private {
    // conditions
    if (_silent) {
      if ( thresholdReached() || atNow() <= date_ico_deadline ) return;
      if ( ethPending[_account] == 0 && ethContributed[_account] == 0 ) return;
      if ( refundClaimed[_account] ) return;
    } else {
      require( !thresholdReached() && atNow() > date_ico_deadline, "too early" );
      require( ethPending[_account] > 0 || ethContributed[_account] > 0, "nothing to return");
      require( !refundClaimed[_account], "refund already claimed");      
    }
  
    // return eth
    uint eth_to_return = ethPending[_account].add(ethContributed[_account]);
    refundClaimed[_account] = true;
    if (eth_to_return > 0) _account.transfer(eth_to_return);

    // log
    emit RefundFailedIco(_account, eth_to_return);
  }

  //
  // ERC20 functions ==========================================================
  //

  /* Transfer out any accidentally sent ERC20 tokens */

  function transferAnyERC20Token(address tokenAddress, uint amount) public onlyOwner returns (bool success) {
      return ERC20Interface(tokenAddress).transfer(owner, amount);
  }

  /* Override "transfer" */

  function transfer(address _to, uint _amount) public returns (bool success) {
    require( tradeable() );
    require( unlockedTokens(msg.sender) >= _amount );
    return super.transfer(_to, _amount);
  }
  
  /* Override "transferFrom" */

  function transferFrom(address _from, address _to, uint _amount) public returns (bool success) {
    require( tradeable() );
    require( unlockedTokens(_from) >= _amount ); 
    return super.transferFrom(_from, _to, _amount);
  }

  // Locked token transfers

  /* Locked token transfer function */
  function transferLocked(address _to, uint _amount, uint _unixts) public returns (bool success) {
    require( tradeable(), "not tradeable" );
    require( unlockedTokens(msg.sender) >= _amount, "not enough unlocked tokens" );
    require( _unixts > atNow(), "date must be in the future");
    require( _unixts < atNow() + MAX_LOCKING_PERIOD, "locking limited to 730 days");
    require( isAvailableLockSlot(_to, _unixts), "no locking slot available");
    super.transfer(_to, _amount);
    registerLockedTokens(_to, _amount, _unixts);
    emit TransferLocked(msg.sender, _to, _amount, _unixts);
    return true;
  }  
  
  // Bulk token transfer function -----

  /* Multiple token transfers from one address to save gas */

  function transferMultiple(address[] _addresses, uint[] _amounts) external {
    require( tradeable() );
    require( _addresses.length == _amounts.length );
    require( _addresses.length <= 100 );
    
    // check token amounts
    uint tokens_to_transfer = 0;
    for (uint i = 0; i < _addresses.length; i++) {
      tokens_to_transfer = tokens_to_transfer.add(_amounts[i]);
    }
    require( tokens_to_transfer <= unlockedTokens(msg.sender) );
    
    // do the transfers
    for (i = 0; i < _addresses.length; i++) {
      super.transfer(_addresses[i], _amounts[i]);
    }
  }
  
}