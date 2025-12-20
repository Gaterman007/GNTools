function updateDefaultParametersTab() {
    const container = $('#defaultparameters-content');
    container.empty();
	var drillbitName = "Default";
	var defaults = {}
	const type = $('#add-toolpath-type').val();
	var defaults = schemas[type]?.Schema || {};
	container.append(`<h3>Paramètres par défaut : ${type}</h3>`);
	container.append(buildDefaultParameterForm(defaults, null));

	setTimeout(() => {
		// Inputs number → spinner
		const nums = container.find('input[type="number"]');
		if (nums.length != 0) {
		  nums.each(function() {
			$(this).spinner();
			$(this).on('change', function() {
				const fullId = $(this).prop("id");  // ex: "default_drillBitName"
				const paramName = fullId.replace(/^default_/, "");  // "drillBitName"
				defaults[paramName].Value = parseFloat($(this).val());
			});
			$(this).on( "spinstop", function( event, ui ) {
				const fullId = $(this).prop("id");  // ex: "default_drillBitName"
				const paramName = fullId.replace(/^default_/, "");  // "drillBitName"
				defaults[paramName].Value = parseFloat($(this).val());
				// si tu veux mettre à jour collection multiple, fais collection.forEach(tp => tp.metadata[paramName] = ... )
			});
		  });
		}

		// Tous les selects → selectmenu
		container.find('select').each(function() {
		  if (this.id !== "default_drillBitName_select") {
			$(this).selectmenu({
			  change: function(event, ui) {
				const fullId = $(this).prop("id");  // ex: "default_drillBitName"
				const paramName = fullId.replace(/^default_/, "");  // "drillBitName"
				defaults[paramName].Value = ui.item.value;
				// idem si collection multiple
			  }
			});
		  } else {
			populateDrillBitSelect(drillBits, "default_drillBitName_select");
			$(this).selectmenu({
			  change: function(event, ui) {
				defaults["drillBitName"].Value = ui.item.value;
				// idem si collection multiple
			  }
			}); // Initialize the selectmenu
		    $(this).addClass("overflow");
			$(this).val(defaults["drillBitName"].Value);
			$(this).selectmenu("refresh");
		  }
		});
		
		const check = container.find('input[type="checkbox"]');
	    if (check.length != 0) {
		  check.each(function() {
		    $(this).checkboxradio();
		    $(this).on('change', function() {
			  const fullId = $(this).prop("id");
			  const paramName = fullId.replace(/^default_/, "");
			  defaults[paramName].Value = $(this).prop('checked');
			  // idem pour collection multiple
		    });
		  });
	    }
	}, 0);
}

function buildDefaultParameterForm(params) {
    let html = `<table class="param-table">`;

    // Récupérer les champs avec un idx valide et trier par idx
    const sortedFields = Object.entries(params)
      .filter(([name, p]) => p.type)            // ne garder que ceux avec type != ""
      .sort((a, b) => (a[1].idx || 0) - (b[1].idx || 0)); // tri par idx

    sortedFields.forEach(([name, p]) => {
        html += `
          <tr>
            <td>${name}</td>
            <td>${createDefaultInputControl(name, p)}</td>
          </tr>`;
    });

    html += `</table>`;
    return html;
}

function createDefaultInputControl(paramName, paramInfo, displayValue) {
	    // --- CAS SPÉCIAL drillBitName ---
    if (paramName === "drillBitName") {
        return `
            <select data-param="drillBitName" id="default_drillBitName_select"></select>
        `;
    }
	
    const type = paramInfo.type || "text";
    const value = displayValue ?? paramInfo.Value;

    switch (type) {

        case "number":
        case "spinner":
			var id = `default_${paramName}`;
            return `
               <input type="number"
                      data-param="${paramName}"
                      value="${value}"
                      min="${paramInfo.min ?? ''}"
                      max="${paramInfo.max ?? ''}"
                      step="${paramInfo.step ?? '0.1'}"
					  id="${id}">
            `;

        case "dropdown":
            let opts = paramInfo.options || [];
			var id = `default_${paramName}`;
            let html = `<select data-param="${paramName}" id="${id}">`;
            opts.forEach(opt => {
                const selected = (opt === value) ? "selected" : "";
                html += `<option value="${opt}" ${selected}>${opt}</option>`;
            });
            html += `</select>`;
            return html;

        case "checkbox":
		    const checked = value ? "checked" : "";
			var id = `default_${paramName}`;
			return ` <label for="${id}">${paramName}</label>
					 <input type="checkbox" id="${id}" data-param="${paramName}" ${checked}>
			       `;


        case "text":
        default:
			var id = `default_${paramName}`;
            return `<input type="text" data-param="${paramName}" id="${id}" value="${value}">`;
    }
}
