document.addEventListener('DOMContentLoaded', function() {
  const configTabs = document.querySelectorAll('.config-section:first-of-type .tabs .tab');
  const scriptTabs = document.querySelectorAll('#script-tabs .tab');
  const configContent = document.getElementById('config-content');
  const scriptContent = document.getElementById('script-content');

  async function loadConfig(file, targetElement) {
    try {
      const response = await fetch('/api/config/' + file);
      const data = await response.json();
      if (data.error) {
        targetElement.textContent = 'Error: ' + data.error;
      } else {
        targetElement.textContent = data.content;
      }
    } catch (err) {
      targetElement.textContent = 'Failed to load configuration';
    }
  }

  configTabs.forEach(function(tab) {
    tab.addEventListener('click', function() {
      configTabs.forEach(function(t) { t.classList.remove('active'); });
      tab.classList.add('active');
      loadConfig(tab.dataset.file, configContent);
    });
  });

  scriptTabs.forEach(function(tab) {
    tab.addEventListener('click', function() {
      scriptTabs.forEach(function(t) { t.classList.remove('active'); });
      tab.classList.add('active');
      loadConfig(tab.dataset.file, scriptContent);
    });
  });

  loadConfig('server-properties', configContent);
});
