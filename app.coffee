###
  Ji-shi, cha-scha angular application for measuring content has been read
###

app = angular.module 'wordsApp', []

app.factory 'VkApi', ['$q', ($q) ->
  service =
    test_mode: 1
    getValue: (scope, key) ->
      deferred = $q.defer()
      VK.api 'storage.get', {key:key, test_mode:service.test_mode}, (data) ->
        scope.$apply ->
          deferred.resolve data.response
      deferred.promise
    setValue: (scope, key, value) ->
      deferred = $q.defer()
      VK.api 'storage.set', {key:key, value:value, test_mode:service.test_mode}, (data) ->
        scope.$apply ->
          if data.response && data.response == 1
            console.log data
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
]


app.factory 'WordsService', ['$q', '$http', 'VkApi', ($q, $http, storage) ->
  self = @

  # public interface
  service =
    init: (scope) ->
      self.scope = scope
      deferred = $q.defer()
      _init = storage.init(self.scope)
      return unless _init
      _init.then ->
        storage.getValue(self.scope, 'data').then (data) ->
          data = JSON.parse(data) if data
          if (data)
            service.data = data
            if update()
              save().then ->
                deferred.resolve()
              return
          else
            initData()
          deferred.resolve()
      deferred.promise

    loadFiles: (files) ->
      for file in files
        if file.type.match('text/plain')
          loadTextFile file
        else if file.type.match('application/pdf')
          loadPdfFile file
    reset: ->
      resetData()
      initToday()
      save()

  periods = [
    {n:6, d:1}
    {n:3, d:7}
    {n:5, d:4*7}
    {n:12, d:4*7}
  ]

  # implementation

  loadTextFile = (file) ->
    reader = new FileReader()
    reader.onload = (e) ->
      processText e.target.result
    reader.readAsText file

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

    self.scope.lastSubmit =
      chars: chars
      words: words

    update()

    service.data.today.chars += chars
    service.data.today.words += words

    service.data.chars += chars
    service.data.words += words

    for i of service.data.periods
      p = service.data.periods[i]
      p.data[0] += words
      p.words += words

    #$scope.$apply()
    save()


  shift = (_n) ->
    for i of service.data.periods
      p = service.data.periods[i]
      np = periods[i].n
      d = periods[i].n

      # calc real n steps for shifting
      n = parseInt((_n + p.x) / d)
      if n <= 0
        p.x += n
        return
      p.x += _n - (n * d)

      # shift values and put zeros
      d = np - n
      if d > 0
        p.data[i] = p.data[i-n] for i in [(np-1)..(np-d)]
        p.data[i] = 0 for i in [0...n]
      else
        p.data[i] = 0 for i in [0...np]

      p.words = 0
      p.words += value for value in p.data


  update = ->
    t = today()
    if service.data.today
      if service.data.today.t != t
        shift(t - service.data.today.t)
        initToday()
        return true
    else
      initToday()
      return true
    return false

  initToday = ->
    service.data.today =
      t: today()
      words: 0
      chars: 0

  initData = ->
    service.data = {}
    resetData()
  resetData = ->
    service.data.chars = 0
    service.data.words = 0
    service.data.periods = [
      {x:0,data:[0,0,0,0,0,0],words:0},
      {x:0,data:[0,0,0],words:0},
      {x:0,data:[0,0,0,0,0,],words:0},
      {x:0,data:[0,0,0,0,0,0,0,0,0,0,0,0],words:0}
    ]

  save = ->
    deferred = $q.defer()
    storage.setValue(self.scope, 'data', JSON.stringify(service.data)).then ->
      deferred.resolve()
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

  countChars2 = (s) ->
    indexOf()
    s = s.replace(/[^a-zA-Z0-9абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ]/gi,"")
    s.length
  countWords2 = (s) ->
    s = s.replace(/\n/gi," ")
    s = s.replace(/\r/gi," ")
    s = s.replace(/[\s\.,\?\!;:]/gi," ") # spaces between words
    s = s.replace(/[^a-zA-Z0-9абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ\s]/gi,"")
    s = s.replace(/(^\s*)|(\s*$)/gi,"") # exclude start and end white-space
    s = s.replace(/\s{2,}/gi," ") # 2 or more space to 1
    s.split(' ').length

  stripHtml = (html) ->
    tmp = document.createElement("DIV")
    tmp.innerHTML = html
    tmp.textContent || tmp.innerText || ""

  today = ->
    # abs day from 1970
    parseInt((new Date().getTime() - new Date(1970, 0, 5).getTime()) / 86400000)

  service
]

app.controller 'WordsController', ['$scope', 'WordsService', ($scope, service) ->
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

  # init
  _init = service.init($scope)
  if _init
    _init.then ->
      $scope.data = service.data
      $scope.loaded = true
]


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


