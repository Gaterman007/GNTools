// ================================
// Global Store
// ================================
const Store = {
  schemas: {},
  strategies: {},
  previews: {},

  defaults: {
    schemas: {},
    strategies: {},
    previews: {}
  }
};

function deepClone(o) {
  return JSON.parse(JSON.stringify(o));
}

// ================================
// Init
// ================================
$(document).ready(function () {
  sketchup.ready();
  $("#tp-tabs").tabs();
  $( "#accept, #cancel, #setDefault, #apply").button();
  $( "#apply" ).on( "click", function( event ) {
	  const type = $('#schema-select').val();
	  if (!type) return;
	  sketchup.saveSchema(type, Store.schemas[type].Schema);
	  sketchup.apply();
  });
  
  $( "#accept" ).on( "click", function( event ) {
	sketchup.accept();
  });

  $( "#cancel" ).on( "click", function( event ) {
	sketchup.cancel();
  });
});

// ================================
// Loaders
// ================================
function loadSchemas(json) {
  Store.schemas = json;
  Store.defaults.schemas = deepClone(json);
  populateSchemaSelect();
}

function loadStrategies(json) {
  Store.strategies = json;
  console.log(Store.strategies)
  Store.defaults.strategies = deepClone(json);
  populateSelect("#strategy-select", Store.strategies, updateTab);
  updateStrategiesTab();
}

function loadPreviews(json) {
  Store.previews = json;
  Store.defaults.previews = deepClone(json);
  populateSelect("#preview-select", Store.previews, updateTab);
  updatePreviewsTab()
}

// ================================
// Select helpers
// ================================
function populateSelect(selectId, items, onChange) {
  const select = $(selectId);
  const current = select.val();

  select.empty();
  Object.keys(items).sort().forEach(name =>
    select.append(`<option value="${name}">${name}</option>`)
  );

  select.val(current && items[current] ? current : Object.keys(items)[0] ?? "");

  if (select.hasClass('ui-selectmenu-button')) {
    select.selectmenu('refresh');
  } else {
    select.selectmenu({ change: onChange });
  }
}

function populateSchemaSelect() {
  populateSelect("#schema-select", Store.schemas, () => {
    updateSchemaContent($('#schema-select').val());
  });
  updateSchemaContent($('#schema-select').val());
}

// ================================
// Tabs
// ================================
function updateTab(event, ui) {
  const select = event.target.id;
  let container, data;

  if (select === "strategy-select") {
    container = $("#strategy-content");
    data = Store.strategies[$('#strategy-select').val()];
	updateStrategiesTab();
  } else if (select === "preview-select") {
    container = $("#preview-content");
    data = Store.previews[$('#preview-select').val()];
	updatePreviewsTab();
  }
}

// ================================
// Schema main
// ================================
function updateSchemaContent(type) {
  const schema = Store.schemas[type];
  if (!schema) return;

  const params = schema.Schema || {};
  const defaults = Store.defaults.schemas[type]?.Schema || {};
  const container = $('#schema-content');

  container.empty();
  container.append(buildSchemaTable(params));
  bindSchemaActions(container, type, params, defaults);
  
  console.log("Strategy ",schema.Strategy)
  
  // Dropdown Strategy et Preview
  const strategyOptions = Object.keys(Store.strategies)
    .map(s => `<option value="${s}" ${s === schema.Strategy?.Name ? "selected" : ""}>${s}</option>`)
    .join("");

  const previewOptions = Object.keys(Store.previews)
    .map(p => `<option value="${p}" ${p === schema.Preview?.Name ? "selected" : ""}>${p}</option>`)
    .join("");

  container.append(`
    <div class="schema-association">
      <label>Strategy:
        <select class="schema-strategy-select">
          ${strategyOptions}
        </select>
      </label>
      <label>Preview:
        <select class="schema-preview-select">
          ${previewOptions}
        </select>
      </label>
    </div>
  `);

  // Sauvegarde des sélections
  container.find('.schema-strategy-select').on('change', function() {
    schema.Strategy = schema.Strategy || {};
    schema.Strategy.Name = $(this).val();
  });

  container.find('.schema-preview-select').on('change', function() {
    schema.Preview = schema.Preview || {};
    schema.Preview.Name = $(this).val();
 });
}

