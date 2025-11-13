/**
 * API Client for ALMED AHU Web Dashboard
 */

const API_BASE = '';

class APIClient {
  constructor() {
    this.baseURL = API_BASE;
  }

  async request(endpoint, options = {}) {
    const url = `${this.baseURL}${endpoint}`;
    const config = {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers
      },
      ...options
    };

    if (options.body) {
      config.body = JSON.stringify(options.body);
    }

    try {
      const response = await fetch(url, config);
      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(data.error || 'Request failed');
      }
      
      return data;
    } catch (error) {
      console.error('API Error:', error);
      throw error;
    }
  }

  // Devices
  async getDevices() {
    return this.request('/api/devices');
  }

  async getDeviceStatus(deviceId) {
    return this.request(`/api/device/${deviceId}/status`);
  }

  async getTelemetry(deviceId, hours = 24) {
    return this.request(`/api/device/${deviceId}/telemetry?hours=${hours}`);
  }

  async sendCommand(deviceId, command) {
    return this.request(`/api/device/${deviceId}/command`, {
      method: 'POST',
      body: { command }
    });
  }

  // Admin
  async verifyAdmin(passcode) {
    return this.request('/api/admin/verify', {
      method: 'POST',
      body: { passcode }
    });
  }

  // Control Commands
  async startDevice(deviceId) {
    return this.sendCommand(deviceId, { start: true });
  }

  async stopDevice(deviceId) {
    return this.sendCommand(deviceId, { stop: true });
  }

  async toggleDevice(deviceId) {
    return this.sendCommand(deviceId, { toggle: true });
  }

  async setTemperature(deviceId, temp) {
    return this.sendCommand(deviceId, { setpoint: temp });
  }

  async setHumidity(deviceId, hum) {
    return this.sendCommand(deviceId, { humset: hum });
  }

  async setFanSpeed(deviceId, speed) {
    return this.sendCommand(deviceId, { fan: speed });
  }

  async toggleFanSpeed(deviceId) {
    return this.sendCommand(deviceId, { fanToggle: true });
  }

  async provisionWifi(deviceId, wifiConfig) {
    return this.sendCommand(deviceId, {
      type: 'provision_wifi',
      ...wifiConfig
    });
  }

  async provisionBroker(deviceId, brokerConfig) {
    return this.sendCommand(deviceId, {
      type: 'provision_broker',
      ...brokerConfig
    });
  }

  async provisionMotorTimings(deviceId, timings) {
    return this.sendCommand(deviceId, {
      type: 'provision_motor_timings',
      ...timings
    });
  }
}

// Export singleton instance
const api = new APIClient();

