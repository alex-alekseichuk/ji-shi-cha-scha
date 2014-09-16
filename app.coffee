###
  Ji-shi, cha-scha angular application for measuring content has been read
###

app = angular.module 'wordsApp', []

# VK API
# used as a storage for saving values
app.factory 'VkApi', ($q, $rootScope) ->
  service =
    test_mode: 1
    getValue: (key) ->
      deferred = $q.defer()
      VK.api 'storage.get', {key:key, test_mode:service.test_mode}, (data) ->
        $rootScope.$apply ->
          if data.error
            deferred.reject data.error.error_msg
          else
            if data.response
              value = JSON.parse(data.response)
            else
              value = undefined
            deferred.resolve value
      deferred.promise
    getData: (key) ->
      deferred = $q.defer()
      VK.api 'storage.get', {key:key, test_mode:service.test_mode}, (data) ->
        $rootScope.$apply ->
          if data.error
            deferred.reject data.error.error_msg
          else
            deferred.resolve data.response
      deferred.promise
    setValue: (key, value) ->
      service.setData key, JSON.stringify(value)
    setData: (key, value) ->
      deferred = $q.defer()
      VK.api 'storage.set', {key:key, value:value, test_mode:service.test_mode}, (data) ->
        $rootScope.$apply ->
          if data.error || data.response != 1
            deferred.reject data.error.error_msg
          else
            deferred.resolve()
      deferred.promise
    init: ->
      deferred = $q.defer()
      try
        VK.init ->
          deferred.resolve()
        , ->
          deferred.reject "VK API initialization failed"
        , '5.24'
      catch
        return false
      deferred.promise

  service

# wraper around real storage to cache values in the local web storage
# useful if VK API is temporary unavailable or works with delay
app.factory 'LocalStorage', ['$q', 'VkApi', ($q, storage) ->
  self = @
  service =
    getValue: (key) ->
      deferred = $q.defer()
      localValue = undefined
      if self.hasWebStorage
        localValue = JSON.parse(localStorage.getItem(key))
      storage.getValue(key).then (value) ->
        if localValue && (value._t < localValue._t)
          deferred.resolve localValue
        else
          deferred.resolve value
      , (error_msg) ->
        if localValue
          deferred.resolve localValue
        else
          deferred.reject error_msg
      deferred.promise
    setValue: (key, value) ->
      deferred = $q.defer()
      value._t = now()
      storage.setValue(key, value).then ->
        saveToLocalStorage key, value, deferred
      , ->
        saveToLocalStorage key, value, deferred
      deferred.promise
    init: ->
      self.hasWebStorage = (typeof(Storage) != "undefined")
      storage.init()

  saveToLocalStorage = (key, value, deferred) ->
    if self.hasWebStorage
      localStorage.setItem(key, JSON.stringify(value))
    deferred.resolve()

  now = ->
    # abs. seconds from 1970
    parseInt((new Date().getTime() - new Date(1970, 0, 5).getTime()) / 1000)

  service
]

