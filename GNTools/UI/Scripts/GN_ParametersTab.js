function updateParametersTab() {
    const container = $('#parameters-content');
    container.empty();
	var drillbitName = "Default";
	var defaults = {}
    // Aucune sélection → paramètres par défaut du type choisi dans Add
    if (selectedToolpaths.length === 0) {
	    // cacher le tab Paramètre
        $("#parameters-tab-header").hide();      // cacher le bouton
		container.hide();
		$("#tabs").tabs( "refresh" );
    } else if (selectedToolpaths.length === 1) {
	    // montrer le tab Paramètre
		$("#parameters-tab-header").show();
		container.show();
		$("#tabs").tabs( "refresh" );
        const key = selectedToolpaths[0];
        container.append(`<h3>Paramètres : ${collection.Toolpaths[key].name}</h3>`);
		var defaults = collection.Toolpaths[key].metadata
        container.append(buildParameterForm(defaults, key));
    } else {
	    // montrer le tab Paramètre
	  $("#parameters-tab-header").show();
	  container.show();
	  $("#tabs").tabs( "refresh" );
      // Sélection multiple
      container.append(`<h3>Sélection multiple (${selectedToolpaths.length})</h3>`);
      container.append(buildMixedParameterForm());
	  setTimeout(() => {
		// Inputs number → spinner
		const nums = container.find('input[type="number"]');
		if (nums.length != 0) {
		  nums.each(function() {
			$(this).spinner();
			$(this).on('change', function() {
				const name = $(this).prop("id");
				const keys = selectedToolpaths;
				// collection a mettre a jour
				keys.forEach(k => {
                  const tpMeta = collection.Toolpaths[k].metadata;
				  if (tpMeta && tpMeta[name]) {  // <-- sécurise
					tpMeta[name].Value = parseFloat($(this).val());
				  }
                });
			});
			$(this).on( "spinstop", function( event, ui ) {
				const name = $(this).prop("id");
				const keys = selectedToolpaths;
				// collection a mettre a jour
				keys.forEach(k => {
                  const tpMeta = collection.Toolpaths[k].metadata;
				  if (tpMeta && tpMeta[name]) {  // <-- sécurise
					tpMeta[name].Value = parseFloat($(this).val());
				  }
                });
			});
		  });
		}

		// Tous les selects → selectmenu
		container.find('select').each(function() {
		  if (this.id !== "drillBitName_select") {
			$(this).selectmenu({
			  change: function(event, ui) {
				const name = $(this).prop("id");
				const keys = selectedToolpaths;
				// collection a mettre a jour
				keys.forEach(k => {
                  const tpMeta = collection.Toolpaths[k].metadata;
				  if (tpMeta && tpMeta[name]) {  // <-- sécurise
					tpMeta[name].Value = ui.item.value;
				  }
                });
			  }
			});
		  } else {
			populateDrillBitSelect(drillBits, "drillBitName_select");
			$(this).selectmenu({
			  change: function(event, ui) {
				const keys = selectedToolpaths;
				// collection a mettre a jour
				keys.forEach(k => {
                  const tpMeta = collection.Toolpaths[k].metadata;
				  if (tpMeta && tpMeta["drillBitName"]) {  // <-- sécurise
					tpMeta["drillBitName"].Value = ui.item.value;
				  }
                });
			  }
			}); // Initialize the selectmenu
		    $(this).addClass("overflow");
			$(this).selectmenu("refresh");
		  }
		});
		
		const check = container.find('input[type="checkbox"]');
	    if (check.length != 0) {
		  check.each(function() {
		    $(this).checkboxradio();
		    $(this).on('change', function() {
			  const name = $(this).prop("id");
				const keys = selectedToolpaths;
				// collection a mettre a jour
				keys.forEach(k => {
                  const tpMeta = collection.Toolpaths[k].metadata;
				  if (tpMeta && tpMeta[name]) {  // <-- sécurise
					tpMeta[name].Value = $(this).prop('checked');
				  }
                });
			  // idem pour collection multiple
		    });
		  });
	    }
	  }, 0);
	  return
	}

	setTimeout(() => {
		// Inputs number → spinner
		const nums = container.find('input[type="number"]');
		if (nums.length != 0) {
		  nums.each(function() {
			$(this).spinner();
			$(this).on('change', function() {
				const name = $(this).prop("id");
				defaults[name].Value = parseFloat($(this).val());
				// si tu veux mettre à jour collection multiple, fais collection.forEach(tp => tp.metadata[name] = ... )
			});
			$(this).on( "spinstop", function( event, ui ) {
				const name = $(this).prop("id");
				defaults[name].Value = parseFloat($(this).val());
				// si tu veux mettre à jour collection multiple, fais collection.forEach(tp => tp.metadata[name] = ... )
			});
		  });
		}

		// Tous les selects → selectmenu
		container.find('select').each(function() {
		  if (this.id !== "drillBitName_select") {
			$(this).selectmenu({
			  change: function(event, ui) {
				const name = $(this).prop("id");
				defaults[name].Value = ui.item.value;
				// idem si collection multiple
			  }
			});
		  } else {
			populateDrillBitSelect(drillBits, "drillBitName_select");
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
			  const name = $(this).prop("id");
			  defaults[name].Value = $(this).prop('checked');
			  // idem pour collection multiple
		    });
		  });
	    }
	}, 0);
}

