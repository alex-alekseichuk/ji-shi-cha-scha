
!function(jschardet) {

jschardet.UTF8Prober = function() {
    jschardet.CharSetProber.apply(this);
    
    var ONE_CHAR_PROB = 0.5;
    var self = this;
    
    function init() {
        self._mCodingSM = new jschardet.CodingStateMachine(jschardet.UTF8SMModel);
        self.reset();
    }
    
    this.reset = function() {
        jschardet.UTF8Prober.prototype.reset.apply(this);
        this._mCodingSM.reset();
        this._mNumOfMBChar = 0;
    }
    
    this.getCharsetName = function() {
        return "utf-8";
    }
    
    this.feed = function(aBuf) {
        for( var i = 0, c; i < aBuf.length; i++ ) {
            c = aBuf[i];
            var codingState = this._mCodingSM.nextState(c);
            if( codingState == jschardet.Constants.error ) {
                this._mState = jschardet.Constants.notMe;
                break;
            } else if( codingState == jschardet.Constants.itsMe ) {
                this._mState = jschardet.Constants.foundIt;
                break;
            } else if( codingState == jschardet.Constants.start ) {
                if( this._mCodingSM.getCurrentCharLen() >= 2 ) {
                    this._mNumOfMBChar++;
                }
            }
        }
        
        if( this.getState() == jschardet.Constants.detecting ) {
            if( this.getConfidence() > jschardet.Constants.SHORTCUT_THRESHOLD ) {
                this._mState = jschardet.Constants.foundIt;
            }
        }
        
        return this.getState();
    }
    
    this.getConfidence = function() {
        var unlike = 0.99;
        if( this._mNumOfMBChar < 6 ) {
            for( var i = 0; i < this._mNumOfMBChar; i++ ) {
                unlike *= ONE_CHAR_PROB;
            }
            return 1 - unlike;
        } else {
            return unlike;
        }
    }
    
    init();
}
jschardet.UTF8Prober.prototype = new jschardet.CharSetProber();

}((typeof process !== 'undefined' && typeof process.title !== 'undefined') ? module.parent.exports : jschardet);