# Model, Service, Engine of the application
app.factory 'WordsService', ['$q', 'LocalStorage', ($q, storage) ->
  self = @

  # public interface
  service =
    init: (scope) ->
      self.scope = scope
      deferred = $q.defer()
      _init = storage.init()
      return unless _init
      _init.then ->
        storage.getValue('data').then (data) ->
          #self.scope.$apply ->
          #console.log data
          if (data)
            service.data = data
            if update()
              save().then ->
                deferred.resolve()
              , (error) ->
                deferred.reject error
              return
          else
            initData()
          deferred.resolve()
        , (error) ->
          deferred.reject error
      deferred.promise

    loadFiles: (files) ->
      for file in files
        if file.type.match('text/plain')
          loadTextFile file
        else if file.type.match('application/pdf')
          loadPdfFile file
    loadText: (text) ->
      processText(text)
    reset: ->
      resetData()
      initToday()
      save()

  periods = [
    # n is num. of periods, d is a num. of days in the period
    {n:7, d:1}      # week
    {n:5, d:6}      # month
    {n:6, d:30}    # half year
    {n:12, d:30}   # year
  ]

  # implementation

  loadTextFile = (file) ->
    reader = new FileReader()
    reader.onload = (e) ->
      #processText e.target.result
      charDet = jschardet.detect(e.target.result)
      if charDet
        reader = new FileReader()
        reader.onload = (e) ->
          processText e.target.result
        reader.readAsText file, charDet.encoding
    reader.readAsBinaryString file

  loadPdfFile = (file) ->
    reader = new FileReader()
    reader.onload = (e) ->
      pdf2txt = new Pdf2TextClass()
      pdf2txt.pdfToText e.target.result, (text) ->
        #console.log text
        processText text
    reader.readAsArrayBuffer file


  processText = (text) ->
    chars = countChars(text)
    words = countWords(text)

    return if words < 10

    self.scope.lastSubmit =
      chars: chars
      words: words

    update()

    # increase total
    service.data.chars += chars
    service.data.words += words

    # increase today
    service.data.today.chars += chars
    service.data.today.words += words

    # increase stats.
    for i of service.data.periods
      p = service.data.periods[i]
      p.data[0] += words
      p.words += words

    # update level
    l = service.data.level
    total = service.data.words
    _now = minutesNow()
    if l.limit <= total
      l.n += 1

      l.limit = (total - l.words) * 3
      if l.period && l.t && (_now - l.t) > 0
        l.limit = parseInt(l.limit * l.period * 2 / (_now - l.t))
      l.limit += total

      l.words = total
      if l.t
        l.period = _now - l.t
        l.period = 1 if l.period <= 0
      l.t = _now

    save()


  shift = (_n) ->
    # _n number of days to shift
    for i of service.data.periods
      p = service.data.periods[i]   # period
      np = periods[i].n             # num. of periods
      nd = periods[i].d              # days in one period

      # calc real n periods for shifting
      n = parseInt((_n + p.x) / nd)
      if n <= 0 # no shifting
        p.x += _n # only days counter
        p.words -= _n * p.dd # and some values for those days of removed period
        continue

      p.x = _n - (n * nd) # extra days after shift

      # shift values and put zeros
      d = np - n

      z = 0
      if d >= 0
        z = p.data[d]
      p.dd = parseInt(z / nd)

      if d > 0
        p.data[i] = p.data[i-n] for i in [(np-1)..(np-d)]
        p.data[i] = 0 for i in [0...n]
      else
        p.data[i] = 0 for i in [0...np]

      p.words = z - (p.dd * (p.x + 1)) # period that we remove except several days
      p.words += value for value in p.data

  update = ->
    needSave = false
    unless service.data.v
      needSave = true
      service.data.v = 1
      service.data.reg = today()
      service.data.level =
        n: 0          # current level
        limit: service.data.words + 5000   # words limit for next level
        words: service.data.words      # words was on current level started
    if service.data.v == 1
      needSave = true
      service.data.v = 2
      service.data.level =
        n: 0          # current level
        limit: service.data.words + 5000   # words limit for next level
        words: service.data.words      # words was on current level started
    if service.data.v == 2
      needSave = true
      service.data.v = 3
      for i of service.data.periods
        p = service.data.periods[i]
        for j in [(p.data.length)...(periods[i].n)]
          p.data[j] = 0
        p.dd = 0

    t = today()
    if service.data.today
      if service.data.today.t != t
        shift(t - service.data.today.t)
        initToday()
        needSave = true
    else
      initToday()
      needSave = true

    return needSave

  initToday = ->
    service.data.today =
      t: today()
      words: 0
      chars: 0

  initData = ->
    service.data = {
      reg: today()
      v: 3
    }
    resetData()

  resetData = ->
    service.data.chars = 0
    service.data.words = 0
    service.data.periods = [
      {x:0,data:[0,0,0,0,0,0,0],words:0,dd:0},
      {x:0,data:[0,0,0,0,0],words:0,dd:0},
      {x:0,data:[0,0,0,0,0,0],words:0,dd:0},
      {x:0,data:[0,0,0,0,0,0,0,0,0,0,0,0],words:0,dd:0}
    ]
    resetLevel()
  resetLevel = ->
    service.data.level =
      n: 0          # current level
      limit: 5000   # words limit for next level
      words: 0      # words was on current level started

  save = ->
    deferred = $q.defer()
    storage.setValue('data', service.data).then ->
      #self.scope.$apply ->
      deferred.resolve()
    , (error) ->
      #self.scope.$apply ->
      deferred.reject error
    deferred.promise

  chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
  spaces = " \t\r\n.,:;"

  # util methods
  countChars = (s) ->
    n = 0
    for c in s
      n += 1 if -1 != chars.indexOf(c)
    n
  countWords = (s) ->
    n = 0
    w = false
    for c in s
      if -1 != chars.indexOf(c)
        w = true
      else
        if -1 != spaces.indexOf(c)
          n += 1 if w
          w = false
    n += 1 if w
    n

  stripHtml = (html) ->
    tmp = document.createElement("DIV")
    tmp.innerHTML = html
    tmp.textContent || tmp.innerText || ""

  today = ->
    # abs day from 1970
    parseInt((new Date().getTime() - new Date(1970, 0, 5).getTime()) / 86400000)
  minutesNow = ->
    # abs minutes from 1970
    parseInt((new Date().getTime() - new Date(1970, 0, 5).getTime()) / 60000)

  service
]

