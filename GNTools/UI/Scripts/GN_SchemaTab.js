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

const SchemaUI = {

  setValue(paramName, value) {
    const type = $('#schema-select').val();
    if (!type) return;

    const param = Store.schemas[type]?.Schema?.[paramName];
    if (!param) return;

    // Conversion simple auto
    if (!isNaN(value) && value !== "") {
      param.Value = Number(value);
    } else {
      param.Value = value;
    }
  },

  editParam(btn) {
    const type = $('#schema-select').val();
    const paramName = btn.dataset.param;

    if (!type || !paramName) return;

    const schema = Store.schemas[type];
    if (!schema || !schema.Schema || !schema.Schema[paramName]) return;

    openParamEditor(type, paramName, schema.Schema[paramName]);
  },

  removeParam(btn) {
    const type = $('#schema-select').val();
    const paramName = btn.dataset.param;
    if (!type || !paramName) return;

    delete Store.schemas[type].Schema[paramName];
    updateSchemaContent(type);
  },

  revertParam(btn) {
    const type = $('#schema-select').val();
    const paramName = btn.dataset.param;

    const def = Store.defaults.schemas[type]?.Schema?.[paramName];
    if (!def) return;

    Store.schemas[type].Schema[paramName] = deepClone(def);
    updateSchemaContent(type);
  }

};

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
	  const value = p.Value ?? "";
      html += `
      <tr>
        <td>${name}</td>
        <td>${p.type ?? ""}</td>
        <td><input
            class="schema-value-input"
            type="text"
            value="${escapeHtml(String(value))}"
            oninput="SchemaUI.setValue('${name}', this.value)"
          /></td>
        <td>
		  <button data-param="${name}" onclick="SchemaUI.editParam(this)">✎</button>
		  <button data-param="${name}" onclick="SchemaUI.revertParam(this)">↺</button>
		  <button data-param="${name}" onclick="SchemaUI.removeParam(this)">🗑</button>
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
    openParamEditor(type, paramName, params[paramName]);
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

function openParamEditor(type, name, param) {

  console.log("name",name)
  console.log("param",param)
  console.log("schema type",Store.schemas[type])
  console.log("schema type Schema",Store.schemas[type].Schema)
  console.log("schema type Schema name",Store.schemas[type].Schema[name])
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


$('#schema-revert').on('click', function () {
  const type = $('#schema-select').val();
  if (!type) return;
  if (!confirm(`Reset ${type} ?`)) return;

  Store.schemas[type] = deepClone(Store.defaults.schemas[type]);
  updateSchemaContent(type);
  sketchup.resetSchema(type);
});
