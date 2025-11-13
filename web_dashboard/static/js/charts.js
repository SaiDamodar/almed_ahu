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

  const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
  const tealColor = isDark ? '#14B8A6' : '#0D9488';
  const lightTeal = isDark ? 'rgba(20, 184, 166, 0.3)' : 'rgba(13, 148, 136, 0.3)';

  const labels = data.map(d => {
    const date = d.timestamp ? new Date(d.timestamp) : new Date();
    return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
  });
  const temperatures = data.map(d => d.temp || d.temperature).filter(v => v != null);

  chartInstances[canvasId] = new Chart(ctx, {
    type: 'line',
    data: {
      labels: labels,
      datasets: [{
        label: 'Temperature (°C)',
        data: temperatures,
        borderColor: tealColor,
        backgroundColor: lightTeal,
        borderWidth: 2,
        fill: true,
        tension: 0.4,
        pointRadius: 0,
        pointHoverRadius: 4
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: false
        },
        tooltip: {
          backgroundColor: isDark ? 'rgba(30, 41, 59, 0.95)' : 'rgba(255, 255, 255, 0.95)',
          titleColor: isDark ? '#F1F5F9' : '#1F2937',
          bodyColor: isDark ? '#F1F5F9' : '#1F2937',
          borderColor: tealColor,
          borderWidth: 1,
          padding: 12,
          displayColors: false
        }
      },
      scales: {
        x: {
          grid: {
            color: isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(0, 0, 0, 0.05)'
          },
          ticks: {
            color: isDark ? '#94A3B8' : '#6B7280'
          }
        },
        y: {
          beginAtZero: false,
          grid: {
            color: isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(0, 0, 0, 0.05)'
          },
          ticks: {
            color: isDark ? '#94A3B8' : '#6B7280',
            callback: function(value) {
              return value + '°C';
            }
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

  const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
  const tealColor = isDark ? '#14B8A6' : '#0D9488';
  const lightTeal = isDark ? 'rgba(20, 184, 166, 0.3)' : 'rgba(13, 148, 136, 0.3)';

  const labels = data.map(d => {
    const date = d.timestamp ? new Date(d.timestamp) : new Date();
    return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
  });
  const humidities = data.map(d => d.hum || d.humidity).filter(v => v != null);

  chartInstances[canvasId] = new Chart(ctx, {
    type: 'line',
    data: {
      labels: labels,
      datasets: [{
        label: 'Humidity (%)',
        data: humidities,
        borderColor: tealColor,
        backgroundColor: lightTeal,
        borderWidth: 2,
        fill: true,
        tension: 0.4,
        pointRadius: 0,
        pointHoverRadius: 4
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: false
        },
        tooltip: {
          backgroundColor: isDark ? 'rgba(30, 41, 59, 0.95)' : 'rgba(255, 255, 255, 0.95)',
          titleColor: isDark ? '#F1F5F9' : '#1F2937',
          bodyColor: isDark ? '#F1F5F9' : '#1F2937',
          borderColor: tealColor,
          borderWidth: 1,
          padding: 12,
          displayColors: false
        }
      },
      scales: {
        x: {
          grid: {
            color: isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(0, 0, 0, 0.05)'
          },
          ticks: {
            color: isDark ? '#94A3B8' : '#6B7280'
          }
        },
        y: {
          beginAtZero: false,
          min: 0,
          max: 100,
          grid: {
            color: isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(0, 0, 0, 0.05)'
          },
          ticks: {
            color: isDark ? '#94A3B8' : '#6B7280',
            callback: function(value) {
              return value + '%';
            }
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

  const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
  const lightTeal = isDark ? 'rgba(20, 184, 166, 0.6)' : 'rgba(13, 148, 136, 0.6)';
  const darkTeal = isDark ? 'rgba(20, 184, 166, 0.8)' : 'rgba(13, 148, 136, 0.8)';

  const labels = data.map(d => {
    const date = d.timestamp ? new Date(d.timestamp) : new Date();
    return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
  });
  const m1 = data.map(d => (d.m1 === true || d.m1 === 1 || d.m1 === 'true') ? 1 : 0);
  const m2 = data.map(d => (d.m2 === true || d.m2 === 1 || d.m2 === 'true') ? 1 : 0);

  chartInstances[canvasId] = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: labels,
      datasets: [
        {
          label: 'Motor 1 (Drain)',
          data: m1,
          backgroundColor: lightTeal,
          borderColor: darkTeal,
          borderWidth: 1
        },
        {
          label: 'Motor 2 (Filter)',
          data: m2,
          backgroundColor: darkTeal,
          borderColor: isDark ? '#14B8A6' : '#0D9488',
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
          position: 'top',
          labels: {
            color: isDark ? '#F1F5F9' : '#1F2937',
            usePointStyle: true,
            padding: 15
          }
        },
        tooltip: {
          backgroundColor: isDark ? 'rgba(30, 41, 59, 0.95)' : 'rgba(255, 255, 255, 0.95)',
          titleColor: isDark ? '#F1F5F9' : '#1F2937',
          bodyColor: isDark ? '#F1F5F9' : '#1F2937',
          borderColor: darkTeal,
          borderWidth: 1,
          padding: 12
        }
      },
      scales: {
        x: {
          grid: {
            color: isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(0, 0, 0, 0.05)'
          },
          ticks: {
            color: isDark ? '#94A3B8' : '#6B7280'
          }
        },
        y: {
          beginAtZero: true,
          max: 1,
          grid: {
            color: isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(0, 0, 0, 0.05)'
          },
          ticks: {
            color: isDark ? '#94A3B8' : '#6B7280',
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

// Area Chart for Temperature (matching image style)
function createTemperatureAreaChart(canvasId, data) {
  const ctx = document.getElementById(canvasId);
  if (!ctx) return null;

  if (chartInstances[canvasId]) {
    chartInstances[canvasId].destroy();
  }

  const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
  const tealColor = isDark ? '#14B8A6' : '#0D9488';
  const lightTeal = isDark ? 'rgba(20, 184, 166, 0.4)' : 'rgba(13, 148, 136, 0.4)';

  const labels = data.map(d => {
    const date = d.timestamp ? new Date(d.timestamp) : new Date();
    return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
  });
  const temperatures = data.map(d => d.temp || d.temperature).filter(v => v != null);

  chartInstances[canvasId] = new Chart(ctx, {
    type: 'line',
    data: {
      labels: labels,
      datasets: [{
        label: 'Temperature (°C)',
        data: temperatures,
        borderColor: tealColor,
        backgroundColor: lightTeal,
        borderWidth: 2,
        fill: true,
        tension: 0.4,
        pointRadius: 0,
        pointHoverRadius: 4
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: false
        },
        tooltip: {
          backgroundColor: isDark ? 'rgba(30, 41, 59, 0.95)' : 'rgba(255, 255, 255, 0.95)',
          titleColor: isDark ? '#F1F5F9' : '#1F2937',
          bodyColor: isDark ? '#F1F5F9' : '#1F2937',
          borderColor: tealColor,
          borderWidth: 1,
          padding: 12,
          displayColors: false
        }
      },
      scales: {
        x: {
          grid: {
            color: isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(0, 0, 0, 0.05)'
          },
          ticks: {
            color: isDark ? '#94A3B8' : '#6B7280'
          }
        },
        y: {
          beginAtZero: false,
          grid: {
            color: isDark ? 'rgba(255, 255, 255, 0.05)' : 'rgba(0, 0, 0, 0.05)'
          },
          ticks: {
            color: isDark ? '#94A3B8' : '#6B7280',
            callback: function(value) {
              return value + '°C';
            }
          }
        }
      }
    }
  });

  return chartInstances[canvasId];
}

// Export
window.charts = {
  createTemperatureChart,
  createHumidityChart,
  createMotorCyclesChart,
  createSystemStatusChart,
  createTemperatureAreaChart,
  destroyAllCharts
};