// ================================
// Schema table
// ================================
function buildSchemaTable(params) {
  let html = `
  <div class="schema-table-container">
    <button class="add-param">+ Ajouter un paramètre</button>
    <table class="param-table">
      <thead>
        <tr>
          <th>Nom</th>
          <th>Type</th>
          <th>Valeur</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>`;

  Object.entries(params)
    .sort((a, b) => (a[1].idx || 0) - (b[1].idx || 0))
    .forEach(([name, p]) => {
      html += `
      <tr>
        <td>${name}</td>
        <td>${p.type ?? ""}</td>
        <td>${p.Value ?? ""}</td>
        <td>
          <button class="remove-param" data-param="${name}">−</button>
          <button class="revert-param" data-param="${name}">⟳</button>
          <button class="edit-param" data-param="${name}">✎</button>
        </td>
      </tr>`;
    });

  return html + `</tbody></table></div>`;
}

// ================================
// Schema actions
// ================================
function bindSchemaActions(container, type, params, defaults) {

  container.find('.add-param').on('click', () => {
    const name = prompt("Nom du paramètre ?");
    if (!name) return;
    params[name] = { Value: "", type: "text", idx: Object.keys(params).length };
    updateSchemaContent(type);
  });

  container.on('click', '.remove-param', function () {
    const paramName = $(this).data('param');
    if (!paramName) return;
    delete params[paramName];
    updateSchemaContent(type);
  });

  container.on('click', '.revert-param', function () {
    const paramName = $(this).data('param');
    if (!paramName || !defaults[paramName]) return;
    params[paramName] = deepClone(defaults[paramName]);
    updateSchemaContent(type);
  });

  container.on('click', '.edit-param', function () {
    const paramName = $(this).data('param');
    if (!paramName) return;
    openParamEditor(paramName, params[paramName]);
  });
}

// ================================
// Param editor
// ================================
const PARAM_OPTION_DEFS = Object.freeze({
  type:    { type: "dropdown", values: ["spinner", "dropdown", "checkbox", "text"] },
  min:     { type: "number" },
  max:     { type: "number" },
  step:    { type: "number" },
  decimal: { type: "number", integer: true },
  options: { type: "text" }
});

function openParamEditor(name, param) {
  // Supprimer l'ancien dialog si il existe
  $("#param-editor").remove();
  
  let html = `
  <div id="param-editor" title="Paramètre : ${name}">
    <table class="param-editor-table">
      <thead>
        <tr><th>Option</th><th>Actif</th><th>Valeur</th></tr>
      </thead>
      <tbody>`;

  Object.entries(PARAM_OPTION_DEFS).forEach(([key, def]) => {
    const enabled = param[key] !== undefined;
    html += `
      <tr data-key="${key}">
        <td>${key}</td>
        <td><input type="checkbox" class="opt-enable" ${enabled ? "checked" : ""}></td>
        <td>${buildOptionInput(def, param[key], enabled)}</td>
      </tr>`;
  });

  html += `</tbody></table></div>`;

  const dlg = $(html).appendTo("body");

  dlg.on('change', '.opt-enable', function () {
    $(this).closest('tr').find('.opt-value')
      .prop('disabled', !this.checked);
  });

  dlg.dialog({
    modal: true,
    width: 520,
      buttons: {
      OK: function () {
        applyParamEditorChanges(param, dlg);
        $(this).dialog("close").remove(); // ok
        updateSchemaContent($('#schema-select').val());
      },
      Cancel: function () {
        $(this).dialog("close").remove();
      }		
    }
  });
}