function buildParameterForm(params) {
    let html = `<table class="param-table">`;

    // Récupérer les champs avec un idx valide et trier par idx
    const sortedFields = Object.entries(params)
      .filter(([name, p]) => p.type)            // ne garder que ceux avec type != ""
      .sort((a, b) => (a[1].idx || 0) - (b[1].idx || 0)); // tri par idx


    sortedFields.forEach(([name, p]) => {
        html += `
          <tr>
            <td>${name}</td>
            <td>${createInputControl(name, p)}</td>
          </tr>`;
    });

    html += `</table>`;
    return html;
}

function getParamType(paramName, keys) {
    for (let k of keys) {
        const tpMeta = collection.Toolpaths[k]?.metadata;
        if (tpMeta && tpMeta[paramName]?.type) {
            return tpMeta[paramName].type;
        }
    }
    return ""; // No show
}

function buildMixedParameterForm() {
    let html = `<table class="param-table">`;

    const keys = selectedToolpaths;
	
	if (keys.length === 0) return html;

    // 1️ Construire la liste de tous les paramnames présents dans les toolpaths sélectionnés
    const allParamNames = new Set();
    keys.forEach(k => {
		console.log(collection.Toolpaths[k])
        const tpMeta = collection.Toolpaths[k].metadata;
        Object.keys(tpMeta).forEach(p => allParamNames.add(p));
    });
    // Récupérer les champs avec un idx valide et trier par idx
	const sortedFields = [...allParamNames]
		.map(paramName => {
			// chercher le premier toolpath qui a ce param
			const meta = keys
				.map(k => collection.Toolpaths[k].metadata[paramName])
				.find(m => m !== undefined);

			return {
				name: paramName,
				meta: meta
			};
		})
		// ne garder que ceux qui ont un "type"
		.filter(entry => entry.meta && entry.meta.type)
		// trier par idx (0 si absent)
		.sort((a, b) => (a.meta.idx || 0) - (b.meta.idx || 0));
    // 2️ Pour chaque paramname
	sortedFields.forEach( param => {
        // valeurs existantes pour ce param dans chaque TP
        const values = keys
						.map(k => collection.Toolpaths[k].metadata[param.name]?.Value)
						.filter(v => v !== undefined);   // <-- important
						
		allSame = true; // pas d’ambiguïté
						
		// aucun TP n’a ce param
		if (values.length === 0) {
			displayValue = "";
		} else {
			const firstValue = values[0];
			allSame = values.every(v => v === firstValue);
			displayValue = allSame ? firstValue : "";
		}
		
		const type = getParamType(param.name, keys)

		if (type != "") {

          const style = allSame ? "" : "background-color:#fff59d";

		  const meta = keys.map(k => collection.Toolpaths[k]?.metadata[param.name]).find(m => m);

          html += `
            <tr>
              <td>${param.name}</td>
              <td style="${style}">
                ${createInputControl(param.name, meta, displayValue)}
              </td>
            </tr>`;
		}
    });

    html += `</table>`;
    return html;
}

function createInputControl(paramName, paramInfo, displayValue) {
	    // --- CAS SPÉCIAL drillBitName ---
    if (paramName === "drillBitName") {
        return `
            <select data-param="drillBitName" id="drillBitName_select"></select>
        `;
    }
	
    const type = paramInfo.type || "text";
    const value = displayValue ?? paramInfo.Value;

    switch (type) {

        case "number":
        case "spinner":
			var id = `${paramName}`;
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
			var id = `${paramName}`;
            let html = `<select data-param="${paramName}" id="${id}">`;
            opts.forEach(opt => {
                const selected = (opt === value) ? "selected" : "";
                html += `<option value="${opt}" ${selected}>${opt}</option>`;
            });
            html += `</select>`;
            return html;

        case "checkbox":
		    const checked = value ? "checked" : "";
			var id = `${paramName}`;
			return ` <label for="${id}">${paramName}</label>
					 <input type="checkbox" id="${id}" data-param="${paramName}" ${checked}>
			       `;


        case "text":
        default:
            return `<input type="text" data-param="${paramName}" value="${value}">`;
    }
}
