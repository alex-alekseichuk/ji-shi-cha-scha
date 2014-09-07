!function(jschardet) {
    jschardet.RuGroupProber = function() {
        jschardet.CharSetGroupProber.apply(this);
        this._mProbers = [
            new jschardet.UTF8Prober(),
            new jschardet.SingleByteCharSetProber(jschardet.Win1251CyrillicModel),
            new jschardet.SingleByteCharSetProber(jschardet.Koi8rModel),
            new jschardet.SingleByteCharSetProber(jschardet.MacCyrillicModel),
            new jschardet.SingleByteCharSetProber(jschardet.Ibm866Model),
            new jschardet.SingleByteCharSetProber(jschardet.Ibm855Model)
        ];
        this.reset();
    }
    jschardet.RuGroupProber.prototype = new jschardet.CharSetGroupProber();
}((typeof process !== 'undefined' && typeof process.title !== 'undefined') ? module.parent.exports : jschardet);