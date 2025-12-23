function updateMaterialTab() {
	
}

function updateMaterial(datajson) {
	objMaterial = datajson;
	console.log(objMaterial);
	$( "#safeHeight" ).cncSpinner("value", objMaterial.safeHeight);
	$( "#Depth" ).val(objMaterial.depth);
	$( "#Thickness" ).val(objMaterial.height);
	$( "#Width" ).val(objMaterial.width);
	$( "#material_type" ).val(objMaterial.material_type);
	$( "#material_type" ).selectmenu("refresh");
	console.log("updateMaterial faite");
}

$(function() {
	$("#material_type").selectmenu();
	$("#safeHeight").cncSpinner({
	  min: 0,
	  max: 200,
	  step: 0.01,
	  value: 0,

	  units: "mm",
	  dangerZone: { min: 0, max: 2 },
	  snap: true,
	  wheel: true,
	  precisionStep: true
	});
	$("#Depth").spinner();
	$("#Thickness").spinner();
	$("#Width").spinner();
});