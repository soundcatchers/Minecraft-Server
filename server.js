const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 5000;

app.use(express.static('public'));

app.get('/api/config/:file', (req, res) => {
  res.set('Cache-Control', 'no-cache');
  const file = req.params.file;
  const filePaths = {
    'server-properties': 'server.properties',
    'paper-global': 'config/paper-global.yml',
    'paper-world': 'config/paper-world-defaults.yml',
    'systemd': 'etc/systemd/system/minecraft.service',
    'ops': 'ops.json',
    'setup': 'scripts/setup.sh',
    'install-systemd': 'scripts/install-systemd.sh',
    'update-plugins': 'scripts/update-plugins.sh',
    'backup': 'scripts/backup.sh',
    'readme': 'README.md'
  };
  
  if (!filePaths[file]) {
    return res.status(404).json({ error: 'File not found' });
  }
  
  try {
    const content = fs.readFileSync(filePaths[file], 'utf8');
    res.json({ content });
  } catch (err) {
    res.status(500).json({ error: 'Could not read file' });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});
