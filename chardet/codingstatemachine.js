
!function(jschardet) {
    
jschardet.CodingStateMachine = function(sm) {
    var self = this;
    
    function init(sm) {
        self._mModel = sm;
        self._mCurrentBytePos = 0;
        self._mCurrentCharLen = 0;
        self.reset();
    }
    
    this.reset = function() {
        this._mCurrentState = jschardet.Constants.start;
    }
    
    this.nextState = function(c) {
        // for each byte we get its class
        // if it is first byte, we also get byte length
        var byteCls = this._mModel.classTable[c.charCodeAt(0)];
        if(this._mCurrentState == jschardet.Constants.start) {
            this._mCurrentBytePos = 0;
            this._mCurrentCharLen = this._mModel.charLenTable[byteCls];
        }
        // from byte's class and stateTable, we get its next state
        this._mCurrentState = this._mModel.stateTable[this._mCurrentState * this._mModel.classFactor + byteCls];
        this._mCurrentBytePos++;
        return this._mCurrentState;
    }
    
    this.getCurrentCharLen = function() {
        return this._mCurrentCharLen;
    }
    
    this.getCodingStateMachine = function() {
        return this._mModel.name;
    }
    
    init(sm);
}

}((typeof process !== 'undefined' && typeof process.title !== 'undefined') ? module.parent.exports : jschardet);