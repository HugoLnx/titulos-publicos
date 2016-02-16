(function() {
  function Loader() {
    var chartReady = false;
    var apiData = null;

    this.prepareGChartAndGetData = function(cb) {
      var uri = "/" + Config.attr + "/" + Config.type + "/" + Config.idate + (Config.edate ? "/" + Config.edate : "") + ".json";
      pegasus(uri).then(function(data) {
        if(chartReady) {
          cb(data);
        } else {
          apiData = data;
        }
      });
      google.charts.load('current', {packages: ['corechart']});
      google.charts.setOnLoadCallback(function() {
        if(apiData) {
          cb(apiData);
        } else {
          chartReady = true;
        }
      });
    };
  }

  function DateChart() {
    var minDate = null;
    var maxDate = null;

    var data = {};

    this.add = function(label, date, value) {
      if(!minDate || minDate > date) minDate = date;
      if(!maxDate || maxDate < date) maxDate = date;

      if(!data[label]) data[label] = {};
      data[label][asKey(date)] = value;
    };

    this.plotOn = function(chart) {
      var plotData = generatePlotData();
      var gData = google.visualization.arrayToDataTable(convertToGoogleArray(plotData));
      chart.draw(gData, {
        title: 'Titulos Públicos',
        hAxis: {
          gridlines: {count: 24*60*60},
          format: "MMM y"
        },
        vAxis: {format: "#,###%"},
        legend: { position: 'right' },
        width: 1300,
        height: 640
      });

    }

    function generatePlotData() {
      var plot = {
        labels: [],
        points: {}
      };

      forEachDay(function(date, i) {
        plot.labels[i] = asKey(date);
      });

      for(label in data) {
        var expDate = new Date(label);
        var points = [];
        
        var lastVal = null;
        forEachDay(function(date, i) {
          if(date <= expDate) {
            points[i] = data[label][asKey(date)] || lastVal;
            lastVal = points[i];
          }
        });
        plot.points[label] = points;
      }
      return plot;
    };

    function convertToGoogleArray(plotData) {
      var headers = ["Month"];
      var data = [];
      for(header in plotData.points) {
        headers.push(header);
      }
      

      var i = 0;
      for(var j in plotData.labels) {
        var label = plotData.labels[j];
        var x = label.split("-");
        var dt = new Date(1900, 1, 1, 0, 0, 0);
        dt.setFullYear(parseFloat(x[0]));
        dt.setMonth(parseFloat(x[1]));
        data[i] = [dt];
        for(header in plotData.points) {
          data[i].push(plotData.points[header][i]);
        }
        i++;
      }

      return [headers].concat(data);
    }

    var COLORS = [
      "rgb(0,255,0)", 
      "rgb(50,255,0)",
      "rgb(100,255,0)",
      "rgb(150,255,0)",
      "rgb(200,255,0)",

      "rgb(255,255,0)",
      "rgb(255,200,0)",
      "rgb(255,150,0)",
      "rgb(255,100,0)",
      "rgb(255,50,0)",

      "rgb(255,0,0)",
      "rgb(255,0,50)",
      "rgb(255,0,100)",
      "rgb(255,0,150)",
      "rgb(255,0,200)",

      "rgb(255,0,255)",
      "rgb(200,0,255)",
      "rgb(150,0,255)",
      "rgb(100,0,255)",
      "rgb(50,0,255)",
      "rgb(0,0,255)"
     ];
    var colorInx = 0;
    function newColor() {
      var color = COLORS[colorInx];
      colorInx = (colorInx + 1) % COLORS.length;
      return color;
    }

    function asKey(date) {
      return date.toISOString().slice(0, 7);
    }

    function forEachDay(func) {
      var i = 0;
      var date = new Date(minDate);
      while(date <= maxDate) {
        func(date, i);
        date.setMonth(date.getMonth()+1);
        i++;
      }
    }
  }

  DateChart.build = function(data) {
    var chart = new DateChart();
    for(expDate in data.data) {
      for(i in data.data[expDate]) {
        var info = data.data[expDate][i];
        chart.add(expDate, new Date(info.date), Math.round(info.value*100000)/1000);
      }
    }
    return chart;
  };

  new Loader().prepareGChartAndGetData(function(data) {
    var chart = DateChart.build(data);
    var simpleChart = new google.visualization.LineChart(document.getElementById("chart"));
    chart.plotOn(simpleChart);
  });
}());
