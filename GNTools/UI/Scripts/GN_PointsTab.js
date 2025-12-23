function updatePointsTab() {
	const INCH_TO_MM = 25.4;
	const pointsContent = $('#points-content');
    pointsContent.empty();
    // Aucune sélection → paramètres par défaut du type choisi dans Add
    if (selectedToolpaths.length === 0) {
	    // cacher le tab Paramètre
        $("#points-tab-header").hide();      // cacher le bouton
		pointsContent.hide();
		$("#tabs").tabs( "refresh" );
    } else if (selectedToolpaths.length === 1) {
		// montrer le tab Paramètre
		$("#points-tab-header").show();
		pointsContent.show();
		$("#tabs").tabs( "refresh" );
		const key = selectedToolpaths[0];
		const tp = collection.Toolpaths[key];
		$('#points-content').html("Points de : " + collection.Toolpaths[key].name);
		if (tp.points.length === 0) {
			pointsContent.html("Aucun point défini pour " + collection.Toolpaths[key].name);
		} else {
			// On affiche les points
			let html = `<h4>Points de : ${collection.Toolpaths[key].name}</h4><ul>`;
			tp.points.forEach((pt, i) => {
				console.log(i,pt)
				x = (pt["pos"][0] * INCH_TO_MM).toFixed(3)
				y = (pt["pos"][1] * INCH_TO_MM).toFixed(3)
				z = (pt["pos"][2] * INCH_TO_MM).toFixed(3)
				html += `<li>Point ${i+1}: x=${x}, y=${y}, z=${z}</li>`;
			});
			html += "</ul>";
			pointsContent.html(html);
		}
	} else {
	    // cacher le tab Paramètre
        $("#points-tab-header").hide();      // cacher le bouton
		pointsContent.hide();
		$("#tabs").tabs( "refresh" );
	}
}