###
  Ji-shi, cha-scha angular application for measuring content has been read
###

app = angular.module 'wordsApp', []

app.service 'VkService', ['$http', ($http) ->
  service = @
  service.connected = false
  service.test_mode = 1
  onIncorrectInit = ->
    console.log 'VK API initialization failed'
  try
    VK.init ->
      service.connected = true
    , ->
      onIncorrectInit()
    , '5.24'
  catch
    onIncorrectInit()
  service.getValue = (key, cb) ->
    VK.api 'storage.get', {key:key, test_mode:service.test_mode}, (data) ->
      cb data.response
  service.setValue = (key, value, cb) ->
    VK.api 'storage.set', {key:key, value:value, test_mode:service.test_mode}, (data) ->
      cb(data.response == 1) if cb
  service
]

app.controller 'WordsController', ['$scope', '$http', 'VkService', ($scope, $http, vk) ->
  ctrl = @
  ctrl.lastSubmit = undefined

  periods = [
    {n:6, d:1},
    {n:3, d:7},
    {n:5, d:4*7},
    {n:12, d:4*7}
  ]

  ctrl.reset = ->
    return unless confirm('Уверены?')
    initData()
    initToday()
    save()

  ctrl.processUrl = ->
    # http://www.corsproxy.com/
    # url = 'http://www.corsproxy.com/' + ctrl.url.replace(/https?:\/\//,"")
    url = ctrl.url
    $http.get url
      .success (data) ->
        ctrl.url = ''
        processText(stripHtml(data))
      .error (err) ->
        console.log err

  processText = (text) ->
    console.log text
    chars = countChars(text)
    words = countWords(text)
    $scope.lastSubmit =
      chars: chars
      words: words

    update()

    ctrl.data.today.chars += chars
    ctrl.data.today.words += words

    ctrl.data.chars += chars
    ctrl.data.words += words

    for i of ctrl.data.periods
      p = ctrl.data.periods[i]
      p.data[0] += words
      p.words += words

    $scope.$apply()
    save()

  save = ->
    vk.setValue 'data', data = JSON.stringify(ctrl.data)

  shift = (_n) ->
    for i of ctrl.data.periods
      p = ctrl.data.periods[i]
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
    if ctrl.data.today
      if ctrl.data.today.t != t
        shift(t - ctrl.data.today.t)
        initToday()
        return true
    else
      initToday()
      return true
    return false

  initToday = ->
    ctrl.data.today =
      t: today()
      words: 0
      chars: 0

  initData = ->
    ctrl.data =
      chars: 0,
      words: 0,
      periods: [
        {x:0,data:[0,0,0,0,0,0],words:0},
        {x:0,data:[0,0,0],words:0},
        {x:0,data:[0,0,0,0,0,],words:0},
        {x:0,data:[0,0,0,0,0,0,0,0,0,0,0,0],words:0}
      ]

  # util methods
  countChars = (s) ->
    s = s.replace(/\s/gi,"")
    s.length
  countWords = (s) ->
    s = s.replace(/(^\s*)|(\s*$)/gi,"") # exclude  start and end white-space
    s = s.replace(/\s/," ")
    s = s.replace(/\n/," ")
    s = s.replace(/[ ]{2,}/gi," ") # 2 or more space to 1
    s.split(' ').length

  stripHtml = (html) ->
    tmp = document.createElement("DIV")
    tmp.innerHTML = html
    tmp.textContent || tmp.innerText || ""

  today = ->
    # abs day from 1970
    parseInt((new Date().getTime() - new Date(1970, 0, 5).getTime()) / 86400000)

  $scope.processFiles = (files) ->
    for file in files
      if file.type.match('text/plain')
        loadTextFile file
  loadTextFile = (file) ->
    reader = new FileReader()
    reader.onload = (e) ->
      processText e.target.result
    reader.readAsText file


  # init
  initData()
  vk.getValue 'data', (data) ->
    data = JSON.parse(data)
    if (data)
      ctrl.data = data
    save() if update()
    $scope.$apply()


  @
]


app.directive 'dropFiles', ->
  return {
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

  }