function buildOptionInput(def, value, enabled) {
  const disabled = enabled ? "" : "disabled";

  if (def.type === "dropdown") {
    return `<select class="opt-value" ${disabled}>
      ${def.values.map(v =>
        `<option value="${v}" ${v === value ? "selected" : ""}>${v}</option>`
      ).join("")}
    </select>`;
  }

  return `<input type="${def.type === "number" ? "number" : "text"}"
           class="opt-value" value="${value ?? ""}" ${disabled}>`;
}

function applyParamEditorChanges(param, dlg) {
  dlg.find("tr[data-key]").each(function () {
    const key = $(this).data("key");
    const enabled = $(this).find(".opt-enable").prop("checked");
    const input = $(this).find(".opt-value");

    if (!enabled) {
      delete param[key];
      return;
    }

    let val = input.val();
    if (!isNaN(val) && val !== "") val = parseFloat(val);
    if (key === "options") val = val.split(",").map(s => s.trim());

    param[key] = val;
  });
}

// ================================
// Apply / Reset
// ================================
$('#tp-apply').on('click', function () {
  const type = $('#schema-select').val();
  if (!type) return;
  sketchup.saveSchema(type, Store.schemas[type].Schema);
});

$('#schema-remove').on('click', function () {
  const type = $('#schema-select').val();
  if (!type) return;
  if (!confirm(`Reset ${type} ?`)) return;

  Store.schemas[type] = deepClone(Store.defaults.schemas[type]);
  updateSchemaContent(type);
  sketchup.resetSchema(type);
});


function updateStrategiesTab() {
  const name = $("#strategy-select").val();
  if (!name || !Store.strategies[name]) return;

  const container = $("#strategy-content");
  container.empty();

  const text = Store.strategies[name];

  const html = `
    <div class="strategy-editor">

      <div class="strategy-toolbar">
        <button id="strategy-add">+</button>
        <button id="strategy-remove">−</button>
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
    sketchup.saveStrategy(name, Store.strategies[name]);
  });

  $("#strategy-revert").on("click", function () {
    if (!defaultStrategies[name]) return;
    Store.strategies[name] = defaultStrategies[name];
    updateStrategiesTab();
  });

  $("#strategy-remove").on("click", function () {
    if (!confirm(`Remove strategy "${name}" ?`)) return;
    delete Store.strategies[name];
    sketchup.removeStrategy(name);
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

function escapeHtml(str) {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function updatePreviewsTab() {
  const name = $("#preview-select").val();
  if (!name || !Store.previews[name]) return;

  const container = $("#preview-content");
  container.empty();

  const text = Store.previews[name];

  const html = `
    <div class="preview-editor">

      <div class="preview-toolbar">
        <button id="preview-add">+</button>
        <button id="preview-remove">−</button>
        <button id="preview-revert">⟳</button>
        <button id="preview-save">💾</button>
      </div>
      <textarea id="preview-text"
                spellcheck="false"
                class="preview-textarea"
                style="width:100%; height:300px; font-family:monospace; font-size:14px;">${escapeHtml(text).trim()}</textarea>

    </div>
  `;

  container.append(html);

  bindPreviewActions(name);
}

function bindPreviewActions(name) {
  $("#preview-save").on("click", function () {
    Store.previews[name] = $("#preview-text").val();
    sketchup.savePreview(name, Store.previews[name]);
  });

  $("#preview-revert").on("click", function () {
    if (!Store.defaults.previews[name]) return;
    Store.previews[name] = Store.defaults.previews[name];
    updatePreviewsTab();
  });

  $("#preview-remove").on("click", function () {
    if (!confirm(`Remove preview "${name}" ?`)) return;
    delete Store.previews[name];
    sketchup.removePreview(name);
    populateSelect("#preview-select", Store.previews);
    updatePreviewsTab();
  });

  $("#preview-add").on("click", function () {
    const newName = prompt("Nom de la nouvelle preview ?");
    if (!newName || Store.previews[newName]) return;

    Store.previews[newName] = "; new preview\n";
    populateSelect("#preview-select", Store.previews);
    $("#preview-select").val(newName).selectmenu("refresh");
    updatePreviewsTab();
  });
}