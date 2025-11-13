/**
 * Charts and Analytics using Chart.js
 */

let chartInstances = {};

function createTemperatureChart(canvasId, data) {
  const ctx = document.getElementById(canvasId);
  if (!ctx) return null;

  // Destroy existing chart
  if (chartInstances[canvasId]) {
    chartInstances[canvasId].destroy();
  }

  const labels = data.map(d => new Date(d.timestamp).toLocaleTimeString());
  const temperatures = data.map(d => d.temperature).filter(v => v != null);

  chartInstances[canvasId] = new Chart(ctx, {
    type: 'line',
    data: {
      labels: labels,
      datasets: [{
        label: 'Temperature (°C)',
        data: temperatures,
        borderColor: '#3B82F6',
        backgroundColor: 'rgba(59, 130, 246, 0.1)',
        borderWidth: 2,
        fill: true,
        tension: 0.4
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: true,
          position: 'top'
        }
      },
      scales: {
        y: {
          beginAtZero: false,
          title: {
            display: true,
            text: 'Temperature (°C)'
          }
        }
      }
    }
  });

  return chartInstances[canvasId];
}

function createHumidityChart(canvasId, data) {
  const ctx = document.getElementById(canvasId);
  if (!ctx) return null;

  if (chartInstances[canvasId]) {
    chartInstances[canvasId].destroy();
  }

  const labels = data.map(d => new Date(d.timestamp).toLocaleTimeString());
  const humidities = data.map(d => d.humidity).filter(v => v != null);

  chartInstances[canvasId] = new Chart(ctx, {
    type: 'line',
    data: {
      labels: labels,
      datasets: [{
        label: 'Humidity (%)',
        data: humidities,
        borderColor: '#60A5FA',
        backgroundColor: 'rgba(96, 165, 250, 0.1)',
        borderWidth: 2,
        fill: true,
        tension: 0.4
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: true,
          position: 'top'
        }
      },
      scales: {
        y: {
          beginAtZero: false,
          min: 0,
          max: 100,
          title: {
            display: true,
            text: 'Humidity (%)'
          }
        }
      }
    }
  });

  return chartInstances[canvasId];
}

function createMotorCyclesChart(canvasId, data) {
  const ctx = document.getElementById(canvasId);
  if (!ctx) return null;

  if (chartInstances[canvasId]) {
    chartInstances[canvasId].destroy();
  }

  const labels = data.map(d => new Date(d.timestamp).toLocaleTimeString());
  const m1 = data.map(d => d.m1 ? 1 : 0);
  const m2 = data.map(d => d.m2 ? 1 : 0);

  chartInstances[canvasId] = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: labels,
      datasets: [
        {
          label: 'Motor 1 (Drain)',
          data: m1,
          backgroundColor: 'rgba(16, 185, 129, 0.6)',
          borderColor: '#10B981',
          borderWidth: 1
        },
        {
          label: 'Motor 2 (Filter)',
          data: m2,
          backgroundColor: 'rgba(59, 130, 246, 0.6)',
          borderColor: '#3B82F6',
          borderWidth: 1
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: true,
          position: 'top'
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          max: 1,
          ticks: {
            stepSize: 1,
            callback: function(value) {
              return value === 1 ? 'ON' : 'OFF';
            }
          }
        }
      }
    }
  });

  return chartInstances[canvasId];
}

function createSystemStatusChart(canvasId, data) {
  const ctx = document.getElementById(canvasId);
  if (!ctx) return null;

  if (chartInstances[canvasId]) {
    chartInstances[canvasId].destroy();
  }

  const labels = data.map(d => new Date(d.timestamp).toLocaleTimeString());
  const run = data.map(d => d.run ? 1 : 0);
  const cp = data.map(d => d.cp ? 1 : 0);
  const heater = data.map(d => d.heater ? 1 : 0);
  const fan = data.map(d => d.fan ? 1 : 0);

  chartInstances[canvasId] = new Chart(ctx, {
    type: 'line',
    data: {
      labels: labels,
      datasets: [
        {
          label: 'System Running',
          data: run,
          borderColor: '#10B981',
          backgroundColor: 'rgba(16, 185, 129, 0.1)',
          borderWidth: 2,
          fill: true
        },
        {
          label: 'Compressor',
          data: cp,
          borderColor: '#3B82F6',
          backgroundColor: 'rgba(59, 130, 246, 0.1)',
          borderWidth: 2,
          fill: true
        },
        {
          label: 'Heater',
          data: heater,
          borderColor: '#EF4444',
          backgroundColor: 'rgba(239, 68, 68, 0.1)',
          borderWidth: 2,
          fill: true
        },
        {
          label: 'Fan',
          data: fan,
          borderColor: '#60A5FA',
          backgroundColor: 'rgba(96, 165, 250, 0.1)',
          borderWidth: 2,
          fill: true
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: true,
          position: 'top'
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          max: 1,
          ticks: {
            stepSize: 1,
            callback: function(value) {
              return value === 1 ? 'ON' : 'OFF';
            }
          }
        }
      }
    }
  });

  return chartInstances[canvasId];
}

function destroyAllCharts() {
  Object.values(chartInstances).forEach(chart => {
    if (chart) chart.destroy();
  });
  chartInstances = {};
}

// Export
window.charts = {
  createTemperatureChart,
  createHumidityChart,
  createMotorCyclesChart,
  createSystemStatusChart,
  destroyAllCharts
};

