// Generated by CoffeeScript 1.8.0

/*
  Ji-shi, cha-scha angular application for measuring content has been read
 */
var app;

app = angular.module('wordsApp', []);

app.factory('VkApi', function($q, $rootScope) {
  var service;
  service = {
    test_mode: 1,
    getValue: function(key) {
      var deferred;
      deferred = $q.defer();
      VK.api('storage.get', {
        key: key,
        test_mode: service.test_mode
      }, function(data) {
        return $rootScope.$apply(function() {
          var value;
          if (data.error) {
            return deferred.reject(data.error.error_msg);
          } else {
            if (data.response) {
              value = JSON.parse(data.response);
            } else {
              value = void 0;
            }
            return deferred.resolve(value);
          }
        });
      });
      return deferred.promise;
    },
    getData: function(key) {
      var deferred;
      deferred = $q.defer();
      VK.api('storage.get', {
        key: key,
        test_mode: service.test_mode
      }, function(data) {
        return $rootScope.$apply(function() {
          if (data.error) {
            return deferred.reject(data.error.error_msg);
          } else {
            return deferred.resolve(data.response);
          }
        });
      });
      return deferred.promise;
    },
    setValue: function(key, value) {
      return service.setData(key, JSON.stringify(value));
    },
    setData: function(key, value) {
      var deferred;
      deferred = $q.defer();
      VK.api('storage.set', {
        key: key,
        value: value,
        test_mode: service.test_mode
      }, function(data) {
        return $rootScope.$apply(function() {
          if (data.error || data.response !== 1) {
            return deferred.reject(data.error.error_msg);
          } else {
            return deferred.resolve();
          }
        });
      });
      return deferred.promise;
    },
    init: function() {
      var deferred;
      deferred = $q.defer();
      try {
        VK.init(function() {
          return deferred.resolve();
        }, function() {
          return deferred.reject("VK API initialization failed");
        }, '5.24');
      } catch (_error) {
        return false;
      }
      return deferred.promise;
    }
  };
  return service;
});

app.factory('LocalStorage', [
  '$q', 'VkApi', function($q, storage) {
    var now, saveToLocalStorage, self, service;
    self = this;
    service = {
      getValue: function(key) {
        var deferred, localValue;
        deferred = $q.defer();
        localValue = void 0;
        if (self.hasWebStorage) {
          localValue = JSON.parse(localStorage.getItem(key));
        }
        storage.getValue(key).then(function(value) {
          if (localValue && (value._t < localValue._t)) {
            return deferred.resolve(localValue);
          } else {
            return deferred.resolve(value);
          }
        }, function(error_msg) {
          if (localValue) {
            return deferred.resolve(localValue);
          } else {
            return deferred.reject(error_msg);
          }
        });
        return deferred.promise;
      },
      setValue: function(key, value) {
        var deferred;
        deferred = $q.defer();
        value._t = now();
        storage.setValue(key, value).then(function() {
          return saveToLocalStorage(key, value, deferred);
        }, function() {
          return saveToLocalStorage(key, value, deferred);
        });
        return deferred.promise;
      },
      init: function() {
        self.hasWebStorage = typeof Storage !== "undefined";
        return storage.init();
      }
    };
    saveToLocalStorage = function(key, value, deferred) {
      if (self.hasWebStorage) {
        localStorage.setItem(key, JSON.stringify(value));
      }
      return deferred.resolve();
    };
    now = function() {
      return parseInt((new Date().getTime() - new Date(1970, 0, 5).getTime()) / 1000);
    };
    return service;
  }
]);

