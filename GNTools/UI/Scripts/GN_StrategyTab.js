function updateStrategiesTab() {
  const name = $("#strategy-select").val();
  if (!name || !Store.strategies[name]) return;

  const container = $("#strategy-content");
  container.empty();

  const text = Store.strategies[name];

  const html = `
    <div class="strategy-editor">

      <div class="strategy-toolbar">
        <button id="strategy-revert">⟳</button>
        <button id="strategy-save">💾</button>
      </div>
      <textarea id="strategy-text" spellcheck="false" class="strategy-textarea" style="width:100%; height:300px; font-family:monospace; font-size:14px;">${escapeHtml(text).trim()}</textarea>
    </div>
  `;

  container.append(html);

  bindStrategyActions(name);
}

function bindStrategyActions(name) {

  $("#strategy-save").on("click", function () {
    Store.strategies[name] = $("#strategy-text").val();
//    sketchup.saveStrategy(name, Store.strategies[name]);
  });

  $("#strategy-revert").on("click", function () {
    if (!Store.defaults.strategies[name]) return;
    Store.strategies[name] = Store.defaults.strategies[name];
    updateStrategiesTab();
  });

  $("#strategy-remove").on("click", function () {
    if (!confirm(`Remove strategy "${name}" ?`)) return;
    delete Store.strategies[name];
//    sketchup.removeStrategy(name);
    populateSelect("#strategy-select", Store.strategies);
    updateStrategiesTab();
  });

  $("#strategy-add").on("click", function () {
    const newName = prompt("Nom de la nouvelle stratégie ?");
    if (!newName || Store.strategies[newName]) return;

    Store.strategies[newName] = "; new strategy\n";
    populateSelect("#strategy-select", Store.strategies);
    $("#strategy-select").val(newName).selectmenu("refresh");
    updateStrategiesTab();
  });
}
