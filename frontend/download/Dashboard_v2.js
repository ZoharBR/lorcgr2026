import React, { useState, useEffect } from "react";

const Dashboard = () => {
  const [stats, setStats] = useState({ devices_total: 0, bras_count: 0, pppoe_total: 0, pppoe_details: [], server_health: { cpu: 0, ram: 0, disk: 0 } });
  const [devices, setDevices] = useState([]);
  const [gbics, setGbics] = useState([]);
  const [gbicSummary, setGbicSummary] = useState({ critical: 0, warning: 0, down: 0, normal: 0 });
  const [loading, setLoading] = useState(true);
  const [time, setTime] = useState(new Date());
  const [filter, setFilter] = useState("all");
  const [searchDevice, setSearchDevice] = useState("");
  const [selectedGbic, setSelectedGbic] = useState(null);
  const [activeTab, setActiveTab] = useState("overview");

  useEffect(() => {
    loadData();
    const interval = setInterval(loadData, 60000);
    const clockInterval = setInterval(() => setTime(new Date()), 1000);
    return () => { clearInterval(interval); clearInterval(clockInterval); };
  }, []);

  const loadData = async () => {
    setLoading(true);
    try {
      const devRes = await fetch("/api/devices/list/");
      if (devRes.ok) setDevices(await devRes.json());
      
      const dashRes = await fetch("/api/devices/dashboard/");
      if (dashRes.ok) setStats(await dashRes.json());
      
      const gbicRes = await fetch("/api/devices/gbic/list/?hide_no_data=true");
      if (gbicRes.ok) {
        const data = await gbicRes.json();
        if (data.status === "success") { 
          setGbics(data.gbics || []); 
          setGbicSummary(data.summary || { critical: 0, warning: 0, down: 0, normal: 0 }); 
        }
      }
    } catch (e) { 
      console.error("Error loading data:", e); 
    } finally { 
      setLoading(false); 
    }
  };

  const onlineDevices = devices.filter(d => d.is_online === true).length;
  const offlineDevices = devices.filter(d => d.is_online === false).length;

  const filteredGbics = gbics.filter(g => {
    if (filter !== "all" && g.status !== filter) return false;
    if (searchDevice && !g.device_name.toLowerCase().includes(searchDevice.toLowerCase()) && !g.interface.toLowerCase().includes(searchDevice.toLowerCase())) return false;
    return true;
  });

  const getStatusColor = (s) => {
    if (s === "critical") return "bg-red-500";
    if (s === "warning") return "bg-yellow-500";
    if (s === "down") return "bg-red-700";
    if (s === "normal") return "bg-green-500";
    return "bg-gray-500";
  };
  
  const getStatusLabel = (s) => {
    if (s === "critical") return "CRITICO";
    if (s === "warning") return "ATENCAO";
    if (s === "down") return "DOWN";
    if (s === "normal") return "NORMAL";
    return "?";
  };

  const formatValue = (val, unit) => {
    if (val === null || val === undefined) return "--";
    return `${val}${unit}`;
  };

  const formatTemp = (val) => {
    if (val === null || val === undefined) return "--";
    const num = typeof val === 'number' ? val : parseFloat(val);
    return isNaN(num) ? "--" : `${num.toFixed(1)}C`;
  };

  const formatPower = (val) => {
    if (val === null || val === undefined) return "--";
    const num = typeof val === 'number' ? val : parseFloat(val);
    return isNaN(num) ? "--" : `${num.toFixed(2)} dBm`;
  };

  return (
    <div className="p-4 bg-gray-900 min-h-screen text-white">
      {/* Header */}
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-blue-400">Dashboard LOR CGR - Network Management</h1>
        <div className="text-right">
          <div className="text-lg">{time.toLocaleDateString('pt-BR')}</div>
          <div className="text-xl font-mono text-blue-300">{time.toLocaleTimeString('pt-BR')}</div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 mb-4 border-b border-gray-700 pb-2">
        {["overview", "gbics", "devices", "pppoe"].map(tab => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`px-4 py-2 rounded-t ${activeTab === tab ? "bg-blue-600 text-white" : "bg-gray-700 text-gray-300 hover:bg-gray-600"}`}
          >
            {tab === "overview" ? "Visao Geral" : tab === "gbics" ? "GBICs" : tab === "devices" ? "Dispositivos" : "PPPoE"}
          </button>
        ))}
      </div>

      {loading && <div className="text-center text-blue-400 mb-4">Carregando...</div>}

      {/* Overview Tab */}
      {activeTab === "overview" && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          {/* Device Status Card */}
          <div className="bg-gray-800 rounded-lg p-4 shadow">
            <h3 className="text-gray-400 text-sm mb-2">Dispositivos</h3>
            <div className="flex items-center gap-4">
              <div className="text-3xl font-bold">{devices.length}</div>
              <div className="flex-1">
                <div className="flex justify-between text-sm">
                  <span className="text-green-400">Online: {onlineDevices}</span>
                  <span className="text-red-400">Offline: {offlineDevices}</span>
                </div>
                <div className="w-full bg-gray-700 rounded-full h-2 mt-1">
                  <div className="bg-green-500 h-2 rounded-full" style={{ width: `${devices.length ? (onlineDevices / devices.length * 100) : 0}%` }}></div>
                </div>
              </div>
            </div>
          </div>

          {/* GBIC Status Card */}
          <div className="bg-gray-800 rounded-lg p-4 shadow">
            <h3 className="text-gray-400 text-sm mb-2">GBICs Monitorados</h3>
            <div className="flex items-center gap-4">
              <div className="text-3xl font-bold">{gbics.length}</div>
              <div className="flex-1 text-sm">
                <div className="flex flex-wrap gap-2">
                  <span className="text-green-400">OK: {gbicSummary.normal}</span>
                  <span className="text-yellow-400">Atencao: {gbicSummary.warning}</span>
                  <span className="text-red-400">Critico: {gbicSummary.critical}</span>
                </div>
              </div>
            </div>
          </div>

          {/* PPPoE Card */}
          <div className="bg-gray-800 rounded-lg p-4 shadow">
            <h3 className="text-gray-400 text-sm mb-2">PPPoE Total</h3>
            <div className="text-3xl font-bold text-blue-400">{stats.pppoe_total}</div>
            <div className="text-sm text-gray-400 mt-1">{stats.bras_count} BRAS ativos</div>
          </div>

          {/* Server Health Card */}
          <div className="bg-gray-800 rounded-lg p-4 shadow">
            <h3 className="text-gray-400 text-sm mb-2">Servidor</h3>
            <div className="space-y-2">
              <div>
                <div className="flex justify-between text-sm">
                  <span>CPU</span>
                  <span>{stats.server_health.cpu}%</span>
                </div>
                <div className="w-full bg-gray-700 rounded-full h-2">
                  <div className="bg-blue-500 h-2 rounded-full" style={{ width: `${stats.server_health.cpu}%` }}></div>
                </div>
              </div>
              <div>
                <div className="flex justify-between text-sm">
                  <span>RAM</span>
                  <span>{stats.server_health.ram}%</span>
                </div>
                <div className="w-full bg-gray-700 rounded-full h-2">
                  <div className="bg-purple-500 h-2 rounded-full" style={{ width: `${stats.server_health.ram}%` }}></div>
                </div>
              </div>
              <div>
                <div className="flex justify-between text-sm">
                  <span>Disco</span>
                  <span>{stats.server_health.disk}%</span>
                </div>
                <div className="w-full bg-gray-700 rounded-full h-2">
                  <div className="bg-orange-500 h-2 rounded-full" style={{ width: `${stats.server_health.disk}%` }}></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* GBICs Tab */}
      {activeTab === "gbics" && (
        <div>
          {/* GBIC Summary Cards */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
            <div className="bg-green-900/30 border border-green-700 rounded-lg p-4 text-center">
              <div className="text-3xl font-bold text-green-400">{gbicSummary.normal}</div>
              <div className="text-sm text-green-300">Normal</div>
            </div>
            <div className="bg-yellow-900/30 border border-yellow-700 rounded-lg p-4 text-center">
              <div className="text-3xl font-bold text-yellow-400">{gbicSummary.warning}</div>
              <div className="text-sm text-yellow-300">Atencao</div>
            </div>
            <div className="bg-red-900/30 border border-red-700 rounded-lg p-4 text-center">
              <div className="text-3xl font-bold text-red-400">{gbicSummary.critical}</div>
              <div className="text-sm text-red-300">Critico</div>
            </div>
            <div className="bg-red-950/30 border border-red-900 rounded-lg p-4 text-center">
              <div className="text-3xl font-bold text-red-600">{gbicSummary.down}</div>
              <div className="text-sm text-red-400">Down</div>
            </div>
          </div>

          {/* Filters */}
          <div className="flex flex-wrap gap-4 mb-4">
            <input
              type="text"
              placeholder="Buscar dispositivo ou interface..."
              value={searchDevice}
              onChange={(e) => setSearchDevice(e.target.value)}
              className="px-4 py-2 bg-gray-800 border border-gray-700 rounded text-white focus:outline-none focus:border-blue-500"
            />
            <select
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
              className="px-4 py-2 bg-gray-800 border border-gray-700 rounded text-white focus:outline-none focus:border-blue-500"
            >
              <option value="all">Todos</option>
              <option value="normal">Normal</option>
              <option value="warning">Atencao</option>
              <option value="critical">Critico</option>
              <option value="down">Down</option>
            </select>
          </div>

          {/* GBIC Table */}
          <div className="bg-gray-800 rounded-lg overflow-hidden">
            <table className="w-full">
              <thead className="bg-gray-700">
                <tr>
                  <th className="px-4 py-3 text-left text-sm">Dispositivo</th>
                  <th className="px-4 py-3 text-left text-sm">Interface</th>
                  <th className="px-4 py-3 text-center text-sm">Status</th>
                  <th className="px-4 py-3 text-center text-sm">Temp</th>
                  <th className="px-4 py-3 text-center text-sm">TX Power</th>
                  <th className="px-4 py-3 text-center text-sm">RX Power</th>
                  <th className="px-4 py-3 text-left text-sm">Alertas</th>
                </tr>
              </thead>
              <tbody>
                {filteredGbics.map((gbic, idx) => (
                  <tr 
                    key={gbic.id} 
                    className={`border-t border-gray-700 hover:bg-gray-700/50 cursor-pointer ${idx % 2 === 0 ? 'bg-gray-800' : 'bg-gray-800/50'}`}
                    onClick={() => setSelectedGbic(gbic)}
                  >
                    <td className="px-4 py-3">
                      <div className="font-medium">{gbic.device_name}</div>
                    </td>
                    <td className="px-4 py-3">
                      <div>{gbic.interface}</div>
                      {gbic.type && <div className="text-xs text-gray-500">{gbic.type}</div>}
                    </td>
                    <td className="px-4 py-3 text-center">
                      <span className={`px-2 py-1 rounded text-xs font-bold ${getStatusColor(gbic.status)}`}>
                        {getStatusLabel(gbic.status)}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-center font-mono">
                      <span className={gbic.temperature > 45 ? "text-red-400" : "text-green-400"}>
                        {formatTemp(gbic.temperature)}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-center font-mono">
                      <span className={gbic.tx_power < 0 ? "text-yellow-400" : "text-green-400"}>
                        {formatPower(gbic.tx_power)}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-center font-mono">
                      <span className={gbic.rx_power < -20 ? "text-red-400" : gbic.rx_power < -15 ? "text-yellow-400" : "text-green-400"}>
                        {formatPower(gbic.rx_power)}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-xs">
                      {gbic.alerts && gbic.alerts.length > 0 ? (
                        <ul className="space-y-1">
                          {gbic.alerts.map((alert, i) => (
                            <li key={i} className="text-red-400">{alert}</li>
                          ))}
                        </ul>
                      ) : <span className="text-gray-500">--</span>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {filteredGbics.length === 0 && (
              <div className="text-center text-gray-500 py-8">Nenhum GBIC encontrado</div>
            )}
          </div>
        </div>
      )}

      {/* Devices Tab */}
      {activeTab === "devices" && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {devices.map((device) => (
            <div 
              key={device.id} 
              className={`bg-gray-800 rounded-lg p-4 border-l-4 ${device.is_online ? 'border-green-500' : 'border-red-500'}`}
            >
              <div className="flex justify-between items-start">
                <div>
                  <h4 className="font-bold text-lg">{device.name}</h4>
                  <p className="text-sm text-gray-400">{device.ip}</p>
                  <p className="text-xs text-gray-500">{device.device_type || 'Unknown'}</p>
                </div>
                <span className={`px-2 py-1 rounded text-xs ${device.is_online ? 'bg-green-900 text-green-300' : 'bg-red-900 text-red-300'}`}>
                  {device.is_online ? 'Online' : 'Offline'}
                </span>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* PPPoE Tab */}
      {activeTab === "pppoe" && (
        <div>
          <div className="bg-gray-800 rounded-lg p-6 mb-6">
            <h3 className="text-xl font-bold mb-4">Total PPPoE: {stats.pppoe_total}</h3>
            {stats.pppoe_details && stats.pppoe_details.length > 0 && (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {stats.pppoe_details.map((bras, idx) => (
                  <div key={idx} className="bg-gray-700 rounded p-4">
                    <h4 className="font-medium">{bras.name || bras.ip}</h4>
                    <div className="text-2xl font-bold text-blue-400">{bras.count}</div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* GBIC Detail Modal */}
      {selectedGbic && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4" onClick={() => setSelectedGbic(null)}>
          <div className="bg-gray-800 rounded-lg p-6 max-w-2xl w-full max-h-[90vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
            <div className="flex justify-between items-start mb-4">
              <h2 className="text-xl font-bold text-blue-400">Detalhes GBIC</h2>
              <button onClick={() => setSelectedGbic(null)} className="text-gray-400 hover:text-white text-2xl">&times;</button>
            </div>
            
            <div className="grid grid-cols-2 gap-4 mb-6">
              <div>
                <label className="text-gray-400 text-sm">Dispositivo</label>
                <div className="font-medium">{selectedGbic.device_name}</div>
              </div>
              <div>
                <label className="text-gray-400 text-sm">Interface</label>
                <div>{selectedGbic.interface}</div>
              </div>
              <div>
                <label className="text-gray-400 text-sm">Tipo</label>
                <div>{selectedGbic.type || '--'}</div>
              </div>
              <div>
                <label className="text-gray-400 text-sm">Status</label>
                <span className={`px-2 py-1 rounded text-sm ${getStatusColor(selectedGbic.status)}`}>
                  {getStatusLabel(selectedGbic.status)}
                </span>
              </div>
              <div>
                <label className="text-gray-400 text-sm">Vendor</label>
                <div>{selectedGbic.vendor || '--'}</div>
              </div>
              <div>
                <label className="text-gray-400 text-sm">Serial</label>
                <div>{selectedGbic.serial || '--'}</div>
              </div>
            </div>

            <div className="grid grid-cols-3 gap-4 mb-6">
              <div className="bg-gray-700 rounded p-4 text-center">
                <div className="text-gray-400 text-sm">Temperatura</div>
                <div className={`text-2xl font-bold ${selectedGbic.temperature > 45 ? 'text-red-400' : 'text-green-400'}`}>
                  {formatTemp(selectedGbic.temperature)}
                </div>
              </div>
              <div className="bg-gray-700 rounded p-4 text-center">
                <div className="text-gray-400 text-sm">TX Power</div>
                <div className={`text-2xl font-bold ${selectedGbic.tx_power < 0 ? 'text-yellow-400' : 'text-green-400'}`}>
                  {formatPower(selectedGbic.tx_power)}
                </div>
              </div>
              <div className="bg-gray-700 rounded p-4 text-center">
                <div className="text-gray-400 text-sm">RX Power</div>
                <div className={`text-2xl font-bold ${selectedGbic.rx_power < -20 ? 'text-red-400' : 'text-green-400'}`}>
                  {formatPower(selectedGbic.rx_power)}
                </div>
              </div>
            </div>

            {selectedGbic.alerts && selectedGbic.alerts.length > 0 && (
              <div className="bg-red-900/30 border border-red-700 rounded p-4">
                <h4 className="font-medium text-red-400 mb-2">Alertas</h4>
                <ul className="space-y-1">
                  {selectedGbic.alerts.map((alert, i) => (
                    <li key={i} className="text-red-300">{alert}</li>
                  ))}
                </ul>
              </div>
            )}

            {selectedGbic.alarm_config && (
              <div className="bg-gray-700 rounded p-4 mt-4">
                <h4 className="font-medium text-blue-400 mb-2">Configuracao de Alarmes</h4>
                <div className="grid grid-cols-2 gap-2 text-sm">
                  <div>Temp Warning: {selectedGbic.alarm_config.temp_warning}C</div>
                  <div>Temp Critical: {selectedGbic.alarm_config.temp_critical}C</div>
                  <div>RX Warning: {selectedGbic.alarm_config.rx_warning} dBm</div>
                  <div>RX Critical: {selectedGbic.alarm_config.rx_critical} dBm</div>
                  <div>TX Warning: {selectedGbic.alarm_config.tx_warning} dBm</div>
                  <div>TX Critical: {selectedGbic.alarm_config.tx_critical} dBm</div>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default Dashboard;
