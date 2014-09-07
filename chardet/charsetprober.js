
!function(jschardet) {  
    
jschardet.CharSetProber = function() {
    this.reset = function() {
        this._mState = jschardet.Constants.detecting;
    }
    
    this.getCharsetName = function() {
        return null;
    }
    
    this.feed = function(aBuf) {
    }
    
    this.getState = function() {
        return this._mState;
    }
    
    this.getConfidence = function() {
        return 0.0;
    }
    
    this.filterHighBitOnly = function(aBuf) {
        aBuf = aBuf.replace(/[\x00-\x7F]+/g, " ");
        return aBuf;
    }
    
    this.filterWithoutEnglishLetters = function(aBuf) {
        aBuf = aBuf.replace(/[A-Za-z]+/g, " ");
        return aBuf;
    }
    
    this.filterWithEnglishLetters = function(aBuf) {
        // TODO
        return aBuf;
    }
}

}((typeof process !== 'undefined' && typeof process.title !== 'undefined') ? module.parent.exports : jschardet);