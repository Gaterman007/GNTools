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


function diffByKey(current, defaults) {
  const diff = {};

  // clés présentes ou modifiées
  Object.keys(current).forEach(key => {
    if (!(key in defaults) || JSON.stringify(current[key]) !== JSON.stringify(defaults[key])) {
      diff[key] = current[key];
    }
  });

  // clés supprimées
  Object.keys(defaults).forEach(key => {
    if (!(key in current)) {
      diff[key] = null; // signal suppression
    }
  });

  return Object.keys(diff).length ? diff : null;
}

// ================================
// Init
// ================================
$(document).ready(function () {
  sketchup.ready();
  $("#tp-tabs").tabs();
  $( "#accept, #cancel, #apply").button();
  $( "#apply" ).on( "click", function( event ) {
    const retVal = {};

    const schemaDiff = diffByKey(Store.schemas, Store.defaults.schemas);
    if (schemaDiff) retVal.schemas = schemaDiff;

    const strategyDiff = diffByKey(Store.strategies, Store.defaults.strategies);
    if (strategyDiff) retVal.strategies = strategyDiff;

    const previewDiff = diffByKey(Store.previews, Store.defaults.previews);
    if (previewDiff) retVal.previews = previewDiff;

    if (Object.keys(retVal).length === 0) {
      sketchup.apply(null);
    } else {
      sketchup.apply(retVal);
    }

  });
  
  $( "#accept" ).on( "click", function( event ) {
    const retVal = {};

    const schemaDiff = diffByKey(Store.schemas, Store.defaults.schemas);
    if (schemaDiff) retVal.schemas = schemaDiff;

    const strategyDiff = diffByKey(Store.strategies, Store.defaults.strategies);
    if (strategyDiff) retVal.strategies = strategyDiff;

    const previewDiff = diffByKey(Store.previews, Store.defaults.previews);
    if (previewDiff) retVal.previews = previewDiff;

    if (Object.keys(retVal).length === 0) {
      sketchup.accept(null);
    } else {
      sketchup.accept(retVal);
    }
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

function escapeHtml(str) {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}