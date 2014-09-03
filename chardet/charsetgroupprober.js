!function(jschardet) {
    
jschardet.CharSetGroupProber = function() {
    jschardet.CharSetProber.apply(this);
    
    var self = this;
    
    function init() {
        self._mActiveNum = 0;
        self._mProbers = [];
        self._mBestGuessProber = null;
    }
    
    this.reset = function() {
        jschardet.CharSetGroupProber.prototype.reset.apply(this);
        this._mActiveNum = 0;
        for(var i = 0, prober; prober = this._mProbers[i]; i++) {
            if(prober) {
                prober.reset();
                prober.active = true;
                this._mActiveNum++;
            }
        }
        this._mBestGuessProber = null;
    }
    
    this.getCharsetName = function() {
        if(!this._mBestGuessProber) {
            this.getConfidence();
            if(!this._mBestGuessProber) return null;
        }
        return this._mBestGuessProber.getCharsetName();
    }
    
    this.feed = function(aBuf) {
        for( var i = 0, prober; prober = this._mProbers[i]; i++ ) {
            if( !prober || !prober.active ) continue;
            var st = prober.feed(aBuf);
            if( !st ) continue;
            if( st == jschardet.Constants.foundIt ) {
                this._mBestGuessProber = prober;
                return this.getState();
            } else if( st == jschardet.Constants.notMe ) {
                prober.active = false;
                this._mActiveNum--;
                if( this._mActiveNum <= 0 ) {
                    this._mState = jschardet.Constants.notMe;
                    return this.getState();
                }
            }
        }
        return this.getState();
    }
    
    this.getConfidence = function() {
        var st = this.getState();
        if( st == jschardet.Constants.foundIt ) {
            return 0.99;
        } else if( st == jschardet.Constants.notMe ) {
            return 0.01;
        }
        var bestConf = 0.0;
        this._mBestGuessProber = null;
        for( var i = 0, prober; prober = this._mProbers[i]; i++ ) {
            if( !prober ) continue;
            if( !prober.active ) {
                if( jschardet.Constants._debug ) {
                    log(prober.getCharsetName() + " not active\n");
                }
                continue;
            }
            var cf = prober.getConfidence();
            if( jschardet.Constants._debug ) {
                log(prober.getCharsetName() + " confidence = " + cf + "\n");
            }
            if( bestConf < cf ) {
                bestConf = cf;
                this._mBestGuessProber = prober;
            }
        }
        if( !this._mBestGuessProber ) return 0.0;
        return bestConf;
    }
    
    init();
}
jschardet.CharSetGroupProber.prototype = new jschardet.CharSetProber();

}((typeof process !== 'undefined' && typeof process.title !== 'undefined') ? module.parent.exports : jschardet);