app.factory('WordsService', [
  '$q', 'LocalStorage', function($q, storage) {
    var chars, countChars, countWords, initData, initToday, loadPdfFile, loadTextFile, minutesNow, periods, processText, resetData, resetLevel, save, self, service, shift, spaces, stripHtml, today, update;
    self = this;
    service = {
      init: function(scope) {
        var deferred, _init;
        self.scope = scope;
        deferred = $q.defer();
        _init = storage.init();
        if (!_init) {
          return;
        }
        _init.then(function() {
          return storage.getValue('data').then(function(data) {
            if (data) {
              service.data = data;
              console.log(data);
              if (update()) {
                save().then(function() {
                  return deferred.resolve();
                }, function(error) {
                  return deferred.reject(error);
                });
                return;
              }
            } else {
              initData();
            }
            return deferred.resolve();
          }, function(error) {
            return deferred.reject(error);
          });
        });
        return deferred.promise;
      },
      loadFiles: function(files) {
        var file, _i, _len, _results;
        _results = [];
        for (_i = 0, _len = files.length; _i < _len; _i++) {
          file = files[_i];
          if (file.type.match('text/plain')) {
            _results.push(loadTextFile(file));
          } else if (file.type.match('application/pdf')) {
            _results.push(loadPdfFile(file));
          } else {
            _results.push(void 0);
          }
        }
        return _results;
      },
      loadText: function(text) {
        return processText(text);
      },
      reset: function() {
        resetData();
        initToday();
        return save();
      }
    };
    periods = [
      {
        n: 7,
        d: 1
      }, {
        n: 5,
        d: 6
      }, {
        n: 6,
        d: 30
      }, {
        n: 12,
        d: 30
      }
    ];
    loadTextFile = function(file) {
      var reader;
      reader = new FileReader();
      reader.onload = function(e) {
        var charDet;
        charDet = jschardet.detect(e.target.result);
        if (charDet) {
          reader = new FileReader();
          reader.onload = function(e) {
            return processText(e.target.result);
          };
          return reader.readAsText(file, charDet.encoding);
        }
      };
      return reader.readAsBinaryString(file);
    };
    loadPdfFile = function(file) {
      var reader;
      reader = new FileReader();
      reader.onload = function(e) {
        var pdf2txt;
        pdf2txt = new Pdf2TextClass();
        return pdf2txt.pdfToText(e.target.result, function(text) {
          return processText(text);
        });
      };
      return reader.readAsArrayBuffer(file);
    };
    processText = function(text) {
      var chars, i, l, p, total, words, _now;
      chars = countChars(text);
      words = countWords(text);
      if (words < 10) {
        return;
      }
      self.scope.lastSubmit = {
        chars: chars,
        words: words
      };
      update();
      service.data.chars += chars;
      service.data.words += words;
      service.data.today.chars += chars;
      service.data.today.words += words;
      for (i in service.data.periods) {
        p = service.data.periods[i];
        p.data[0] += words;
        p.words += words;
      }
      l = service.data.level;
      total = service.data.words;
      _now = minutesNow();
      if (l.limit <= total) {
        l.n += 1;
        l.limit = (total - l.words) * 3;
        if (l.period && l.t && (_now - l.t) > 0) {
          l.limit = parseInt(l.limit * l.period * 2 / (_now - l.t));
        }
        l.limit += total;
        l.words = total;
        if (l.t) {
          l.period = _now - l.t;
          if (l.period <= 0) {
            l.period = 1;
          }
        }
        l.t = _now;
      }
      return save();
    };
    shift = function(_n) {
      var d, i, n, nd, np, p, value, z, _i, _j, _k, _ref, _ref1, _results;
      _results = [];
      for (i in service.data.periods) {
        p = service.data.periods[i];
        np = periods[i].n;
        nd = periods[i].d;
        n = parseInt((_n + p.x) / nd);
        if (n <= 0) {
          p.x += _n;
          p.words -= _n * p.dd;
          continue;
        }
        p.x = _n - (n * nd);
        d = np - n;
        z = 0;
        if (d >= 0) {
          z = p.data[d];
        }
        p.dd = parseInt(z / nd);
        if (d > 0) {
          for (i = _i = _ref = np - 1, _ref1 = np - d; _ref <= _ref1 ? _i <= _ref1 : _i >= _ref1; i = _ref <= _ref1 ? ++_i : --_i) {
            p.data[i] = p.data[i - n];
          }
          for (i = _j = 0; 0 <= n ? _j < n : _j > n; i = 0 <= n ? ++_j : --_j) {
            p.data[i] = 0;
          }
        } else {
          for (i = _k = 0; 0 <= np ? _k < np : _k > np; i = 0 <= np ? ++_k : --_k) {
            p.data[i] = 0;
          }
        }
        p.words = z - (p.dd * (p.x + 1));
        _results.push((function() {
          var _l, _len, _ref2, _results1;
          _ref2 = p.data;
          _results1 = [];
          for (_l = 0, _len = _ref2.length; _l < _len; _l++) {
            value = _ref2[_l];
            _results1.push(p.words += value);
          }
          return _results1;
        })());
      }
      return _results;
    };
    update = function() {
      var i, j, needSave, p, t, _i, _ref, _ref1;
      needSave = false;
      if (!service.data.v) {
        needSave = true;
        service.data.v = 1;
        service.data.reg = today();
        service.data.level = {
          n: 0,
          limit: service.data.words + 5000,
          words: service.data.words
        };
      }
      if (service.data.v === 1) {
        needSave = true;
        service.data.v = 2;
        service.data.level = {
          n: 0,
          limit: service.data.words + 5000,
          words: service.data.words
        };
      }
      if (service.data.v === 2) {
        needSave = true;
        service.data.v = 3;
        for (i in service.data.periods) {
          p = service.data.periods[i];
          for (j = _i = _ref = p.data.length, _ref1 = periods[i].n; _ref <= _ref1 ? _i < _ref1 : _i > _ref1; j = _ref <= _ref1 ? ++_i : --_i) {
            p.data[j] = 0;
          }
          p.dd = 0;
        }
      }
      t = today();
      if (service.data.today) {
        if (service.data.today.t !== t) {
          shift(t - service.data.today.t);
          initToday();
          needSave = true;
        }
      } else {
        initToday();
        needSave = true;
      }
      return needSave;
    };
    initToday = function() {
      return service.data.today = {
        t: today(),
        words: 0,
        chars: 0
      };
    };
    initData = function() {
      service.data = {
        reg: today(),
        v: 3
      };
      return resetData();
    };
    resetData = function() {
      service.data.chars = 0;
      service.data.words = 0;
      service.data.periods = [
        {
          x: 0,
          data: [0, 0, 0, 0, 0, 0, 0],
          words: 0,
          dd: 0
        }, {
          x: 0,
          data: [0, 0, 0, 0, 0],
          words: 0,
          dd: 0
        }, {
          x: 0,
          data: [0, 0, 0, 0, 0, 0],
          words: 0,
          dd: 0
        }, {
          x: 0,
          data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          words: 0,
          dd: 0
        }
      ];
      return resetLevel();
    };
    resetLevel = function() {
      return service.data.level = {
        n: 0,
        limit: 5000,
        words: 0
      };
    };
    save = function() {
      var deferred;
      deferred = $q.defer();
      storage.setValue('data', service.data).then(function() {
        return deferred.resolve();
      }, function(error) {
        return deferred.reject(error);
      });
      return deferred.promise;
    };
    chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ";
    spaces = " \t\r\n.,:;";
    countChars = function(s) {
      var c, n, _i, _len;
      n = 0;
      for (_i = 0, _len = s.length; _i < _len; _i++) {
        c = s[_i];
        if (-1 !== chars.indexOf(c)) {
          n += 1;
        }
      }
      return n;
    };
    countWords = function(s) {
      var c, n, w, _i, _len;
      n = 0;
      w = false;
      for (_i = 0, _len = s.length; _i < _len; _i++) {
        c = s[_i];
        if (-1 !== chars.indexOf(c)) {
          w = true;
        } else {
          if (-1 !== spaces.indexOf(c)) {
            if (w) {
              n += 1;
            }
            w = false;
          }
        }
      }
      if (w) {
        n += 1;
      }
      return n;
    };
    stripHtml = function(html) {
      var tmp;
      tmp = document.createElement("DIV");
      tmp.innerHTML = html;
      return tmp.textContent || tmp.innerText || "";
    };
    today = function() {
      return parseInt((new Date().getTime() - new Date(1970, 0, 5).getTime()) / 86400000);
    };
    minutesNow = function() {
      return parseInt((new Date().getTime() - new Date(1970, 0, 5).getTime()) / 60000);
    };
    return service;
  }
]);

