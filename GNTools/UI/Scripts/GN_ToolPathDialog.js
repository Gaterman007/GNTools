var collection = {};
var objMaterial;
var selectedToolpaths = []; // Liste des toolpaths sélectionnés

$(document).ready(function() {
  sketchup.ready();
});

function adjustParametersHeight() {
    const footer = document.getElementById("ui-footer");
	const tabs = document.querySelector(".ui-tabs-nav");  // barre des onglets
    const container = document.getElementById("parameters-content");

    if (!footer || !container) return;

    const footerHeight = footer.offsetHeight;
	const tabsHeight = tabs.offsetHeight;
    const viewportHeight = window.innerHeight;
	
    // marge de sécurité
    const margin = 20;

    container.style.maxHeight = (viewportHeight - tabsHeight - footerHeight - margin) + "px";
}

// appeler au chargement
//window.addEventListener("load", adjustParametersHeight);

// appeler quand on redimensionne la fenêtre du dialog
//window.addEventListener("resize", adjustParametersHeight);

// Reçu depuis Ruby
window.loadCollection = function(datajson) {
  console.log(datajson);
  collection = datajson;
  refreshToolpathList();
  updateTabsContent();
};

window.updateSchemas = function(datajson) {
  const schemas = JSON.parse(datajson);

  // Mettre à jour la liste des types pour l’ajout
  updateToolpathTypeList(schemas);

  // Tu pourras aussi plus tard remplir les paramètres selon les types
  window.schemas = schemas;  
  updateTabsContent();
};

window.selectToolpathType = function(type) {
	const select = $('#add-toolpath-type');
    if (!select) return;
    // Sélectionner l'option correspondante
    select.val(type);
	console.log(type);
	select.selectmenu("refresh");
    updateTabsContent();
};

window.updateSelection = function(selected) {
  selectedToolpaths = selected;

  $('.tp-select').each(function() {
    const key = $(this).val();
    this.checked = selected.includes(key);
  });

  updateTabsContent();
};

window.setTitle = function(title) {
  $("#title").html(title)
}

function updateMaterialType(datajson) {
	const matTypes = JSON.parse(datajson);
	const selectMatType = $('#material_type');
	selectMatType.empty();
	Object.keys(matTypes).forEach(key => {
		selectMatType.append(`<option value="${key}">${matTypes[key]}</option>`);
	});
}

function refreshToolpathList() {
  const list = $('#toolpath-list');
  list.empty();

  selectedToolpaths = [];
  var allVisible = true
  if (collection.Toolpaths) {
	  Object.keys(collection.Toolpaths).forEach(key => {
		const tp = collection.Toolpaths[key];
		const checked = tp.visible ? "checked" : "";
		if (!tp.visible) allVisible = false
		const li = $(`
		  <li>
			<input type="checkbox" class="tp-select" value="${key}"  ${checked}>
			<span class="tp-label">${tp.type} (${tp.name})</span>
		  </li>
		`);
		list.append(li);
		// Mettre à jour selectedToolpaths si visible
		if (tp.visible) selectedToolpaths.push(key);
	  });

    if (selectedToolpaths.length === Object.keys(collection.Toolpaths).length) {
	  $('#tp-select-all').prop("checked", true);
    }
  
    // Mise à jour des toolpaths sélectionnés
    $('.tp-select').change(function() {
      const key = $(this).val();

      if (this.checked) {
        if (!selectedToolpaths.includes(key)) selectedToolpaths.push(key);
      } else {
        selectedToolpaths = selectedToolpaths.filter(k => k !== key);
      }
	  if (selectedToolpaths.length === 0)  {
		$('#tp-select-all').prop("checked", false);
	  }
	  if (selectedToolpaths.length === Object.keys(collection.Toolpaths).length) {
		$('#tp-select-all').prop("checked", true);
	  }
	  collection.Toolpaths[key].visible = this.checked
	  sketchup.fromJS(JSON.stringify({
	    action: "set_toolpath_visible",
	    id: key,
	    visible: this.checked
	  }));
	
      updateTabsContent();
    });
  }
}

// Sélection / désélection globale
$('#tp-select-all').change(function() {
  const checked = this.checked;

  $('.tp-select').each(function() {
    this.checked = checked;

    const key = $(this).val();

    if (checked) {
      if (!selectedToolpaths.includes(key)) {
        selectedToolpaths.push(key);
      }
    } else {
      selectedToolpaths = [];
    }
	collection.Toolpaths[key].visible = this.checked
	sketchup.fromJS(JSON.stringify({
	  action: "set_toolpath_visible",
	  id: key,
	  visible: this.checked
	}));
  });
  updateParametersTab();
  updatePointsTab();
});


// ➜ Supprimer plusieurs toolpaths
function updateToolpathTypeList(schemas) {
  const select = $('#add-toolpath-type');
  select.empty();

  Object.keys(schemas).forEach(type => {
    select.append(`<option value="${type}">${type}</option>`);
  });

  select.selectmenu("refresh");
}

$('#btn-remove-tp').click(function() {
  if (selectedToolpaths.length === 0) return;

  selectedToolpaths.forEach(key => {
    delete collection.Toolpaths[key];
	sketchup.fromJS(JSON.stringify({
	  action: "toolpath_delete",
	  id: key
	}));
  });

  selectedToolpaths = [];
  refreshToolpathList();
  $('#parameters-content').empty();
  $('#points-content').empty();
});

$('#btn-edit-tp').click(function() {
  const type = $('#add-toolpath-type').val();
  const key = type + "_" + (Object.keys(collection.Toolpaths).length + 1);
  const defaults = schemas[type]?.Schema || {};

  sketchup.fromJS(JSON.stringify({
	action: "edit_toolpath",
	type: type,
	key: key,
	defaults: defaults
  }));
});


// ➜ Mettre à jour les autres tabs selon la sélection
function updateTabsContent() {
  updateParametersTab();
  updateDefaultParametersTab();
  updatePointsTab();
}

$(function() {
  $("#add-toolpath-type").selectmenu();
  $("#tabs").tabs();
  $( "#accept, #cancel, #setDefault, #apply").button();
  $( "#apply" ).on( "click", function( event ) {
	sketchup.apply(collection,objMaterial);
  });
  $( "#accept" ).on( "click", function( event ) {
	sketchup.accept(collection,objMaterial);
  });

  $( "#setDefault" ).on( "click", function( event ) {
	const type = $('#add-toolpath-type').val();
	var defaults = schemas[type]?.Schema || {};
	sketchup.setDefault(defaults);
  });
  $( "#cancel" ).on( "click", function( event ) {
	sketchup.cancel();
  });
  // Ajuster le checkbox "Select All"
  if (collection.Toolpaths) {
	$('#tp-select-all').prop("checked", selectedToolpaths.length === Object.keys(collection.Toolpaths).length);
  } else {
	$('#tp-select-all').prop("checked",false);
  }	
  $("#add-toolpath-type").on("selectmenuchange", function () {
	const type = $('#add-toolpath-type').val();
	sketchup.fromJS(JSON.stringify({
      action: "toolpath_type_setting",
	  type: type
    }));
    updateTabsContent();
  });
  $("#btn-edit").button().on("click", function () {
    $(this).toggleClass("active");

    if ($(this).hasClass("active")) {
        console.log("Edit mode ON");
    } else {
        console.log("Edit mode OFF");
    }
  });
  $("#btn-edit").button({
    icon: "ui-icon-pencil"
  });
});
