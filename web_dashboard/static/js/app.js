/**
 * Main Application Logic
 */

// Theme Management
function initTheme() {
  const savedTheme = localStorage.getItem('theme') || 'light';
  document.documentElement.setAttribute('data-theme', savedTheme);
  updateThemeToggle(savedTheme);
}

function toggleTheme() {
  const currentTheme = document.documentElement.getAttribute('data-theme');
  const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', newTheme);
  localStorage.setItem('theme', newTheme);
  updateThemeToggle(newTheme);
}

function updateThemeToggle(theme) {
  const toggle = document.getElementById('theme-toggle');
  if (toggle) {
    toggle.innerHTML = theme === 'dark' 
      ? '<span>🌙</span>' 
      : '<span>☀️</span>';
  }
}

// Connection Status
let connectionStatus = false;

async function updateConnectionStatus() {
  try {
    const response = await api.getDevices();
    connectionStatus = response.success;
    updateStatusIndicator(connectionStatus);
  } catch (error) {
    connectionStatus = false;
    updateStatusIndicator(false);
  }
}

function updateStatusIndicator(connected) {
  const indicator = document.getElementById('connection-status');
  if (indicator) {
    indicator.className = `status-indicator ${connected ? 'connected' : ''}`;
    indicator.innerHTML = `
      <div class="status-dot ${connected ? 'connected' : ''}"></div>
      <span>${connected ? 'Connected' : 'Disconnected'}</span>
    `;
  }
}

// Admin Authentication
function checkAdminAccess() {
  const isAdmin = sessionStorage.getItem('admin_authenticated') === 'true';
  if (!isAdmin) {
    const passcode = prompt('Enter admin passcode:');
    if (passcode) {
      verifyAdmin(passcode);
    } else {
      window.location.href = '/';
    }
  }
  return isAdmin;
}

async function verifyAdmin(passcode) {
  try {
    const response = await api.verifyAdmin(passcode);
    if (response.success) {
      sessionStorage.setItem('admin_authenticated', 'true');
      return true;
    } else {
      alert('Invalid passcode');
      return false;
    }
  } catch (error) {
    alert('Authentication failed: ' + error.message);
    return false;
  }
}

// Utility Functions
function formatTimestamp(timestamp) {
  if (!timestamp) return 'N/A';
  const date = new Date(timestamp);
  return date.toLocaleString();
}

function formatTemperature(temp) {
  if (temp === null || temp === undefined) return '--';
  return `${temp.toFixed(1)}°C`;
}

function formatHumidity(hum) {
  if (hum === null || hum === undefined) return '--';
  return `${hum.toFixed(1)}%`;
}

function getFanLabel(speed) {
  switch (speed) {
    case 0: return 'Fan OFF';
    case 1: return 'Fan LOW';
    case 2: return 'Fan MED';
    case 3: return 'Fan HIGH';
    default: return 'Fan';
  }
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
  initTheme();
  updateConnectionStatus();
  
  // Update connection status every 5 seconds
  setInterval(updateConnectionStatus, 5000);
  
  // Theme toggle
  const themeToggle = document.getElementById('theme-toggle');
  if (themeToggle) {
    themeToggle.addEventListener('click', toggleTheme);
  }
});

// Export for use in other scripts
window.app = {
  api,
  toggleTheme,
  checkAdminAccess,
  verifyAdmin,
  formatTimestamp,
  formatTemperature,
  formatHumidity,
  getFanLabel
};

