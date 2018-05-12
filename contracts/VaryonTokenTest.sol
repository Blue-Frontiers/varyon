contract VaryonTokenTest is VaryonToken {

    /*

    Introduces function setTestTime(uint)
    
    Overrides function atNow() to return testTime instead of now()

    */

    uint public testTime = 1;
    
    // Events ---------------------------

    event TestTimeSet(uint _now);

    // Functions ------------------------

    constructor() public {}

    function atNow() public constant returns (uint) {
            return testTime;
    }

    function setTestTime(uint _t) public onlyOwner {
        // require( _t > testTime );
        testTime = _t;
        emit TestTimeSet(_t);
    }

}