app.constant 'Strings', {
  'words': ['слово', 'слова', 'слов']
  'chars': ['знак', 'знака', 'знаков']
}

app.controller 'WordsController', ['$scope', 'WordsService', 'Strings', ($scope, service, strings) ->
  $scope.reset = ->
    return unless confirm('Уверены?')
    #$scope.$apply -> service.reset()
    delete $scope.lastSubmit
    service.reset()

#  $scope.processUrl = ->
#    $http.get ctrl.url
#      .success (data) ->
#        ctrl.url = ''
#        processText(stripHtml(data))
#      .error (err) ->
#        console.log err

  $scope.processFiles = (files) ->
    service.loadFiles files

  $scope.decline = (n, key) ->
    s = strings[key]
    q = n / 10
    r = n % 10
    return s[0] if r == 1 && q != 1
    return s[1] if 2 <= r && r <= 4 && q != 1
    s[2]
  $scope.decline3 = (n, s1, s2, s3) ->
    q = n / 10
    r = n % 10
    return s1 if r == 1 && q != 1
    return s2 if 2 <= r && r <= 4 && q != 1
    s3

  # init
  $scope.mode = 'loading'
  _init = service.init($scope)
  if _init
    _init.then ->
      $scope.data = service.data
      $scope.mode = 'loaded'
    , (error) ->
      $scope.mode = 'unavailable'
      $scope.error = error

  $scope.$watch 'text', (text) ->
    if text
      $scope.text = ''
      service.loadText text
  , true
]

app.filter 'longNum', ->
    (input) ->
      return '0' unless input
      input.toString().replace(/(\d)(?=(?:\d{3})+$)/g, '$1 ')

app.directive 'dropFiles', ->
  restrict: 'A'
  scope:
    onDrop: '&' # parent
  link: (scope, element, attr) ->
    # again we need the native object
    el = element[0]
    el.addEventListener 'dragover',
    (e) ->
      #e.dataTransfer.dropEffect = 'move'
      # allows us to drop
      e.preventDefault() if e.preventDefault
      @classList.add('over')
      return false
    ,
      false
    el.addEventListener 'dragenter',
    (e) ->
      @classList.add('over')
      false
    ,
      false
    el.addEventListener 'dragleave',
    (e) ->
      @classList.remove('over')
      false
    ,
      false

    el.addEventListener 'drop',
    (e) ->
      # Stops some browsers from redirecting.
      e.preventDefault() if e.preventDefault
      e.stopPropagation() if e.stopPropagation

      @classList.remove('over')

      #scope.$apply('drop()')
      scope.onDrop {files:e.dataTransfer.files}

      false
    ,
      false