app.constant('Strings', {
  'words': ['слово', 'слова', 'слов'],
  'chars': ['знак', 'знака', 'знаков']
});

app.controller('WordsController', [
  '$scope', 'WordsService', 'Strings', function($scope, service, strings) {
    var _init;
    $scope.reset = function() {
      if (!confirm('Уверены?')) {
        return;
      }
      delete $scope.lastSubmit;
      return service.reset();
    };
    $scope.processFiles = function(files) {
      return service.loadFiles(files);
    };
    $scope.decline = function(n, key) {
      var q, r, s;
      s = strings[key];
      q = n / 10;
      r = n % 10;
      if (r === 1 && q !== 1) {
        return s[0];
      }
      if (2 <= r && r <= 4 && q !== 1) {
        return s[1];
      }
      return s[2];
    };
    $scope.decline3 = function(n, s1, s2, s3) {
      var q, r;
      q = n / 10;
      r = n % 10;
      if (r === 1 && q !== 1) {
        return s1;
      }
      if (2 <= r && r <= 4 && q !== 1) {
        return s2;
      }
      return s3;
    };
    $scope.mode = 'loading';
    _init = service.init($scope);
    if (_init) {
      _init.then(function() {
        $scope.data = service.data;
        return $scope.mode = 'loaded';
      }, function(error) {
        $scope.mode = 'unavailable';
        return $scope.error = error;
      });
    }
    return $scope.$watch('text', function(text) {
      if (text) {
        $scope.text = '';
        return service.loadText(text);
      }
    }, true);
  }
]);

app.filter('longNum', function() {
  return function(input) {
    if (!input) {
      return '0';
    }
    return input.toString().replace(/(\d)(?=(?:\d{3})+$)/g, '$1 ');
  };
});

app.directive('dropFiles', function() {
  return {
    restrict: 'A',
    scope: {
      onDrop: '&'
    },
    link: function(scope, element, attr) {
      var el;
      el = element[0];
      el.addEventListener('dragover', function(e) {
        if (e.preventDefault) {
          e.preventDefault();
        }
        this.classList.add('over');
        return false;
      }, false);
      el.addEventListener('dragenter', function(e) {
        this.classList.add('over');
        return false;
      }, false);
      el.addEventListener('dragleave', function(e) {
        this.classList.remove('over');
        return false;
      }, false);
      return el.addEventListener('drop', function(e) {
        if (e.preventDefault) {
          e.preventDefault();
        }
        if (e.stopPropagation) {
          e.stopPropagation();
        }
        this.classList.remove('over');
        scope.onDrop({
          files: e.dataTransfer.files
        });
        return false;
      }, false);
    }
  };
});

//# sourceMappingURL=app.js.map
