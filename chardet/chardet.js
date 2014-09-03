var jschardet = {};

jschardet.Constants = {
    _debug      : false,

    detecting   : 0,
    foundIt     : 1,
    notMe       : 2,

    start       : 0,
    error       : 1,
    itsMe       : 2,

    SHORTCUT_THRESHOLD  : 0.95
};

jschardet.detect = function(buffer) {
    var u = new jschardet.UniversalDetector();
    u.reset();
    if(typeof Buffer == 'function' && buffer instanceof Buffer) {
        var str = "";
        for (var i = 0; i < buffer.length; ++i)
            str += String.fromCharCode(buffer[i])
        u.feed(str);
    } else {
        u.feed(buffer);
    }
    u.close();
    return u.result;
}
